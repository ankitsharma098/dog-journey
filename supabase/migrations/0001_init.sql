-- ================================================================
--  PawJourney :: initial Supabase schema
--  Adapted from db-design/00_core.sql + 01_breed_scanner.sql for
--  Supabase (Postgres + Auth + RLS) instead of Firebase Auth +
--  Firestore, following db-design/00_core.sql + 01_breed_scanner.sql
--  as closely as Supabase allows — see 0002_align_with_db_design.sql
--  for the two deliberate deviations (users.id, pets.breed_id) and
--  why. `breeds` stays a bundled JSON asset (assets/data/breeds.json),
--  never a table — PRD §9. Every not-yet-built module's tables
--  (health_records, chat_threads, etc.) are left out until those
--  modules exist; pet_members/user_pets (household sharing, already
--  in db-design/00_core.sql) are added in 0002.
-- ================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------
-- ENUMS
-- ----------------------------------------------------------------
create type species    as enum ('dog', 'cat');
create type pet_sex    as enum ('male', 'female', 'unknown');
create type plan_tier  as enum ('free', 'premium');
create type unit_system as enum ('metric', 'imperial');
create type scan_status as enum ('pending', 'done', 'failed');

-- ----------------------------------------------------------------
-- APP CONFIG
-- Server-side settings so a change is a SQL edit, not an app
-- release: the Gemini model name, the free scan limit, etc.
-- Public read (any signed-in user), no client write policy —
-- admin-managed via the SQL editor / dashboard only.
-- ----------------------------------------------------------------
create table app_config (
    key         varchar(60)  primary key,
    value       jsonb        not null,
    updated_at  timestamptz  not null default now()
);

-- ----------------------------------------------------------------
-- USERS
-- id is the Supabase auth user id directly (1:1 with auth.users) —
-- no separate firebase_uid mirror column needed, unlike the
-- Firebase version of this schema.
-- ----------------------------------------------------------------
create table users (
    id              uuid        primary key references auth.users(id) on delete cascade,
    email           varchar(255) not null,
    display_name    varchar(150),
    photo_url       text,

    locale          varchar(10) not null default 'en-US',
    timezone        varchar(50) not null default 'America/New_York',
    units           unit_system not null default 'imperial',

    -- denormalised so the paywall never needs a join
    tier            plan_tier   not null default 'free',
    tier_expires_at timestamptz,

    fcm_token       text,
    onboarding_done boolean     not null default false,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    deleted_at      timestamptz
);

-- ----------------------------------------------------------------
-- PETS
-- breed_id is the *slug* string from the bundled breeds.json
-- (e.g. "golden-retriever"), not a UUID FK — there's no breeds
-- table to reference.
-- ----------------------------------------------------------------
create table pets (
    id              uuid        primary key default gen_random_uuid(),
    owner_id        uuid        not null references users(id),
    species         species     not null default 'dog',
    name            varchar(100) not null,
    sex             pet_sex     not null default 'unknown',

    birthdate             date,
    birthdate_is_estimate boolean not null default false,
    adopted_date          date,
    is_neutered           boolean,
    photo_url             text,

    breed_id        text,
    breed_mix       jsonb       not null default '[]', -- [{breed_id, name, pct}]
    weight_kg       numeric(5,2),
    allergies       text[]      not null default '{}',

    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    deleted_at      timestamptz
);

create index pets_owner_idx on pets(owner_id) where deleted_at is null;

-- ----------------------------------------------------------------
-- SCANS
-- Mirrors db-design/01_breed_scanner.sql. result stays JSONB — it's
-- always read whole, never queried by individual breed.
-- ----------------------------------------------------------------
create table scans (
    id              uuid        primary key default gen_random_uuid(),
    user_id         uuid        not null references users(id),
    pet_id          uuid        references pets(id) on delete set null,
    species         species     not null default 'dog',

    photo_url       text        not null,
    image_hash      char(64)    not null,  -- sha256, cache key
    model_version   varchar(30) not null,
    status          scan_status not null default 'pending',

    result          jsonb       not null default '[]', -- [{breed_slug, name, pct, confidence}]
    species_matched boolean,
    from_cache      boolean     not null default false,
    error_code      varchar(40),

    created_at      timestamptz not null default now()
);

