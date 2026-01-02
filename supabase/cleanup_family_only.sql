-- Family-only cleanup helper (run manually in Supabase SQL editor).
--
-- Household allowed:
--   4b7c62d7-7584-4665-a1e7-991700d4d30c
--
-- NOTE:
-- - Review the SELECTs first.
-- - If you run DELETEs, do it in a transaction so you can ROLLBACK if needed.

begin;

-- 1) Inspect non-family households and memberships
select *
from public.households
where id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;

select *
from public.household_members
where household_id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;

-- 2) Inspect pods outside the family household
select *
from public.pods
where household_id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;

-- 3) Optional destructive cleanup (uncomment only after review)
-- delete from public.pods
-- where household_id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;
--
-- delete from public.household_members
-- where household_id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;
--
-- delete from public.households
-- where id <> '4b7c62d7-7584-4665-a1e7-991700d4d30c'::uuid;

rollback;


