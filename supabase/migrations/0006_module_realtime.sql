-- ================================================================
--  0006: enable Realtime replication for the module tables that
--  stream via SupabaseRepository.watchQuery() / .stream().
-- ================================================================
--
-- Same gap as 0005, just for the other three live-updating tables:
--   - HealthPassportCubit watches `health_records` (pet_id filter)
--   - TimelineRepository.watchByPet() watches `timeline_entries`
--   - ChatRepository.watchMessages() watches `chat_messages`
-- None of them were ever added to the `supabase_realtime` publication,
-- so every subscribe attempt fails immediately with
-- "Unable to subscribe to changes ... Please check Realtime is
-- enabled", and each screen falls back to its error state instead of
-- ever receiving data.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'health_records'
  ) then
    alter publication supabase_realtime add table health_records;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'timeline_entries'
  ) then
    alter publication supabase_realtime add table timeline_entries;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table chat_messages;
  end if;
end $$;
