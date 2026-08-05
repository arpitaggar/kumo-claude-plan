# lib/features/expense_split

Migrated from the project root CLAUDE.md (2026-08-03 doctor cleanup) — loads only when working under lib/features/expense_split/.

### Expense Improvements (Stage 17)

**Migration:** `docs/supabase_migrations/stage17_expense_improvements.sql`  
Must be run in Supabase SQL editor before deploying the corresponding app build.

#### Database schema additions

Three new columns on `public.expenses` (all `add column if not exists`, backward-compatible defaults):

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `split_mode` | `text` | `'equal'` | `check in ('equal', 'percentage', 'ratio')` |
| `exchange_rate_to_base` | `numeric` | `1.0` | Multiplier: `expense_currency → trip base currency` |
| `is_settlement` | `bool` | `false` | True for cash settle-up payments; hidden from expense list |

#### Flutter layer

**Entities** (`lib/features/expense_split/domain/entities/expense.dart`):
- `enum SplitMode { equal, percentage, ratio }` — added at file level
- `Expense` gains: `splitMode`, `exchangeRateToBase`, `isSettlement` (all with safe defaults)
- `ExpenseSplit` gains: `rawValue` (optional double — stores the raw % or ratio value for display; not used in calculations)
- `Settlement` gains: `currencyCode` (always the trip base currency)

**Model** (`lib/features/expense_split/data/models/expense_model.dart`):
- `fromJson` uses `??` fallbacks to match the DB defaults; old rows without the new columns deserialise cleanly
- `rawValue` in splits is stored in the existing JSONB `splits` column — no schema change needed

**Use cases:**
- `CalculateSettlementsUseCase.call(expenses, {required String baseCurrency})` — multiplies each split's `shareAmount` by `expense.exchangeRateToBase` before accumulating net balances; skips settlement expenses so they cancel debt without double-counting
- `AddExpenseUseCase.call(...)` — accepts `splitMode`, `exchangeRateToBase`, `isSettlement` optional named params

**Providers** (`lib/features/expense_split/presentation/providers/expense_provider.dart`):
- `settlementsProvider` family param changed from `String itineraryId` to `(String itineraryId, String baseCurrency)` record — threads base currency into the calculator without a wrapper class

**Add Expense page** (`lib/features/expense_split/presentation/pages/add_expense_page.dart`):
- `_CurrencyPicker`: `DropdownButton<String>` over 25 common travel currencies
- `_SplitModeBar`: `SegmentedButton<SplitMode>` — Equal / Percent / Ratio
- `_SplitSection` + `_MemberSplitRow`: per-member `TextField` controllers for % or ratio input with live amount preview
- Exchange-rate field shown only when `expenseCurrency != itinerary.currencyCode`: `1 [currency] = [X] [baseCurrency]`
- Percentage mode validates that all member values sum to 100 ± 0.1% before allowing submit

**Itinerary detail page** (`lib/features/itinerary/presentation/pages/itinerary_detail_page.dart`):
- Expense list filters: `.where((e) => !e.isSettlement)` — settlement rows are hidden from the expense list and budget totals
- `_settleUp(BuildContext, WidgetRef, Settlement)` — shows a confirm dialog, records a cash payment as `is_settlement: true` expense with debtor as payer + creditor in splits; shows "Payment recorded" snackbar on success
- `_SettlementRow` — added "Mark paid" `TextButton` that triggers `_settleUp`

#### Key design decisions

- **No settlements table.** Cash payments are stored as `is_settlement = true` expense rows. The greedy debt-minimisation algorithm already handles this correctly — debtor-as-payer with creditor in splits cancels the net balance without any schema additions.
- **Multi-currency normalisation happens at the calculation layer only.** Raw `shareAmount` values stored in JSONB are always in the expense's own currency; the `exchangeRateToBase` multiplier is applied only inside `CalculateSettlementsUseCase` to produce base-currency net balances.
- **`rawValue` in splits.** Stores the user-entered % or ratio for the edit flow (currently write-only; an edit expense screen can use it to repopulate the split inputs). Not used in any financial calculation.

