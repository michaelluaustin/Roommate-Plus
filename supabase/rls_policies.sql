-- Roommate+ database setup
--
-- Creates any missing tables, then applies RLS policies.
-- Safe to re-run in Supabase Dashboard → SQL Editor.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by_user_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  email text,
  rotation_order integer not null,
  paused_until timestamptz,
  status text,
  status_updated_at timestamptz,
  created_at timestamptz not null default now()
);

-- Add status columns to pre-existing users tables (safe to re-run).
alter table public.users add column if not exists status text;
alter table public.users add column if not exists status_updated_at timestamptz;
alter table public.users add column if not exists avatar_url text;
alter table public.users add column if not exists avatar_updated_at timestamptz;
alter table public.users add column if not exists venmo_username text;
alter table public.users add column if not exists zelle_phone text;

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  current_assignee_id uuid references public.users (id),
  last_fulfilled_by_user_id uuid references public.users (id),
  last_fulfilled_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.join_codes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  code text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.history (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  fulfilled_by_user_id uuid not null references public.users (id),
  fulfilled_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  created_by_user_id uuid not null references public.users (id),
  title text not null,
  note text,
  amount_cents integer not null check (amount_cents > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.expense_participants (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.users (id),
  share_cents integer not null check (share_cents >= 0),
  settled_at timestamptz,
  settled_by_user_id uuid references public.users (id),
  unique (expense_id, user_id)
);

create index if not exists users_household_id_idx on public.users (household_id);
create index if not exists items_household_id_idx on public.items (household_id);
create index if not exists join_codes_code_idx on public.join_codes (code);
create index if not exists join_codes_expires_at_idx on public.join_codes (expires_at);
create index if not exists history_household_id_idx on public.history (household_id);
create index if not exists expenses_household_id_idx on public.expenses (household_id);
create index if not exists expense_participants_expense_id_idx on public.expense_participants (expense_id);

-- ---------------------------------------------------------------------------
-- Row-level security (app uses publishable/anon key, no Supabase Auth)
-- ---------------------------------------------------------------------------

-- Remove any existing policies first. Old policies (e.g. ones that query
-- users from within a users policy) cause "infinite recursion" errors.
do $$
declare
  pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('households', 'users', 'items', 'join_codes', 'history', 'expenses', 'expense_participants')
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      pol.policyname,
      pol.schemaname,
      pol.tablename
    );
  end loop;
end $$;

alter table public.households enable row level security;
create policy "anon_all_households"
  on public.households
  for all
  to anon
  using (true)
  with check (true);

alter table public.users enable row level security;
create policy "anon_all_users"
  on public.users
  for all
  to anon
  using (true)
  with check (true);

alter table public.items enable row level security;
create policy "anon_all_items"
  on public.items
  for all
  to anon
  using (true)
  with check (true);

alter table public.join_codes enable row level security;
create policy "anon_all_join_codes"
  on public.join_codes
  for all
  to anon
  using (true)
  with check (true);

alter table public.history enable row level security;
create policy "anon_all_history"
  on public.history
  for all
  to anon
  using (true)
  with check (true);

alter table public.expenses enable row level security;
create policy "anon_all_expenses"
  on public.expenses
  for all
  to anon
  using (true)
  with check (true);

alter table public.expense_participants enable row level security;
create policy "anon_all_expense_participants"
  on public.expense_participants
  for all
  to anon
  using (true)
  with check (true);

-- Ensure deleting an item also removes its history rows.
alter table public.history drop constraint if exists history_item_id_fkey;
alter table public.history
  add constraint history_item_id_fkey
  foreign key (item_id) references public.items (id) on delete cascade;

-- ---------------------------------------------------------------------------
-- Storage: profile photos (public read; anon upload for this app's model)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'anon_avatar%'
  loop
    execute format('drop policy if exists %I on storage.objects', pol.policyname);
  end loop;
end $$;

create policy "anon_avatar_select"
  on storage.objects
  for select
  to anon
  using (bucket_id = 'avatars');

create policy "anon_avatar_insert"
  on storage.objects
  for insert
  to anon
  with check (bucket_id = 'avatars');

create policy "anon_avatar_update"
  on storage.objects
  for update
  to anon
  using (bucket_id = 'avatars');

create policy "anon_avatar_delete"
  on storage.objects
  for delete
  to anon
  using (bucket_id = 'avatars');

-- ---------------------------------------------------------------------------
-- Realtime: push table changes to connected apps (live sync across phones)
-- ---------------------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.items;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.users;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expenses;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expense_participants;
exception when duplicate_object then null;
end $$;
