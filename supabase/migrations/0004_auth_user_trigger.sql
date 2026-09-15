-- ================================================================
--  0004: create the `public.users` row via a trigger on
--  `auth.users` insert, instead of a client-side INSERT right
--  after auth.signUp().
-- ================================================================
--
-- Bug: AuthRepository.signUp() (lib/features/auth/data/repositories/
-- auth_repository.dart) used to call auth.signUp() and then insert the
-- public.users row itself, in the same client call. That insert is
-- gated by RLS policy `users_insert` (auth.uid() = id) — but
-- auth.signUp() doesn't hand back an active session until the new
-- user confirms their email (whenever Supabase's "Confirm email"
-- setting is on for the project, which is the default). So the insert
-- ran with no session, auth.uid() was null, and it hit
-- "new row violates row-level security policy for table users"
-- (Postgres code 42501) on every sign-up. Net effect: the
-- auth.users account existed but public.users never did, and the
-- account was permanently stuck (can't sign in — no profile row —
-- and can't sign up again — email already exists).
--
-- Fix: do it server-side, the same way reserve_scan_quota() (0001)
-- bypasses RLS for usage_counters — a security definer function,
-- owned by a role that isn't subject to `users`' RLS, so it works
-- with or without a client session. AuthRepository.signUp() now only
-- patches locale/timezone/units (device-specific, unknowable here) as
-- a best-effort follow-up when a session happens to exist already.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
