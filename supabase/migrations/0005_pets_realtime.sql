-- ================================================================
--  0005: enable Realtime replication for `pets`.
-- ================================================================
--
-- PetRepository.watchOwnedBy() (lib/features/pets/data/repositories/
-- pet_repository.dart) subscribes via SupabaseRepository.watchQuery(),
-- which is a Postgres Changes realtime subscription under the hood —
-- but a table only streams changes once it's added to the
-- `supabase_realtime` publication (off by default; none of the prior
-- migrations turned it on). Without it, PetsBloc's subscribe call
-- fails immediately with "Unable to subscribe to changes ... Please
-- check Realtime is enabled", PetsBloc sits in PetsStatus.error, and
-- everything downstream that waits on "does this user have a pet yet"
-- (the router's onboarding redirect, AddPetScreen's submit button
-- staying disabled past `success` to prevent a double-submit) hangs
-- forever, since that confirmation never arrives.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pets'
  ) then
    alter publication supabase_realtime add table pets;
  end if;
end $$;
