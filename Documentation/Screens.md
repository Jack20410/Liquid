# Screens

Navigation is a five-tab `TabView` in `RootTabView.swift`, styled with the native
iOS 26 Liquid Glass tab bar. Tab selection is held in an `AppTab` enum so Dashboard
cards can jump the user to another tab.

| Tab | Screen | Status |
|-----|--------|--------|
| Dashboard | `DashboardView` | ✅ |
| Accounts | `AccountsView` | ✅ |
| Envelopes | `EnvelopesView` | ✅ |
| Transactions | `TransactionsView` | ✅ |
| Distribute | `DistributePaycheckView` | ✅ |

## Dashboard (`Views/Dashboard/DashboardView.swift`)

The first screen the user sees (spec FR-15, FR-13). A scroll of cards, each matching a
chart form to its data's job. The **card order is user-arrangeable** (see Settings),
so this lists the cards, not a fixed sequence:

- **To Be Budgeted** — a hero tile showing unallocated income, color-coded.
- **Accounts card** — net worth, then accounts **grouped by bank** with a type icon
  each. Chart choice: **Bars** (a magnitude bar per account) or **Assets/Liabilities**
  (one stacked green/red bar). Every row taps through to `AccountDetailView`.
- **Envelopes card** — the top few envelopes as **bullet bars** (fill = balance, tick =
  target, label = value + % of target; overspent in red) or a **donut** of budgeted
  balances, user's choice. A **See all** link opens the Envelopes tab; rows tap through
  to `EnvelopeDetailView`.
- **Cash Flow · 30 Days** (`CashFlowCard`) — **diverging bars** (green in / red out) or
  a **daily-net line**, user's choice; tap a day for its in/out totals.
- **Spending · 30 Days** (`SpendingByCategoryCard`) — spending by envelope as a ranked
  **bar list** or a **donut**, user's choice; each row navigates to that envelope.
- **Net Worth trend** (`NetWorthTrendCard`) — a hero value + delta, a W/M/3M/Y range
  selector, and a scrubable Swift Charts **area** trend (`chartXSelection`). Built on
  `BudgetMath.netWorthSeries` (income + / expense −, allocations & transfers net-zero;
  the first point is the opening balance). Defaults to the bottom — this is a
  money-tracking app, so budget cards lead and the trend is context.

Most card headers are tappable and navigate to their tab. With no data, a welcome
state routes the user to add their first account. Charts use **Swift Charts**.

### Customizing the dashboard
Cards, their order, and their chart forms are user preferences stored via `@AppStorage`
(`DashboardChartStyles.swift`). Four cards offer a chart-form choice (Accounts, Cash
flow, Spending, Envelopes), each surfaced two ways that stay in sync: an on-card `···`
menu (`ChartStyleMenu`) and the **Settings** screen. The gear (top-right) opens
`SettingsView`; its **Customize dashboard** screen (`DashboardCustomizeView`) lets the
user **drag to reorder** cards and pick each chart form. Card order persists as a
comma-joined `DashboardCardID` list; unknown/added cards are reconciled on load.

A round **calendar icon** at the top-left (a `topBarLeading` toolbar button) opens the
Spending Calendar as a sheet.

## Spending Calendar (`Views/Calendar/SpendingCalendarView.swift`)

A month calendar of money activity, opened from the Dashboard's calendar icon.

- **Month grid** — each day cell shows the day number plus that day's **net**
  (income − spending), color-coded green (≥ 0) or red (< 0). Today gets a ring; the
  selected day gets a filled highlight. Month navigation via ‹ / › chevrons, with a
  **Today** shortcut when off the current month.
- **Inline day detail** — tapping a day reveals, below the grid in the same sheet,
  that day's **In** / **Out** / **Net** totals and its transactions (via
  `TransactionRow`, showing category and account).
- **Allocations are excluded** (real income/spending only), consistent with the Cash
  Flow card.
- **Calendar correctness** — every date derives from a single `Calendar.current`
  instance (day count via `range(of:.day…)`, locale-aware first weekday, DST-safe day
  stepping), and per-day money is bucketed by the same `startOfDay` used to render the
  cell, so the day shown always matches the transactions counted. New/edited
  transactions appear automatically via `@Query`. The aggregation is the shared
  `BudgetMath.dailySummaries(_:calendar:)` helper, also used by the Cash Flow card.

