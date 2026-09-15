-- ================================================================
--  Modules 2-6 schema — Health Passport, AI Vet Chat, Nutrition,
--  Memory Timeline, Billing & Reminders. None of these modules are
--  built in the app yet; this creates the tables ahead of that work
--  so the schema matches db-design/*.sql in full, not just the
--  subset backing shipped features.
--
--  Reference/lookup tables are DELIBERATELY NOT created here, same
--  precedent as `breeds` in 0001 — assets/data/README.md already
--  documents these as bundled JSON assets per PRD §9 (zero reads,
--  works offline, triage_rules must work with no network):
--    vaccine_types, triage_rules, toxic_items, food_items,
--    milestone_templates
--  Columns that FK'd into them (health_records.vaccine_type_id,
--  food_logs.food_item_id, timeline_entries.template_id) are kept
--  as plain uuid with no REFERENCES, same treatment as
--  pets.breed_id in 0001.
--
--  `recalls` (04_nutrition.sql) IS created as a real table — it's
--  polled from the FDA feed, not static reference data, so it can't
--  be a bundled asset.
--
--  CONFLICT NOT RESOLVED HERE: 06_billing_reminders.sql redefines
--  `usage_counters` with a different shape (usage_date/kind
--  quota_kind/used, no "limit" column) than 00_core.sql's version,
--  which 0001_init.sql already created and which reserve_scan_quota()
--  already writes to in production. This migration does NOT touch
--  usage_counters — replacing a live, tested table with an
--  incompatible redefinition isn't a call to make silently. When
--  Module 6 (chat quota) actually gets built, reconcile the two
--  db-design files first (e.g. add a `kind`-scoped variant or widen
--  the existing table) rather than running 06's CREATE TABLE as-is.
-- ================================================================

-- ----------------------------------------------------------------
-- ENUMS
-- ----------------------------------------------------------------
create type record_type      as enum ('vaccine', 'vet_visit', 'medication', 'weight', 'allergy', 'preventive');
create type triage_level     as enum ('emergency', 'urgent', 'routine', 'info');
create type message_role     as enum ('user', 'assistant');
create type log_category     as enum ('meal', 'treat', 'human_food', 'toxic_alert');
create type plan_goal        as enum ('maintain', 'lose', 'gain', 'growth');
create type entry_type       as enum ('photo', 'milestone', 'gotcha_day', 'birthday', 'first', 'note');
create type store_kind       as enum ('apple', 'google', 'promo');
create type sub_status       as enum ('trialing', 'active', 'expired', 'canceled', 'refunded');
create type reminder_status  as enum ('pending', 'sent', 'completed', 'skipped');

-- ================================================================
--  MODULE 2: Health Passport
-- ================================================================

create table health_records (
    id              uuid        primary key default gen_random_uuid(),
    pet_id          uuid        not null references pets(id) on delete cascade,
    type            record_type not null,

    title           varchar(150) not null,
    occurred_on     date        not null,
    due_on          date,

    -- vaccine_types is a bundled JSON asset (assets/data/vaccine_types.json),
    -- not a table — see file header. Plain uuid, no FK, same as pets.breed_id.
    vaccine_type_id uuid,
    dose_number     smallint,
    weight_kg       numeric(5,2),
    body_score      smallint    check (body_score between 1 and 9),
    dosage_text     varchar(80),
    frequency_text  varchar(80),
    dose_times      time[]      not null default '{}',
    ends_on         date,
    clinic_name     varchar(150),
    cost_amount     numeric(10,2),
    notes           text,
    attachment_urls text[]      not null default '{}',

    is_active       boolean     not null default true,
    created_by_id   uuid        not null references users(id),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index records_pet_idx    on health_records(pet_id, occurred_on desc);
create index records_type_idx   on health_records(pet_id, type, occurred_on desc);
create index records_due_idx    on health_records(due_on) where due_on is not null;
create index records_weight_idx on health_records(pet_id, occurred_on desc) where type = 'weight';

create trigger trg_records_upd before update on health_records
    for each row execute function set_updated_at();

create view latest_weights with (security_invoker = true) as
select distinct on (pet_id) pet_id, occurred_on, weight_kg, body_score
from health_records where type = 'weight'
order by pet_id, occurred_on desc;

alter table health_records enable row level security;

create policy health_records_select on health_records
    for select using (is_pet_owner(pet_id));
create policy health_records_insert on health_records
    for insert with check (is_pet_owner(pet_id));
create policy health_records_update on health_records
    for update using (is_pet_owner(pet_id));
create policy health_records_delete on health_records
    for delete using (is_pet_owner(pet_id));

-- ================================================================
--  MODULE 3: AI Vet Chat
--  triage_rules / toxic_items stay bundled JSON (see file header) —
--  chat_threads / chat_messages are real, they're the user's own data.
-- ================================================================

create table chat_threads (
    id              uuid        primary key default gen_random_uuid(),
    user_id         uuid        not null references users(id),
    pet_id          uuid        references pets(id) on delete set null,

    title           varchar(150),
    level           triage_level,
    summary         text,

    pet_snapshot    jsonb       not null default '{}',

    message_count   smallint    not null default 0,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index threads_user_idx      on chat_threads(user_id, created_at desc);
create index threads_emergency_idx on chat_threads(created_at desc) where level = 'emergency';

create trigger trg_threads_upd before update on chat_threads
    for each row execute function set_updated_at();

alter table chat_threads enable row level security;

create policy chat_threads_select on chat_threads
    for select using (auth.uid() = user_id);
create policy chat_threads_insert on chat_threads
    for insert with check (auth.uid() = user_id);
create policy chat_threads_update on chat_threads
    for update using (auth.uid() = user_id);

create table chat_messages (
    id              uuid        primary key default gen_random_uuid(),
    thread_id       uuid        not null references chat_threads(id) on delete cascade,
    role            message_role not null,
    content         text        not null,
    photo_urls      text[]      not null default '{}',

    matched_rules   text[]      not null default '{}',
    level           triage_level,

    was_helpful     boolean,
    tokens_used     int,
    created_at      timestamptz not null default now()
);

create index messages_thread_idx on chat_messages(thread_id, created_at);
create index messages_bad_idx    on chat_messages(created_at desc) where was_helpful = false;

-- security definer + stable: called from chat_messages' own RLS
-- policies below, mirrors is_pet_owner's reasoning in 0002.
create or replace function owns_chat_thread(p_thread_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from chat_threads where id = p_thread_id and user_id = auth.uid()
  );
$$;

grant execute on function owns_chat_thread(uuid) to authenticated;

alter table chat_messages enable row level security;

create policy chat_messages_select on chat_messages
    for select using (owns_chat_thread(thread_id));
create policy chat_messages_insert on chat_messages
    for insert with check (owns_chat_thread(thread_id));
create policy chat_messages_update on chat_messages
    for update using (owns_chat_thread(thread_id));

-- ================================================================
--  MODULE 4: Nutrition & Care Planner
--  food_items stays bundled JSON (see file header).
-- ================================================================

create table feeding_plans (
    id                  uuid        primary key default gen_random_uuid(),
    pet_id              uuid        not null references pets(id) on delete cascade,
    goal                plan_goal   not null default 'maintain',

    basis_weight_kg     numeric(5,2) not null,
    target_weight_kg    numeric(5,2),
    mer_factor          numeric(3,1) not null,
    daily_kcal          int         not null,
    treat_budget_kcal   int         not null,

    meals               jsonb       not null default '[]',
    notes               text,

    is_active           boolean     not null default true,
    recalculate_after   date,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create unique index plans_one_active_uidx on feeding_plans(pet_id) where is_active = true;

create trigger trg_plans_upd before update on feeding_plans
    for each row execute function set_updated_at();

alter table feeding_plans enable row level security;

create policy feeding_plans_select on feeding_plans
    for select using (is_pet_owner(pet_id));
create policy feeding_plans_insert on feeding_plans
    for insert with check (is_pet_owner(pet_id));
create policy feeding_plans_update on feeding_plans
    for update using (is_pet_owner(pet_id));
create policy feeding_plans_delete on feeding_plans
    for delete using (is_pet_owner(pet_id));

create table food_logs (
    id              uuid        primary key default gen_random_uuid(),
    pet_id          uuid        not null references pets(id) on delete cascade,
    -- food_items is a bundled JSON asset, not a table — see file header.
    food_item_id    uuid,
    item_text       varchar(150) not null,
    category        log_category not null default 'meal',
    kcal            int,
    logged_at       timestamptz not null default now(),
    logged_by_id    uuid        not null references users(id)
);

create index food_logs_pet_idx on food_logs(pet_id, logged_at desc);

create view daily_intake with (security_invoker = true) as
select pet_id, date(logged_at) as day,
       sum(kcal)                                                   as total_kcal,
       sum(kcal) filter (where category in ('treat', 'human_food')) as treat_kcal
from food_logs
group by pet_id, date(logged_at);

alter table food_logs enable row level security;

create policy food_logs_select on food_logs
    for select using (is_pet_owner(pet_id));
create policy food_logs_insert on food_logs
    for insert with check (is_pet_owner(pet_id));
create policy food_logs_delete on food_logs
    for delete using (is_pet_owner(pet_id));

-- recalls: global, polled from the FDA feed server-side — not bundled
-- JSON (it changes over time and needs to reach installed apps
-- without a release), not user-owned either. Public read, no client
-- write policy (cron/service-role managed only).
create table recalls (
    id              uuid        primary key default gen_random_uuid(),
    species_scope   species[]   not null,
    external_id     varchar(80) not null unique,
    brand           varchar(120) not null,
    product         varchar(200) not null,
    reason          text,
    lot_codes       text[]      not null default '{}',
    published_on    date        not null,
    source_url      text,
    created_at      timestamptz not null default now()
);

create index recalls_published_idx on recalls(published_on desc);

alter table recalls enable row level security;

create policy recalls_read on recalls
    for select using (auth.role() = 'authenticated');

-- ================================================================
--  MODULE 5: Memory Timeline
--  milestone_templates stays bundled JSON (see file header).
-- ================================================================

create table timeline_entries (
    id              uuid        primary key default gen_random_uuid(),
    pet_id          uuid        not null references pets(id) on delete cascade,
    -- milestone_templates is a bundled JSON asset, not a table — see file header.
    template_id     uuid,

    entry_type      entry_type  not null default 'photo',
    title           varchar(150),
    body            text,
    entry_date      date        not null,
    photos          jsonb       not null default '[]',

    is_auto_created boolean     not null default false,
    share_count     int         not null default 0,

    created_by_id   uuid        not null references users(id),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    deleted_at      timestamptz
);

create index entries_pet_idx    on timeline_entries(pet_id, entry_date desc) where deleted_at is null;
create index entries_future_idx on timeline_entries(entry_date) where is_auto_created = true;

create trigger trg_entries_upd before update on timeline_entries
    for each row execute function set_updated_at();

alter table timeline_entries enable row level security;

create policy timeline_entries_select on timeline_entries
    for select using (is_pet_owner(pet_id));
create policy timeline_entries_insert on timeline_entries
    for insert with check (is_pet_owner(pet_id));
create policy timeline_entries_update on timeline_entries
    for update using (is_pet_owner(pet_id));
create policy timeline_entries_delete on timeline_entries
    for delete using (is_pet_owner(pet_id));

-- ================================================================
--  Billing & Reminders
--  usage_counters is intentionally NOT touched — see file header.
-- ================================================================

-- plans: admin-managed pricing/entitlement tiers, same pattern as
-- app_config — public read, no client write policy.
create table plans (
    tier                plan_tier   primary key,
    display_name        varchar(60) not null,
    max_pets            smallint    not null,
    scans_per_day       smallint    not null,
    chats_per_day       smallint    not null,
    max_members_per_pet smallint    not null default 1,
    has_cloud_photos    boolean     not null default false,
    has_nutrition       boolean     not null default false,
    has_recall_alerts   boolean     not null default false
);

alter table plans enable row level security;

create policy plans_read on plans
    for select using (auth.role() = 'authenticated');

-- subscriptions: written by the RevenueCat webhook only (service
-- role, bypasses RLS) — client gets read-only access to its own row,
-- same shape as usage_counters in 0001.
create table subscriptions (
    id              uuid        primary key default gen_random_uuid(),
    user_id         uuid        not null references users(id),
    tier            plan_tier   not null references plans(tier),
    store           store_kind  not null,
    store_txn_id    varchar(150) unique,
    status          sub_status  not null default 'active',
    is_yearly       boolean     not null default false,

    trial_ends_at   timestamptz,
    started_at      timestamptz not null default now(),
    expires_at      timestamptz,
    canceled_at     timestamptz,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index subs_user_idx on subscriptions(user_id, status);

create trigger trg_subs_upd before update on subscriptions
    for each row execute function set_updated_at();

alter table subscriptions enable row level security;

create policy subscriptions_select on subscriptions
    for select using (auth.uid() = user_id);

create table reminders (
    id              uuid        primary key default gen_random_uuid(),
    pet_id          uuid        not null references pets(id) on delete cascade,
    user_id         uuid        not null references users(id) on delete cascade,

    source_id       uuid,
    due_on          date,
    fire_at         timestamptz not null,

    title           varchar(150) not null,
    body            text,
    status          reminder_status not null default 'pending',
    sent_at         timestamptz,
    created_at      timestamptz not null default now()
);

create index reminders_fire_idx on reminders(fire_at) where status = 'pending';
create index reminders_pet_idx  on reminders(pet_id, fire_at);
create unique index reminders_dedupe_uidx on reminders(pet_id, source_id, fire_at)
    where source_id is not null;

alter table reminders enable row level security;

create policy reminders_select on reminders
    for select using (auth.uid() = user_id);
create policy reminders_insert on reminders
    for insert with check (auth.uid() = user_id);
create policy reminders_update on reminders
    for update using (auth.uid() = user_id);
create policy reminders_delete on reminders
    for delete using (auth.uid() = user_id);

-- what a user is allowed to do right now
create view user_limits with (security_invoker = true) as
select u.id as user_id, u.tier,
       (u.tier = 'free' or u.tier_expires_at > now()) as is_valid,
       p.max_pets, p.scans_per_day, p.chats_per_day, p.max_members_per_pet,
       p.has_cloud_photos, p.has_nutrition, p.has_recall_alerts
from users u
join plans p on p.tier = u.tier
where u.deleted_at is null;

create view reminders_to_send with (security_invoker = true) as
select * from reminders where status = 'pending' and fire_at <= now();
