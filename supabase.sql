-- AUREM WORLD DATABASE SETUP
-- Run this entire file in Supabase > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check (char_length(username) between 3 and 24),
 display_name text,
 bio text default '',
 avatar_url text,
 is_verified boolean not null default false,
 is_admin boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 caption text default '',
 media_url text not null,
 media_path text not null,
 media_type text not null check (media_type in ('image','video')),
 visibility text not null default 'public' check (visibility in ('public','private')),
 created_at timestamptz not null default now()
);
create table if not exists public.follows (
 follower_id uuid references public.profiles(id) on delete cascade,
 following_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,following_id),
 check(follower_id <> following_id)
);
create table if not exists public.likes (
 user_id uuid references public.profiles(id) on delete cascade,
 post_id uuid references public.posts(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,post_id)
);
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table if not exists public.conversations (
 id uuid primary key default gen_random_uuid(),
 user_a uuid not null references public.profiles(id) on delete cascade,
 user_b uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(user_a <> user_b),
 unique(user_a,user_b)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2000),
 created_at timestamptz not null default now()
);
create or replace view public.post_counts as
 select p.id as post_id,
 (select count(*) from public.likes l where l.post_id=p.id) as like_count,
 (select count(*) from public.comments c where c.post_id=p.id) as comment_count
 from public.posts p;

-- Create a profile automatically after a user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare uname text;
begin
 uname := lower(coalesce(new.raw_user_meta_data->>'username','user_'||substr(new.id::text,1,8)));
 insert into public.profiles(id,username,display_name)
 values(new.id,uname,coalesce(new.raw_user_meta_data->>'display_name',uname))
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Optional owner auto-follow: set owner UUID in app_settings after creating owner account.
create table if not exists public.app_settings(key text primary key,value text not null);
create or replace function public.auto_follow_owner()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid;
begin
 select value::uuid into owner_id from public.app_settings where key='owner_user_id';
 if owner_id is not null and owner_id <> new.id then
  insert into public.follows(follower_id,following_id) values(new.id,owner_id) on conflict do nothing;
 end if;
 return new;
end; $$;
drop trigger if exists profile_auto_follow_owner on public.profiles;
create trigger profile_auto_follow_owner after insert on public.profiles
for each row execute procedure public.auto_follow_owner();

-- Secure conversation helper: users can only open a conversation with themselves and another profile.
create or replace function public.get_or_create_conversation(other_user_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare me uuid; a uuid; b uuid; cid uuid;
begin
 me := auth.uid();
 if me is null or me=other_user_id then raise exception 'Invalid conversation'; end if;
 a := least(me,other_user_id); b := greatest(me,other_user_id);
 insert into public.conversations(user_a,user_b) values(a,b)
 on conflict(user_a,user_b) do update set user_a=excluded.user_a
 returning id into cid;
 return cid;
end; $$;
grant execute on function public.get_or_create_conversation(uuid) to authenticated;

-- RLS
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.app_settings enable row level security;

create policy "profiles readable" on public.profiles for select using(true);
create policy "profile insert own" on public.profiles for insert with check(auth.uid()=id);
create policy "profile update own" on public.profiles for update using(auth.uid()=id) with check(auth.uid()=id);
create policy "public posts readable" on public.posts for select using(visibility='public' or auth.uid()=user_id);
create policy "posts create own" on public.posts for insert with check(auth.uid()=user_id);
create policy "posts update own" on public.posts for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "posts delete own" on public.posts for delete using(auth.uid()=user_id);
create policy "follows readable" on public.follows for select using(true);
create policy "follow as self" on public.follows for insert with check(auth.uid()=follower_id);
create policy "unfollow as self" on public.follows for delete using(auth.uid()=follower_id);
create policy "likes readable" on public.likes for select using(true);
create policy "like as self" on public.likes for insert with check(auth.uid()=user_id);
create policy "unlike as self" on public.likes for delete using(auth.uid()=user_id);
create policy "comments readable" on public.comments for select using(true);
create policy "comment as self" on public.comments for insert with check(auth.uid()=user_id);
create policy "delete own comment" on public.comments for delete using(auth.uid()=user_id);
create policy "conversation participants read" on public.conversations for select using(auth.uid()=user_a or auth.uid()=user_b);
create policy "conversation participants create" on public.conversations for insert with check(auth.uid()=user_a or auth.uid()=user_b);
create policy "messages participants read" on public.messages for select using(exists(select 1 from public.conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
create policy "messages sender insert" on public.messages for insert with check(auth.uid()=sender_id and exists(select 1 from public.conversations c where c.id=conversation_id and (c.user_a=auth.uid() or c.user_b=auth.uid())));
create policy "settings hidden" on public.app_settings for select using(false);

-- Public media bucket for post assets (do not store private documents here).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('media','media',true,209715200,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'])
on conflict(id) do nothing;
create policy "media public read" on storage.objects for select using(bucket_id='media');
create policy "users upload own media" on storage.objects for insert to authenticated
with check(bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "users delete own media" on storage.objects for delete to authenticated
using(bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);

-- IMPORTANT: create the owner account first. Then run the owner setup SQL
-- from SETUP.md with that account's UUID.
