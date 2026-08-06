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
| Distribute | placeholder | ⏳ engine ready, screen pending |

## Dashboard (`Views/Dashboard/DashboardView.swift`)

The first screen the user sees (spec FR-15, FR-13). A scroll of cards:

- **To Be Budgeted** — a hero tile showing unallocated income, color-coded: green
  when income waits for a job, red when envelopes over-claim, neutral at zero, each
  with a one-line explanation.
- **Accounts card** — the combined total plus a horizontal bar per account, with
  direct dollar labels (no axis clutter). Negative balances render red.
- **Envelopes card** — a bar per envelope on one shared scale, teal for healthy and
  **red for overspent**. Savings targets appear as a "% of target" label rather than
  a second bar, so one envelope's large target can't crush the shared x-scale.
- **Cash Flow · 30 Days** — a diverging daily bar chart around a zero baseline:
  green income up, red spending down, weekly axis marks, and a legend. **Touch and
  hold a day** to reveal a callout with that day's in/out totals (via
  `chartXSelection`). Allocations are excluded, since they are budget moves, not cash
  flow.

Every card header is tappable and navigates to its tab. With no data at all, the
screen shows a welcome state that routes the user to add their first account.

Charts are built with **Swift Charts** (`import Charts`).

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
