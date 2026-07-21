-- Stage 15: Read receipts for chat messages
--
-- Adds a read_by text[] column that stores the user IDs (as text) of
-- members who have opened the chat and seen the message.
-- A SECURITY DEFINER RPC is used so members can mark messages as read
-- without needing a broad UPDATE policy on the messages table.
--
-- Run in Supabase SQL editor.

alter table public.messages
  add column if not exists read_by text[] not null default '{}';

-- RPC: atomically appends the caller's user_id to read_by for all
-- unread messages in a given itinerary that were not sent by the caller.
create or replace function public.mark_messages_read(p_itinerary_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.messages
  set read_by = array_append(read_by, auth.uid()::text)
  where itinerary_id = p_itinerary_id
    and sender_id    != auth.uid()
    and not (read_by @> array[auth.uid()::text]);
$$;

revoke all on function public.mark_messages_read(uuid) from anon;
grant execute on function public.mark_messages_read(uuid) to authenticated;
