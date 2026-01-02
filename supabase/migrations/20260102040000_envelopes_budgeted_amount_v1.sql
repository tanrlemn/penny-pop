-- Envelopes budget v1 — add budgeted amounts and support Income section.
--
-- - Add `budgeted_amount_in_cents` to `pod_settings`
-- - Expand `pod_settings.category` check constraint to include 'Income'

alter table public.pod_settings
  add column if not exists budgeted_amount_in_cents bigint;

-- The original migration used an inline CHECK on `category`, which creates an
-- auto-named constraint. Drop any existing CHECK constraint that references
-- `category` before adding our expanded version.
do $$
declare
  r record;
begin
  for r in
    select conname
    from pg_constraint
    where contype = 'c'
      and conrelid = 'public.pod_settings'::regclass
      and pg_get_constraintdef(oid) ilike '%category%'
  loop
    execute format('alter table public.pod_settings drop constraint if exists %I', r.conname);
  end loop;
end $$;

alter table public.pod_settings
  add constraint pod_settings_category_check check (
    category is null
    or category in (
      'Income',
      'Savings',
      'Kiddos',
      'Necessities',
      'Pressing',
      'Discretionary'
    )
  );


