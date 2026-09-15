-- ================================================================
--  0007: real account deletion.
-- ================================================================
--
-- Settings screen's "Delete account" button (lib/features/settings/
-- presentation/screens/settings_screen.dart) signed the user out and
-- claimed "Account deletion requested" without ever deleting
-- anything — the actual delete was a `// TODO`. A client can't call
-- the GoTrue Admin API directly (that needs the service-role key,
-- which must never ship in the app), so this is a security-definer
-- RPC instead: it runs as the function owner (which has access to
-- the `auth` schema on a Supabase-managed project), deletes the
-- caller's own `auth.users` row, and every other table cascades from
-- there — `public.users.id references auth.users(id) on delete
-- cascade` (0001_init.sql), and everything else cascades from
-- `users(id)` in turn.

create or replace function delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function delete_user() to authenticated;
