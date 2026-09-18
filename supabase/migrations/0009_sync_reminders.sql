-- ================================================================
--  SYNC REMINDERS
-- ================================================================
-- HealthRecordRepository.syncReminders(id) has called this RPC since
-- it was written, but the function itself was never created — every
-- call to it 404s with PGRST202 (visible in logs right after adding
-- any record with a due date). The `reminders` table and its RLS
-- (0003_remaining_modules.sql) were already in place for this; this
-- just fills in the missing function.
--
-- "Sync" means reconcile, not append: delete-then-recreate rather
-- than insert-if-absent, so editing a record's due date (or clearing
-- it) moves/removes its reminder instead of leaving a stale one
-- alongside a new one.
create or replace function sync_reminders(p_health_record_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_pet_id uuid;
  v_title varchar(150);
  v_due_on date;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select hr.pet_id, hr.title, hr.due_on
    into v_pet_id, v_title, v_due_on
  from health_records hr
  where hr.id = p_health_record_id;

  -- Record not found (bad id, or deleted between the write and this
  -- call) — nothing to reconcile.
  if v_pet_id is null then
    return;
  end if;

  delete from reminders
  where source_id = p_health_record_id
    and user_id = v_user_id;

  if v_due_on is not null then
    insert into reminders (pet_id, user_id, source_id, due_on, fire_at, title, body)
    values (
      v_pet_id,
      v_user_id,
      p_health_record_id,
      v_due_on,
      (v_due_on::timestamp + interval '9 hours') at time zone 'utc',
      coalesce(v_title, 'Care reminder'),
      'Due today for your dog.'
    );
  end if;
end;
$$;

grant execute on function sync_reminders(uuid) to authenticated;
