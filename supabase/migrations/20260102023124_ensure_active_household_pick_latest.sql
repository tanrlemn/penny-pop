-- Prefer the most recently-created household membership when a user has multiple.
-- This prevents the "partner" case where they auto-created a household on first login,
-- then later get added to the admin's household but keep seeing the older one.

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
  order by hm.created_at desc
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


