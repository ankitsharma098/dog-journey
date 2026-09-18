-- ================================================================
--  VET CHAT QUOTA
-- ================================================================
-- Mirrors reserve_scan_quota() (0001_init.sql) for the 'chat' kind
-- on the same usage_counters table — that table and RLS were already
-- shaped for this (see 0001's comment: "kind = 'scans' leaves room
-- for a 'chat' sibling"), and ChatRepository.incrementUsage already
-- queried this exact shape (kind='chat', daily date key) but never
-- actually wrote to it; its own comment says "the real gate is in
-- the increment_usage RPC", which this is. VetChatCubit previously
-- only tracked usage in an in-memory counter that reset on every
-- cubit recreation, so free-tier chat was unlimited in practice.
create or replace function reserve_chat_quota(p_limit integer)
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
  values (v_user_id, 'chat', current_date, 1, p_limit)
  on conflict (user_id, kind, date)
  do update set count = usage_counters.count + 1
  where usage_counters.count < p_limit
  returning true into v_reserved;

  return coalesce(v_reserved, false);
end;
$$;

grant execute on function reserve_chat_quota(integer) to authenticated;
