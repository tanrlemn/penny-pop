-- Fix ambiguous column reference in add_household_member_by_email
-- Cause: RETURNS TABLE output column names (household_id, user_id, role) are also
-- common column names. In PL/pgSQL, output columns are variables, so unqualified
-- identifiers can become ambiguous.
--
-- We drop and recreate the function with non-colliding output column names.

drop function if exists public.add_household_member_by_email(uuid, text);

create function public.add_household_member_by_email(
  p_household_id uuid,
  p_email text
)
returns table (
  out_household_id uuid,
  out_user_id uuid,
  out_role text
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


