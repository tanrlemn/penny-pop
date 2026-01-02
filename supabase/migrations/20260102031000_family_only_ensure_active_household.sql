-- Family-only lock: ensure_active_household must only ever return the one
-- family household, and must never auto-create households/memberships.
--
-- This prevents random sign-ins from becoming "admin" and syncing global
-- Sequence pods into a new household.

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
  v_family_household_id uuid := '4b7c62d7-7584-4665-a1e7-991700d4d30c';
  v_household_name text;
  v_role text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select h.name, hm.role
    into v_household_name, v_role
  from public.households h
  join public.household_members hm on hm.household_id = h.id
  where h.id = v_family_household_id
    and hm.user_id = v_user_id
  limit 1;

  if v_role is null then
    raise exception 'Not authorized (not a member of the family household)';
  end if;

  household_id := v_family_household_id;
  household_name := v_household_name;
  role := v_role;
  return next;
end;
$$;


