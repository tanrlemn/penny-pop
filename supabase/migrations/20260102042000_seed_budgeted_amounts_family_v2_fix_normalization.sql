-- Seed v2: fix name normalization (handle capital letters) + avoid duplicate matches.
--
-- v1 bug: regexp pattern `[ ^a-z0-9 ]` removed capital letters *before* lowercasing,
-- so "Rent" -> "ent" and nothing matched. This migration corrects that and re-applies
-- the same budget map safely (idempotent).

do $$
declare
  family_household_id uuid := '4b7c62d7-7584-4665-a1e7-991700d4d30c';
  matched_count integer := 0;
begin
  with
    pods_norm as (
      select
        p.id as pod_id,
        regexp_replace(lower(p.name), '[^a-z0-9]+', '', 'g') as full_key,
        regexp_replace(
          lower(split_part(p.name, ' - ', 1)),
          '[^a-z0-9]+',
          '',
          'g'
        ) as base_key
      from public.pods p
      where p.is_active = true
        and p.household_id = family_household_id
    ),
    budgets as (
      select * from (values
        ('art',                       2000::bigint,   'Discretionary'),
        ('birthdaymoney',             5000::bigint,   'Kiddos'),
        ('cargas',                   15000::bigint,   'Necessities'),
        ('carinsurance',             15000::bigint,   'Necessities'),
        ('carmaintenance',            5000::bigint,   'Necessities'),
        ('carpayment',               56000::bigint,   'Necessities'),
        ('clothing',                  5000::bigint,   'Discretionary'),
        ('creditcards',              15000::bigint,   'Pressing'),
        ('eatout',                       0::bigint,   'Discretionary'),
        ('education',                35000::bigint,   'Kiddos'),
        -- Electric (AES)
        ('electric',                 27500::bigint,   'Necessities'),
        ('electricaes',              27500::bigint,   'Necessities'),
        ('aes',                      27500::bigint,   'Necessities'),
        -- Gas/Water (Citizens)
        ('gaswater',                 27500::bigint,   'Necessities'),
        ('gaswatercitizens',         27500::bigint,   'Necessities'),
        ('citizens',                 27500::bigint,   'Necessities'),
        ('citizensenergy',           27500::bigint,   'Necessities'),
        -- Kids
        ('greenlightkids',           20000::bigint,   'Kiddos'),
        ('greenlight',               20000::bigint,   'Kiddos'),
        ('groceries',               120000::bigint,   'Necessities'),
        ('health',                   70000::bigint,   'Necessities'),
        ('housecleaning',            25000::bigint,   'Necessities'),
        ('juicebox',                 15000::bigint,   'Kiddos'),
        -- Move to ___
        ('moveto',                  200000::bigint,   'Pressing'),
        ('mowing',                       0::bigint,   'Discretionary'),
        ('phones',                  15000::bigint,   'Necessities'),
        ('rent',                   170000::bigint,   'Necessities'),
        ('robinhoodinvesting',        9000::bigint,   'Savings'),
        ('safetynet',               50000::bigint,   'Savings'),
        ('sequencebilling',          3000::bigint,   'Necessities'),
        ('sofisavings',                 0::bigint,   'Savings'),
        ('streamingservices',        3000::bigint,   'Discretionary'),
        ('toiletries',               5000::bigint,   'Necessities'),
        ('vivint',                  16900::bigint,   'Necessities'),
        ('wifi',                     9000::bigint,   'Necessities')
      ) as t(key, cents, category)
    ),
    matched as (
      -- Prefer full_key match over base_key. DISTINCT avoids duplicates that would
      -- otherwise error in INSERT ... ON CONFLICT when a pod matches multiple keys.
      select distinct on (pn.pod_id)
        pn.pod_id,
        b.cents,
        b.category
      from pods_norm pn
      join budgets b on b.key = pn.full_key or b.key = pn.base_key
      order by pn.pod_id, case when b.key = pn.full_key then 0 else 1 end
    )
  insert into public.pod_settings (
      pod_id,
      budgeted_amount_in_cents,
      category,
      updated_at
    )
    select
      m.pod_id,
      m.cents,
      m.category,
      now()
    from matched m
    on conflict (pod_id) do update
      set
        budgeted_amount_in_cents = excluded.budgeted_amount_in_cents,
        category = coalesce(public.pod_settings.category, excluded.category),
        updated_at = excluded.updated_at;

  get diagnostics matched_count = row_count;
  raise notice 'seed budget v2: updated % pods in household %', matched_count, family_household_id;
end $$;


