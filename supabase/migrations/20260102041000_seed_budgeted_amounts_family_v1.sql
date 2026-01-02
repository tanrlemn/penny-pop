-- Seed v1: populate budgeted amounts for existing envelopes (pods) by name.
--
-- This migration:
-- - Upserts `pod_settings.budgeted_amount_in_cents` for matched pods
-- - Optionally sets `pod_settings.category` (our “section”) only if it is NULL
-- - Does NOT create pods; it only updates pods that already exist in `public.pods`
--
-- Scope: family household only (matches the app’s Edge sync gate).
-- If you ever want this to apply to all households, remove the household_id filter.

do $$
declare
  family_household_id uuid := '4b7c62d7-7584-4665-a1e7-991700d4d30c';
begin
  with
  -- Normalize names (strip punctuation/spaces). We match BOTH:
  -- - full key: "Electric - AES" -> "electricaes"
  -- - base key: "Electric - AES" -> "electric" (split before ' - ')
  pods_norm as (
    select
      p.id as pod_id,
      lower(
        regexp_replace(
          p.name,
          '[^a-z0-9]+',
          '',
          'g'
        )
      ) as full_key,
      lower(
        regexp_replace(
          split_part(p.name, ' - ', 1),
          '[^a-z0-9]+',
          '',
          'g'
        )
      ) as base_key
    from public.pods p
    where p.is_active = true
      and p.household_id = family_household_id
  ),
  budgets as (
    -- key, budgeted_amount_in_cents, default_section(category)
    -- Add synonyms as extra rows with the same cents/category.
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
      -- Electric - AES
      ('electric',                27500::bigint,   'Necessities'),
      ('electricaes',              27500::bigint,   'Necessities'),
      ('aes',                      27500::bigint,   'Necessities'),
      -- Gas & Water - Citizens
      ('gaswater',                27500::bigint,   'Necessities'),
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
    select
      pn.pod_id,
      b.cents,
      b.category
    from pods_norm pn
    join budgets b on b.key = pn.full_key or b.key = pn.base_key
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
      -- keep any existing manual section; only set a default if currently null
      category = coalesce(public.pod_settings.category, excluded.category),
      updated_at = excluded.updated_at;
end $$;


