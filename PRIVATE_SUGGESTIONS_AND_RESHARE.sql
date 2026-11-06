-- Aurem World: reshare + private suggestions + admin-only suggestion reading
-- Run in Supabase SQL Editor. Does not delete posts, accounts, messages, or existing tables.

create table if not exists public.reshares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, post_id)
);
alter table public.reshares add column if not exists user_id uuid references public.profiles(id) on delete cascade;
alter table public.reshares add column if not exists post_id uuid references public.posts(id) on delete cascade;
alter table public.reshares add column if not exists created_at timestamptz not null default now();
create unique index if not exists reshares_user_post_unique on public.reshares(user_id, post_id);
alter table public.reshares enable row level security;
drop policy if exists "reshares readable by everyone" on public.reshares;
create policy "reshares readable by everyone" on public.reshares for select using (true);
drop policy if exists "users manage own reshares" on public.reshares;
create policy "users manage own reshares" on public.reshares for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table public.suggestions enable row level security;
drop policy if exists "users submit suggestions" on public.suggestions;
create policy "users submit suggestions" on public.suggestions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "suggestion owners read own" on public.suggestions;
drop policy if exists "admin reads suggestions" on public.suggestions;

-- Only a database administrator can add rows to this allow-list.
create table if not exists public.app_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.app_admins enable row level security;
drop policy if exists "admins can read own admin record" on public.app_admins;
create policy "admins can read own admin record" on public.app_admins for select to authenticated using (auth.uid() = user_id);
create policy "admin reads suggestions" on public.suggestions for select to authenticated
using (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

-- Register @anonymous_001 as the only admin. Confirm exactly one row is inserted.
insert into public.app_admins(user_id)
select id from public.profiles where lower(username) = 'anonymous_001'
on conflict (user_id) do nothing;

notify pgrst, 'reload schema';
