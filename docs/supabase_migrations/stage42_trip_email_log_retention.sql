-- =============================================================================
-- Stage 42 — Retention policy for trip_email_forward_log.
--
-- Found during the 2026-08-12 legal/privacy audit: trip_email_forward_log
-- (stage27) stores a third party's email address (from_address — often a
-- non-Kumo-user, e.g. an airline or hotel) and subject line indefinitely,
-- with no TTL. The table is intentionally metadata-only (no message body is
-- ever stored — see stage27's own comment), but an unbounded retention
-- window on a real person's email address is still a gap worth closing.
--
-- This adds a SECURITY DEFINER purge function that deletes forward-log rows
-- older than 90 days, and schedules it via pg_cron IF that extension is
-- already enabled on this project. pg_cron is NOT enabled by default on
-- Supabase projects — enabling it is a one-time dashboard action (Database
-- → Extensions → pg_cron), not something a SQL migration can safely do
-- unconditionally (it would fail the whole migration on projects where the
-- extension isn't available). The DO block below is a no-op if pg_cron
-- isn't present, so this migration is safe to run either way.
--
-- If pg_cron ends up not being enabled for this project, call
-- `select public.purge_old_trip_email_forward_log();` from an existing
-- scheduled Edge Function invocation (or Supabase's own Cron Jobs UI, which
-- wraps pg_cron) as the alternative — either way, someone needs to confirm
-- one of these two paths is actually active post-deploy; this migration
-- alone only guarantees the function exists and the schedule *will* be
-- created wherever pg_cron is already on.
--
-- Safe to re-run: uses CREATE OR REPLACE.
-- =============================================================================

create or replace function public.purge_old_trip_email_forward_log()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.trip_email_forward_log
  where created_at < now() - interval '90 days';
end;
$$;

revoke all on function public.purge_old_trip_email_forward_log() from public, anon, authenticated;
grant execute on function public.purge_old_trip_email_forward_log() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- cron.schedule() replaces the existing job when called again with the
    -- same job name, so this is idempotent on re-run.
    perform cron.schedule(
      'purge-trip-email-forward-log',
      '17 3 * * *', -- daily at 03:17 UTC
      $cron$select public.purge_old_trip_email_forward_log();$cron$
    );
  end if;
end $$;
