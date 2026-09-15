-- ================================================================
--  Align 0001 with db-design/00_core.sql more closely, per review.
--  Run this once against a project that already has 0001 applied —
--  0001_init.sql in this repo has since been corrected in place, so
--  a *fresh* install only needs 0001, not this file. Two real
--  deviations fixed here for an already-migrated project:
--
--  1. pets.owner_id / scans.user_id had `on delete cascade` added —
--     db-design/00_core.sql just has a plain `REFERENCES users(id)`
--     (no cascade). Restoring that exact FK behaviour.
--
--  2. pet_members / user_pets (household sharing) were dropped
--     entirely as "not wired to code yet." Restoring them from
--     db-design/00_core.sql as-written — the table can exist unused
--     until Module 2's sharing feature is built, same as any other
--     not-yet-built table would.
--
--  Two deliberate, discussed deviations from db-design/00_core.sql
--  are NOT reverted here (both confirmed with the user):
--   - users.id is the Supabase auth uid directly, not a separate
--     gen_random_uuid() surrogate with a firebase_uid mirror column
--     (that column existed only to translate a Firebase string uid
--     into a Postgres uuid; Supabase's auth.users.id is already a
--     native uuid, so the translation layer has nothing to do).
--   - pets.breed_id stays a text slug with no breeds table, per PRD
--     §9 (breed reference data is a bundled JSON asset, never
--     queried) — db-design/00_core.sql's `breeds` table describes
--     the reference schema, not what the app actually reads from.
-- ================================================================

-- ----------------------------------------------------------------
-- 1. FK behaviour fix — drop the cascade this migration's first
--    pass added, match db-design/00_core.sql exactly.
-- ----------------------------------------------------------------
alter table pets  drop constraint pets_owner_id_fkey;
alter table pets  add constraint pets_owner_id_fkey  foreign key (owner_id) references users(id);

alter table scans drop constraint scans_user_id_fkey;
alter table scans add constraint scans_user_id_fkey foreign key (user_id) references users(id);

-- ----------------------------------------------------------------
-- 2. PET MEMBERS  (household sharing — a paid feature, db-design/00_core.sql)
-- ----------------------------------------------------------------
create type member_role as enum ('owner', 'member');

create table pet_members (
    pet_id      uuid        not null references pets(id) on delete cascade,
    user_id     uuid        not null references users(id) on delete cascade,
    role        member_role not null default 'member',
    joined_at   timestamptz not null default now(),
    primary key (pet_id, user_id)
);

create index pet_members_user_idx on pet_members(user_id);

-- every pet a user can see, owned or shared (db-design/00_core.sql).
-- security_invoker so it enforces the *querying* user's RLS, not the
-- view definer's — the Supabase-recommended pattern for views over
-- RLS-protected tables.
create view user_pets with (security_invoker = true) as
select m.user_id, m.role, p.*
from pets p
join pet_members m on m.pet_id = p.id
where p.deleted_at is null;

-- RLS: not reachable from the app yet (no sharing UI built), but
-- gated the same way every other table here is, not left wide open.
alter table pet_members enable row level security;

-- security definer + stable: called from pet_members' own RLS
-- policies below, so it must see the pets row regardless of the
-- caller's RLS visibility into pets, or a non-owner member's queries
-- would recurse into a false negative.
create or replace function is_pet_owner(p_pet_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from pets where id = p_pet_id and owner_id = auth.uid()
  );
$$;

grant execute on function is_pet_owner(uuid) to authenticated;

create policy pet_members_select on pet_members
    for select using (is_pet_owner(pet_id) or user_id = auth.uid());
create policy pet_members_insert on pet_members
    for insert with check (is_pet_owner(pet_id));
create policy pet_members_delete on pet_members
    for delete using (is_pet_owner(pet_id));
