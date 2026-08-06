# Overview

## The problem Liquid solves

Liquid helps one person answer two questions about their money: **where is it**, and
**what is it for**. You record income and expenses by hand, organise your money into
budget categories ("envelopes"), and when a paycheck arrives you distribute it
across those envelopes according to rules you define.

Everything runs on the device. There is no account, no internet connection, and no
third-party financial service. This keeps the app private by construction.

## The core mental model

Money has two independent properties at the same time:

- **Where it is** — its **Account** (Checking, Savings, Cash). An account balance is
  income in minus expenses out.
- **What it is for** — its **Envelope** (Rent, Groceries, Fun). An envelope balance
  is allocations in minus expenses out.

These are two *views of the same transactions*. When you spend $10 of groceries from
Checking, both the Checking balance and the Groceries envelope drop by $10 — but the
total amount of money didn't change twice; it's the same $10 seen from two angles.

**Allocation** is the special move that assigns existing dollars a job without moving
them physically. Distributing a paycheck creates allocations: your envelope balances
go up, but your account balance is unchanged, because the money was already sitting
in the account.

**To Be Budgeted** is income that has arrived but hasn't yet been given a job —
income minus allocations. The goal of zero-based budgeting is to drive this to zero:
"every dollar has a job."

## What you can do in this version

**Dashboard** (the landing screen)
- See **To Be Budgeted** as a large, color-coded headline
- Bar charts of account balances and envelope balances (overspent envelopes show red)
- A **30-day cash-flow chart** (green income vs. red spending) with tap-to-inspect
  daily totals
- Tap any card to jump into its tab

**Accounts**
- Create, rename, and delete accounts
- See each balance and the combined total, computed live

**Envelopes**
- Create, rename, and delete budget categories
- Give each an **allocation rule** (Fixed, Percentage, Fill-to-target, or Remainder),
  a priority, and an optional **savings target** with progress
- **Tap** an envelope to see its full transaction **history**; **swipe left** to Edit
  or Delete

**Transactions**
- Record **income** or **expenses** (amount, date, account, envelope, note)
- **Edit** (tap) or **delete** (swipe) any entry
- **Filter** by date range and by envelope
- Validation blocks saving until required fields are present

All data persists across launches, works fully offline, and demo data only exists in
debug builds (a real device starts empty with your own data).

## What is not in this version

- **Distribute Paycheck screen** — the one remaining core feature. The distribution
  *engine* is already built and unit-tested; only its review-and-confirm screen is
  pending. The "Distribute" tab is currently a placeholder.
- **Out of scope for v1 by design:** automatic bank/card import, multi-device sync,
  cloud backup, multi-currency, forecasting, and shared household budgets.
