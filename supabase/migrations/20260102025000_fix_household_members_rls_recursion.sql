-- Fix RLS recursion on household_members.
--
-- The previous policy checked membership by querying household_members again:
--   exists(select 1 from household_members hm ...)
-- When other tables (like pods) also query household_members in their policies,
-- Postgres can detect infinite recursion (42P17).
--
-- For v1, we only need users to read *their own* membership rows. That is
-- sufficient for household-scoped access checks (pods, households, etc.)

alter table public.household_members enable row level security;

drop policy if exists "household_members_select_for_members" on public.household_members;
drop policy if exists "household_members_select_own" on public.household_members;

create policy "household_members_select_own"
on public.household_members
for select
to authenticated
using (user_id = auth.uid());


