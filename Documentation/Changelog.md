# Changelog

This records what was built in the current version, in the order it happened. It
replaces the default Xcode template (`Item` / `ContentView`) with the full v1 core.

## v1 core — data model, engine, screens, dashboard

Committed as `192f387` ("Build v1 core: data model, distribution engine, screens,
and dashboard"). 26 files changed.

**Data layer**
- Added SwiftData models `Account`, `Envelope`, `Transaction`, `AllocationRule` with
  the spec §9 delete rules (account → cascade; envelope → nullify transactions,
  cascade rule). Amounts stored positive per spec §6.3.
- `AllocationStrategy` (enum with associated values) persisted as a `kind` + `value`
  pair behind a computed property, since SwiftData can't store associated-value enums.

**Domain layer**
- `DistributionEngine` — the pure §7 paycheck-distribution algorithm over value-type
  snapshots.
- `BudgetMath` — account/envelope balances and To Be Budgeted, reconciling the spec
  §6.3 sign convention with the §7.4 rule that allocations don't move account
  balances.
- `BudgetRepository` — protocol + `SwiftDataBudgetRepository`, the seam between UI and
  storage (NFR-5), including `applyDistribution`.

**Screens**
- `RootTabView` with five tabs (Liquid Glass tab bar).
- **Accounts**: list with balances + total, add/rename/delete.
- **Envelopes**: list with rule chips, balances, and target progress; editor for
  name, target, and allocation rule.
- **Transactions**: chronological list, add/edit/delete form with validation (UC-1),
  and date/envelope filtering.
- Shared components: `CurrencyField`, `Formatters`, `EmptyStateView`.
- **Dashboard**: To Be Budgeted hero, account/envelope bar charts, and a 30-day
  cash-flow chart with tap-to-inspect — the landing screen. Cards link to their tabs.

**Support & tests**
- `SampleData` — DEBUG-only first-launch seed (compiled out of release builds).
- 12 unit tests (`DistributionEngineTests`, `BudgetMathTests`), including the spec
  §7.2 worked example and the "allocations don't change account balance" invariant.

## Envelope history + swipe-to-edit (uncommitted)

Refined the Envelopes interaction based on feedback that tapping a category should
show its history rather than open the editor:

- Added `EnvelopeDetailView` — a per-envelope screen showing the balance, target
  progress, rule description, and the full transaction **history** (newest first).
- `EnvelopesView`: **tap** a row now navigates to that detail screen; **swipe left**
  reveals **Edit** and **Delete**.
- Extracted the transaction row into a shared `TransactionRow` (previously private to
  `TransactionsView`), reused by both the Transactions list and envelope history, with
  an option to hide the envelope name when the list is already scoped to one envelope.
- Enriched `SampleData` with a full month of dated transactions so the dashboard
  charts and envelope histories have realistic content.

All 12 tests still pass; the app builds and was verified in the simulator.

## Spending Calendar (uncommitted)

Added a month calendar of money activity:

- New `BudgetMath.dailySummaries(_:calendar:)` + `DailySummary` type — per-day income
  and spending keyed by start-of-day, allocations excluded. `CashFlowCard` was
  refactored to build on this shared helper (one source of truth).
- New `SpendingCalendarView` — a calendar-correct month grid (dates derived entirely
  from `Calendar.current`) where each day shows its color-coded net; tapping a day
  reveals that day's In/Out/Net totals and transaction list inline. Reachable from a
  round calendar icon added at the top-left of the Dashboard, presented as a sheet.
- New `BudgetMathDailyTests` (3 tests): day grouping/sums, allocation exclusion, and
  the empty case. Test count is now **15**, all passing.

## Multi-bank accounts, account types & credit cards (uncommitted)

Expanded accounts from a flat list into banks, types, and credit cards:

- New `Institution` entity groups accounts by bank. `Account` gains `type`
  (`AccountType`: checking / savings / creditCard / cash / other), `creditLimit`, an
  `institution`, and an `incomingTransfers` inverse.
- New `.transfer` `TransactionType` + `Transaction.toAccount` for moving money between
  accounts (e.g. paying a card). Every exhaustive `TransactionType` switch updated.
- `BudgetMath`: `accountBalance` handles transfers both directions; new
  `amountOwed` / `availableCredit` / `creditUtilization` and
  `totalAssets` / `totalLiabilities` (net worth = assets − liabilities). Transfers
  excluded from cash flow and To Be Budgeted.
- Repository: `createAccount`/`updateAccount` (type/limit/institution),
  `createInstitution`, `addTransfer`.
- UI: Accounts screen regrouped by bank with a **Net Worth / Assets / Liabilities**
  header and credit-card rows (owed, available, utilization); richer `AccountEditView`
  (type, bank, limit); new `AccountDetailView` (statement + **Pay Balance**);
  `TransactionEditView` gains a **Transfer** type with From/To pickers and prefill;
  `TransactionRow` renders transfers as "from → to". Dashboard "Total" → "Net Worth".
- New `AccountTests` (5): credit-card owed/available/utilization, transfer moves
  balances without touching net worth / envelopes / TBB / cash flow, and
  assets − liabilities == net worth. Test count is now **20**, all passing.

## Deferred to the next version

- **Distribute Paycheck screen** — the last core screen. The engine and repository
  method it needs already exist and are tested; only the review-and-confirm UI
  remains (record income → see the proposed split → adjust → apply).

Out of scope for v1 by design: bank/card import, multi-device sync, cloud backup,
multi-currency, forecasting, shared budgets.
