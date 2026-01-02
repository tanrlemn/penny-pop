-- Chunk 3 — Household + Membership (Minimal, Partner-ready)
-- Schema:
-- - profiles (email -> user_id lookup for admin add-by-email)
-- - households
-- - household_members
-- - RPC: ensure_active_household()
-- - RPC: add_household_member_by_email(household_id, email)

-- Extensions
create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  -- Email can be null (some providers may not supply it). Unique allows multiple nulls.
  email citext unique,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- Keep profile rows in sync with auth.users.
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- If provider doesn't supply email, skip profile insert so signups don't fail.
  if new.email is null then
    return new;
  end if;

  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update
    set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row
execute function public.handle_new_user_profile();

-- ---------------------------------------------------------------------------
-- households + household_members
-- ---------------------------------------------------------------------------

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Lemon Household',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index if not exists household_members_user_id_idx
on public.household_members (user_id);

alter table public.households enable row level security;
alter table public.household_members enable row level security;

-- RLS: households select if you're a member
drop policy if exists "households_select_for_members" on public.households;
create policy "households_select_for_members"
on public.households
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = households.id
      and hm.user_id = auth.uid()
  )
);

-- RLS: household_members select if you're a member of that household
drop policy if exists "household_members_select_for_members" on public.household_members;
create policy "household_members_select_for_members"
on public.household_members
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = household_members.household_id
      and hm.user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- RPC: ensure_active_household()
-- ---------------------------------------------------------------------------

create or replace function public.ensure_active_household()
returns table (
  household_id uuid,
  household_name text,
  role text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_household_id uuid;
  v_household_name text;
  v_role text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select hm.household_id, h.name, hm.role
    into v_household_id, v_household_name, v_role
  from public.household_members hm
  join public.households h on h.id = hm.household_id
  where hm.user_id = v_user_id
  order by hm.created_at asc
  limit 1;

  if v_household_id is not null then
    household_id := v_household_id;
    household_name := v_household_name;
    role := v_role;
    return next;
    return;
  end if;

  insert into public.households (name, created_by)
  values ('Lemon Household', v_user_id)
  returning id, name into v_household_id, v_household_name;

  insert into public.household_members (household_id, user_id, role)
  values (v_household_id, v_user_id, 'admin');

  household_id := v_household_id;
  household_name := v_household_name;
  role := 'admin';
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: add_household_member_by_email(household_id, email)
-- ---------------------------------------------------------------------------

create or replace function public.add_household_member_by_email(
  p_household_id uuid,
  p_email text
)
returns table (
  household_id uuid,
  user_id uuid,
  role text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_user_id uuid;
  v_target_user_id uuid;
begin
  v_admin_user_id := auth.uid();
  if v_admin_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if p_household_id is null then
    raise exception 'Missing household id';
  end if;
  if p_email is null or btrim(p_email) = '' then
    raise exception 'Missing email';
  end if;

  if not exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.user_id = v_admin_user_id
      and hm.role = 'admin'
  ) then
    raise exception 'Only admins can add household members';
  end if;

  select p.id
    into v_target_user_id
  from public.profiles p
  where p.email = p_email::citext
  limit 1;

  if v_target_user_id is null then
    raise exception 'No user found for email % (they must sign in once first)', p_email;
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (p_household_id, v_target_user_id, 'member')
  on conflict (household_id, user_id) do nothing;

  return query
  select hm.household_id, hm.user_id, hm.role
  from public.household_members hm
  where hm.household_id = p_household_id
    and hm.user_id = v_target_user_id;
end;
$$;


