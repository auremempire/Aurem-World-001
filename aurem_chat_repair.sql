-- AUREM WORLD: CHAT / INBOX REPAIR
-- Safe additive migration. It does not delete existing tables, messages, or policies.
-- Run this in Supabase SQL Editor while signed in as project owner.

begin;

-- Ensure authenticated users can read conversation rows only when they participate.
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='conversations'
      and policyname='aurem_chat_participants_read'
  ) then
    create policy aurem_chat_participants_read
      on public.conversations for select to authenticated
      using (
        auth.uid() = user_one or auth.uid() = user_two
        or auth.uid() = user_a or auth.uid() = user_b
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='messages'
      and policyname='aurem_chat_participants_read'
  ) then
    create policy aurem_chat_participants_read
      on public.messages for select to authenticated
      using (
        exists (
          select 1 from public.conversations c
          where c.id = messages.conversation_id
            and (
              auth.uid() = c.user_one or auth.uid() = c.user_two
              or auth.uid() = c.user_a or auth.uid() = c.user_b
            )
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='messages'
      and policyname='aurem_chat_participants_send'
  ) then
    create policy aurem_chat_participants_send
      on public.messages for insert to authenticated
      with check (
        sender_id = auth.uid()
        and exists (
          select 1 from public.conversations c
          where c.id = messages.conversation_id
            and (
              auth.uid() = c.user_one or auth.uid() = c.user_two
              or auth.uid() = c.user_a or auth.uid() = c.user_b
            )
        )
      );
  end if;
end $$;

grant select on public.conversations to authenticated;
grant select, insert on public.messages to authenticated;

-- Ensure the existing RPC can be called by signed-in users.
grant execute on function public.get_or_create_conversation(uuid) to authenticated;

commit;

-- VERIFICATION QUERY 1: should return the policies above plus any existing policies.
select tablename, policyname, cmd
from pg_policies
where schemaname='public'
  and tablename in ('conversations','messages')
order by tablename, policyname;

-- VERIFICATION QUERY 2: function should appear as one row.
select routine_name, routine_type
from information_schema.routines
where routine_schema='public'
  and routine_name='get_or_create_conversation';
