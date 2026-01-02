-- Chunk 4 — Pods Sync from Sequence + Metadata (Household-scoped)
--
-- Tables:
-- - pods (synced from Sequence; no in-app creation)
-- - pod_settings (metadata managed in-app)

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- pods
-- ---------------------------------------------------------------------------

create table if not exists public.pods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  sequence_account_id text not null,
  name text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  constraint pods_household_sequence_account_unique unique (household_id, sequence_account_id)
);

create index if not exists pods_household_active_idx
on public.pods (household_id, is_active);

create index if not exists pods_household_last_seen_idx
on public.pods (household_id, last_seen_at);

alter table public.pods enable row level security;

drop policy if exists "pods_select_for_household_members" on public.pods;
create policy "pods_select_for_household_members"
on public.pods
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = pods.household_id
      and hm.user_id = auth.uid()
  )
);

-- Intentionally no INSERT/UPDATE/DELETE policies.
-- Sync happens via Supabase Edge Function using service role.

-- ---------------------------------------------------------------------------
-- pod_settings
-- ---------------------------------------------------------------------------

create table if not exists public.pod_settings (
  pod_id uuid primary key references public.pods(id) on delete cascade,
  category text check (
    category is null
    or category in ('Savings', 'Kiddos', 'Necessities', 'Pressing', 'Discretionary')
  ),
  notes text,
  updated_at timestamptz not null default now()
);

alter table public.pod_settings enable row level security;

drop policy if exists "pod_settings_select_for_household_members" on public.pod_settings;
create policy "pod_settings_select_for_household_members"
on public.pod_settings
for select
to authenticated
using (
  exists (
    select 1
    from public.pods p
    join public.household_members hm on hm.household_id = p.household_id
    where p.id = pod_settings.pod_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "pod_settings_insert_for_household_members" on public.pod_settings;
create policy "pod_settings_insert_for_household_members"
on public.pod_settings
for insert
to authenticated
with check (
  exists (
    select 1
    from public.pods p
    join public.household_members hm on hm.household_id = p.household_id
    where p.id = pod_settings.pod_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "pod_settings_update_for_household_members" on public.pod_settings;
create policy "pod_settings_update_for_household_members"
on public.pod_settings
for update
to authenticated
using (
  exists (
    select 1
    from public.pods p
    join public.household_members hm on hm.household_id = p.household_id
    where p.id = pod_settings.pod_id
      and hm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.pods p
    join public.household_members hm on hm.household_id = p.household_id
    where p.id = pod_settings.pod_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "pod_settings_delete_for_household_members" on public.pod_settings;
create policy "pod_settings_delete_for_household_members"
on public.pod_settings
for delete
to authenticated
using (
  exists (
    select 1
    from public.pods p
    join public.household_members hm on hm.household_id = p.household_id
    where p.id = pod_settings.pod_id
      and hm.user_id = auth.uid()
  )
);


