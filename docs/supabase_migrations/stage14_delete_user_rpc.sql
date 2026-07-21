-- Stage 14: GDPR — account self-deletion RPC
--
-- Allows an authenticated user to delete their own auth.users row.
-- Cascades automatically to all app tables via FK ON DELETE CASCADE.
-- Called client-side via supabase.rpc('delete_user').
--
-- Run in Supabase SQL editor.

create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = public
as $$
  delete from auth.users where id = auth.uid();
$$;

-- Only authenticated users can call this
revoke all on function public.delete_user() from anon;
grant execute on function public.delete_user() to authenticated;
