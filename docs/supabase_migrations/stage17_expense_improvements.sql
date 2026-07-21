-- Stage 17: Expense splitting improvements
--
-- Adds three columns to the existing `expenses` table:
--   split_mode            — 'equal' | 'percentage' | 'ratio'
--   exchange_rate_to_base — how many trip-base-currency units 1 expense-currency unit equals
--   is_settlement         — true for cash settle-up payments (excluded from budget tracking)
--
-- Safe to re-run: all statements use IF NOT EXISTS / ADD COLUMN IF NOT EXISTS.
-- Run in Supabase SQL editor before deploying the corresponding app update.

alter table public.expenses
  add column if not exists split_mode text not null default 'equal'
    check (split_mode in ('equal', 'percentage', 'ratio')),
  add column if not exists exchange_rate_to_base numeric not null default 1.0,
  add column if not exists is_settlement bool not null default false;

-- Note: the `splits` column is already JSONB. The new fields added per split entry
-- (rawValue — optional double for the percentage or ratio value) are stored inside
-- that JSONB and require no schema change. Old rows simply lack rawValue and are
-- treated as equal splits by the app.
