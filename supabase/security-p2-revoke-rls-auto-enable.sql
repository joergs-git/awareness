-- Awareness — security audit 2026-10-16, finding P2 (LOW)
-- APPLIED on 2026-10-24 to project dntkhnjmczkqluwgddir (migration "security_p2_revoke_rls_auto_enable").
-- Kept in the repo for the record; re-running it is harmless.
--
-- The SECURITY DEFINER event-trigger helper public.rls_auto_enable() was executable by the
-- anon and authenticated roles through /rest/v1/rpc/rls_auto_enable (two Supabase security
-- advisor warnings). It is only meant to run as an event trigger, never as an API call.
-- No app version calls it, so there is no client impact.

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
