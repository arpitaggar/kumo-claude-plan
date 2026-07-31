-- Stage 20: Fix push_tokens — pre-existing table collided with stage19's spec
--
-- `push_tokens` already existed in this database (from something unrelated
-- to this repo's migration history — no migration here ever created it)
-- before stage19_chat_upgrade.sql ran. Because that migration used
-- `create table if not exists`, it silently kept the pre-existing table
-- instead of creating the one it defines, which surfaced as two separate
-- bugs discovered live:
--
--   1. No unique/exclusion constraint spans exactly (user_id, token), so
--      upsert_push_token()'s `on conflict (user_id, token)` always failed
--      with "there is no unique or exclusion constraint matching the ON
--      CONFLICT specification".
--
--   2. push_tokens_user_id_fkey references an unrelated `public.users`
--      table (not `auth.users`, which every other table in this app's
--      schema uses per stage1/stage2/stage16/stage19 conventions), so
--      even after fixing (1), inserts failed with "insert or update on
--      table push_tokens violates foreign key constraint
--      push_tokens_user_id_fkey" for real authenticated users who simply
--      have no row in that unrelated table.
--
-- Net effect: every upsert_push_token() call has failed since push
-- notifications were built — no device has ever registered a token, so
-- send-message-push always finds zero recipients and no notification is
-- ever delivered, on any device.
--
-- The table is guaranteed to have zero real rows (every write attempt has
-- errored out), so instead of patching constraints one at a time, this
-- drops and recreates it cleanly per the original stage19 spec.

drop table if exists public.push_tokens cascade;

create table public.push_tokens (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  token      text        not null,
  platform   text        not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.push_tokens enable row level security;

create policy "push_tokens_owner_all" on public.push_tokens
  for all
  using     (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.upsert_push_token(p_token text, p_platform text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.push_tokens (user_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (user_id, token)
  do update set platform = excluded.platform, updated_at = now();
$$;

revoke all on function public.upsert_push_token(text, text) from anon;
grant execute on function public.upsert_push_token(text, text) to authenticated;
