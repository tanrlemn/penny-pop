-- Income Sources v1 — budget-only income breakdown (no effect on Sequence pods).
--
-- Adds `public.income_sources` scoped by household, editable in-app.
--
-- Fields:
-- - name: label for the source (e.g. "Redline", "MRO", "SSA")
-- - budgeted_amount_in_cents: planned income amount used for budget math
-- - is_active: soft-delete / archive
-- - sort_order: optional stable ordering in UI

create extension if not exists pgcrypto;

create table if not exists public.income_sources (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  budgeted_amount_in_cents bigint not null default 0,
  is_active boolean not null default true,
  sort_order int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint income_sources_household_name_unique unique (household_id, name)
);

create index if not exists income_sources_household_active_idx
on public.income_sources (household_id, is_active);

alter table public.income_sources enable row level security;

drop policy if exists "income_sources_select_for_household_members" on public.income_sources;
create policy "income_sources_select_for_household_members"
on public.income_sources
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = income_sources.household_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "income_sources_insert_for_household_members" on public.income_sources;
create policy "income_sources_insert_for_household_members"
on public.income_sources
for insert
to authenticated
with check (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = income_sources.household_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "income_sources_update_for_household_members" on public.income_sources;
create policy "income_sources_update_for_household_members"
on public.income_sources
for update
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = income_sources.household_id
      and hm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = income_sources.household_id
      and hm.user_id = auth.uid()
  )
);

drop policy if exists "income_sources_delete_for_household_members" on public.income_sources;
create policy "income_sources_delete_for_household_members"
on public.income_sources
for delete
to authenticated
using (
  exists (
    select 1
    from public.household_members hm
    where hm.household_id = income_sources.household_id
      and hm.user_id = auth.uid()
  )
);