## Accounts (`Views/Accounts/`)

`AccountsView` (FR-1, FR-2) organizes accounts by **bank** (`Institution`) into
sections, under a **Net Worth** header with **Assets** and **Liabilities** subtotals.
Each row shows a type icon; asset rows show their balance, **credit-card** rows show
**owed** (red), **available of limit**, and a utilization bar. A debit/checking card
is not a separate type — it is just a checking account and renders like any asset.

- **Tap** a row → `AccountDetailView`: the account's balance (or, for a card, owed /
  available / utilization), a **Pay Balance** action (cards), and full history. Pay
  Balance opens a **prefilled transfer** (`TransactionEditView`) from an asset account
  to the card for the owed amount.
- **Swipe** a row → Edit / Delete.
- `AccountEditView` sets name, **type**, **bank** (pick an existing one or type a new
  one, created on save), and — for credit cards — a **credit limit**.

Transfers between accounts are recorded via the **Transfer** type in
`TransactionEditView` (From/To pickers, no envelope); they don't affect net worth,
envelopes, To Be Budgeted, or cash flow.

## Envelopes (`Views/Envelopes/`)

`EnvelopesView` lists categories with their rule chip, balance, and target progress
(FR-7–FR-9, FR-14).

- **Tap** a row → `EnvelopeDetailView`: the envelope's balance, target progress, rule
  description, and its full **transaction history** (allocations in, expenses out),
  newest first.
- **Swipe left** on a row → **Edit** and **Delete** actions.

`EnvelopeEditView` is the create/edit sheet: name, optional savings target, and the
allocation rule (strategy picker, value field, priority stepper). It warns when a
second **remainder** envelope would be created, since at most one is allowed.
Percentage is entered as a whole number (10 = 10%) and stored as a fraction (0.10) to
match the engine.

## Transactions (`Views/Transactions/`)

`TransactionsView` is the chronological list (FR-3–FR-6). Add via **+**; tap a row to
edit; swipe to delete.

- `TransactionEditView` — the add/edit form (UC-1): an Expense/Income segmented
  control, amount (via `CurrencyField` and a decimal keypad), date, account, envelope
  (required for expenses), and an optional note. **Save is disabled until required
  fields are valid.** Allocations are produced by paycheck distribution, not entered
  by hand, so the form offers only Income and Expense.
- `TransactionFilterView` — filter by **date range** and by **envelope**; the toolbar
  icon fills in when a filter is active, and a "Clear filters" affordance appears.
- Transfers also use `TransactionEditView` (a third **Transfer** type with From/To
  pickers); see the Accounts screen.

## Distribute Paycheck (`Views/Distribute/DistributePaycheckView.swift`)

The signature flow (spec UC-2, FR-10–FR-12): sweep **To Be Budgeted** into envelopes.

- **To distribute** defaults to the current To Be Budgeted; an account picker sets
  which account the allocations are recorded against.
- The pure `DistributionEngine` proposes a split from each envelope's rule (fixed,
  percentage of the amount, fill-to-target, remainder); every envelope's amount is
  **editable**, with a live "Assigned / remaining" summary and a **Reset to suggested**
  button.
- **Confirm** calls `BudgetRepository.applyDistribution`, writing one `.allocation` per
  funded envelope. Envelope balances rise and To Be Budgeted falls; **account balances
  and net worth are unchanged** (§7.4). Empty states cover "nothing to distribute" and
  "no envelopes".
- Reached from the **Distribute** tab and the **Distribute** button on the To Be
  Budgeted dashboard card.

## Shared components (`Views/Shared/`)

- **`TransactionRow`** — the row used by both the Transactions list and envelope
  history. Sign and color derive from the transaction type (income green, expense
  primary, allocation blue); it can hide the envelope name when a list is already
  scoped to one envelope.
- **`CurrencyField`** — Decimal amount entry with the primary currency symbol and a
  decimal keypad.
- **`Formatters`** — currency/date formatting plus `Decimal.asCurrency` /
  `Decimal.asDouble` helpers (the latter bridges to Swift Charts).
- **`EmptyStateView`** — a `ContentUnavailableView` wrapper for friendly empty states.
