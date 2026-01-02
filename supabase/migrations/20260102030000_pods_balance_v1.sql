-- Chunk 4 follow-up — store Sequence balances for nicer “accounts-style” list UI.

alter table public.pods
  add column if not exists balance_amount_in_cents bigint,
  add column if not exists balance_error text,
  add column if not exists balance_updated_at timestamptz;