create index scans_user_idx  on scans(user_id, created_at desc);
create index scans_cache_idx on scans(user_id, image_hash, model_version) where status = 'done';

-- ----------------------------------------------------------------
-- USAGE COUNTERS
-- Per-user, per-day, per-kind quota (scans today; chat later —
-- see QuotaExceededFailure's doc comment in the Dart source, this
-- table was already scoped for both). date lives in its own column
-- (not encoded into a doc id like the Firestore version needed) —
-- a real composite primary key does the same job cleanly.
-- No insert/update RLS policy at all: every write goes through
-- reserve_scan_quota() below, which is the only thing allowed to
-- touch this table.
-- ----------------------------------------------------------------
create table usage_counters (
    user_id     uuid        not null references users(id) on delete cascade,
    kind        varchar(20) not null,
    date        date        not null default current_date,
    count       integer     not null default 0,
    "limit"     integer     not null,
    primary key (user_id, kind, date)
);

-- Atomic check-and-increment — replaces the Firestore transaction +
-- rules-based increment hack with one real SQL statement. Returns
-- true if the reservation succeeded, false if already at the cap.
-- security definer so it can write usage_counters despite no RLS
-- write policy existing on that table; auth.uid() (not a caller-
-- supplied id) is what it reserves against, so a client can only
-- ever spend its own quota.
create or replace function reserve_scan_quota(p_limit integer)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_reserved boolean;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  insert into usage_counters (user_id, kind, date, count, "limit")
  values (v_user_id, 'scans', current_date, 1, p_limit)
  on conflict (user_id, kind, date)
  do update set count = usage_counters.count + 1
  where usage_counters.count < p_limit
  returning true into v_reserved;

  return coalesce(v_reserved, false);
end;
$$;

grant execute on function reserve_scan_quota(integer) to authenticated;

-- ----------------------------------------------------------------
-- TRIGGERS
-- ----------------------------------------------------------------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger trg_users_upd before update on users for each row execute function set_updated_at();
create trigger trg_pets_upd  before update on pets  for each row execute function set_updated_at();

-- ================================================================
--  ROW LEVEL SECURITY  (replaces firestore.rules)
-- ================================================================

alter table app_config      enable row level security;
alter table users            enable row level security;
alter table pets             enable row level security;
alter table scans            enable row level security;
alter table usage_counters   enable row level security;

-- app_config: read-only to any signed-in user, no write policy
-- (admin/SQL-editor managed only).
create policy app_config_read on app_config
    for select using (auth.role() = 'authenticated');

-- users: a user can read/update only their own row, and can create
-- it only for their own id (the AuthRepository.signUp two-step:
-- auth.signUp() then this insert).
create policy users_select on users
    for select using (auth.uid() = id);
create policy users_insert on users
    for insert with check (auth.uid() = id);
create policy users_update on users
    for update using (auth.uid() = id);

-- pets: owner-only (household sharing isn't built yet — add a
-- pet_members-based policy alongside this when it is).
create policy pets_select on pets
    for select using (auth.uid() = owner_id);
create policy pets_insert on pets
    for insert with check (auth.uid() = owner_id);
create policy pets_update on pets
    for update using (auth.uid() = owner_id);
create policy pets_delete on pets
    for delete using (auth.uid() = owner_id);

-- scans: owner-only, append-only from the client (no update/delete
-- policy — a real "finalize" step, if ever needed, would be a
-- security-definer function like reserve_scan_quota, not a raw
-- client update).
create policy scans_select on scans
    for select using (auth.uid() = user_id);
create policy scans_insert on scans
    for insert with check (auth.uid() = user_id);

-- usage_counters: read-only to the owning user (for the pre-spend
-- hasQuota() peek); every write goes through reserve_scan_quota().
create policy usage_counters_select on usage_counters
    for select using (auth.uid() = user_id);

-- ================================================================
--  STORAGE
-- ================================================================

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

-- Authenticated users may upload only under their own uid prefix
-- (photos/{uid}/...); public read on the whole bucket (matches
-- what the Drive-link workaround already was this session — no
-- privacy regression, just no more service-account/OAuth dance).
create policy photos_insert on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy photos_read on storage.objects
    for select using (bucket_id = 'photos');
