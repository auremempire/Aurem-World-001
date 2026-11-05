-- Aurem World feature migration (additive; run once in Supabase SQL Editor)
-- This migration does not drop existing tables or policies.
create table if not exists public.reshares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, post_id)
);
alter table public.reshares enable row level security;
drop policy if exists "reshares readable by everyone" on public.reshares;
create policy "reshares readable by everyone" on public.reshares for select using (true);
drop policy if exists "users manage own reshares" on public.reshares;
create policy "users manage own reshares" on public.reshares for all
using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table public.suggestions enable row level security;
drop policy if exists "users submit suggestions" on public.suggestions;
create policy "users submit suggestions" on public.suggestions for insert to authenticated
with check (auth.uid() = user_id);
drop policy if exists "suggestion owners read own" on public.suggestions;
create policy "suggestion owners read own" on public.suggestions for select to authenticated
using (auth.uid() = user_id);
-- Admin read is intentionally not granted by username in SQL. Use a server-side
-- admin role/RPC for production; do not expose service-role keys in the browser.

create table if not exists public.user_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_seen timestamptz not null default now()
);
alter table public.user_presence enable row level security;
drop policy if exists "users update own presence" on public.user_presence;
create policy "users update own presence" on public.user_presence for all to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "signed in users read presence" on public.user_presence;
create policy "signed in users read presence" on public.user_presence for select to authenticated using (true);

create table if not exists public.chat_activity (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_date date not null default current_date,
  primary key(conversation_id,user_id,activity_date)
);
alter table public.chat_activity enable row level security;
drop policy if exists "chat participants read activity" on public.chat_activity;
create policy "chat participants read activity" on public.chat_activity for select to authenticated
using (exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in (c.user_a,c.user_b)));
drop policy if exists "users record own chat activity" on public.chat_activity;
create policy "users record own chat activity" on public.chat_activity for insert to authenticated
with check (auth.uid()=user_id and exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in (c.user_a,c.user_b)));

create or replace function public.record_chat_activity(p_conversation_id uuid)
returns void language plpgsql security invoker as $$
begin
  if not exists(select 1 from public.conversations c where c.id=p_conversation_id and auth.uid() in (c.user_a,c.user_b)) then
    raise exception 'Not a conversation participant';
  end if;
  insert into public.chat_activity(conversation_id,user_id,activity_date)
  values(p_conversation_id,auth.uid(),current_date) on conflict do nothing;
end; $$;
grant execute on function public.record_chat_activity(uuid) to authenticated;

insert into storage.buckets(id,name,public)
values('voice-notes','voice-notes',true)
on conflict(id) do nothing;
drop policy if exists "voice notes upload own" on storage.objects;
create policy "voice notes upload own" on storage.objects for insert to authenticated
with check (bucket_id='voice-notes' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "voice notes public read" on storage.objects;
create policy "voice notes public read" on storage.objects for select
using (bucket_id='voice-notes');
