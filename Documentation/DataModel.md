# Data Model

The model rests on one principle (spec §6): **money has two independent properties at
once** — where it is (its Account) and what it is for (its Envelope). Account balances
and envelope balances are two separate views of the same underlying transactions.

All types are SwiftData `@Model` classes in `Liquid/Models/`.

## Entities

### Institution (`Institution.swift`)
A bank/brand (e.g. Chase) that groups accounts on the Accounts screen.

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | `UUID` | |
| `name` | `String` | e.g. "Chase" |
| `accounts` | `[Account]` | `@Relationship(deleteRule: .nullify)` — deleting a bank un-assigns, never deletes, its accounts |

### Account (`Account.swift`)
A place money lives (asset) or is owed (credit-card liability).

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | `UUID` | |
| `name` | `String` | e.g. "Checking" |
| `type` | `AccountType` | `.checking`, `.savings`, `.creditCard`, `.cash`, `.other` (icon, `isLiability`, `usesCreditLimit`) |
| `creditLimit` | `Decimal?` | Credit cards only |
| `institution` | `Institution?` | Owning bank (nil = "Other") |
| `transactions` | `[Transaction]` | `@Relationship(deleteRule: .cascade)` — source side (income/expense/allocation + transfer "from") |
| `incomingTransfers` | `[Transaction]` | `@Relationship(deleteRule: .nullify)` — transfer "to" side |

A **debit/checking card is not a separate type** — it is a `.checking` account.
Balance is **computed**, not stored — see [balance rules](#balances-and-the-sign-convention).

### Envelope (`Envelope.swift`)
A budget category — a job assigned to money.

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | `UUID` | |
| `name` | `String` | e.g. "Groceries" |
| `target` | `Decimal?` | Optional savings target (FR-14) |
| `rule` | `AllocationRule?` | `@Relationship(deleteRule: .cascade)` |
| `transactions` | `[Transaction]` | `@Relationship(deleteRule: .nullify)` |

### Transaction (`Transaction.swift`)
A single movement of money.

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | `UUID` | |
| `date` | `Date` | |
| `amount` | `Decimal` | **Always stored positive** (see sign convention) |
| `type` | `TransactionType` | `.income`, `.expense`, `.allocation`, or `.transfer` |
| `note` | `String` | Optional free text |
| `account` | `Account?` | Source account; the "from" side of a transfer |
| `toAccount` | `Account?` | Transfer destination (the "to" side); nil otherwise |
| `envelope` | `Envelope?` | Set for expenses and allocations |

`TransactionType` is a `String`-backed enum, persisted directly. A **`.transfer`**
moves money between two accounts (e.g. paying a credit card): it leaves `account` and
enters `toAccount`, touches no envelope, and is excluded from cash flow and To Be
Budgeted (like `.allocation`).

### AllocationRule (`AllocationRule.swift`)
How an envelope is filled on payday.

| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | `UUID` | |
| `strategyKind` | `AllocationStrategy.Kind` | Persisted enum kind |
| `strategyValue` | `Decimal` | Persisted associated value |
| `priority` | `Int` | Lower runs first |

**Why two stored fields for the strategy?** The logical strategy is
`AllocationStrategy`, an enum with associated values
(`fixed(Decimal)`, `percentage(Decimal)`, `fillToTarget(Decimal)`, `remainder`).
SwiftData cannot persist an enum with associated values directly, so it is stored as
a `kind` + `value` pair and exposed through a computed `strategy` property that reads
and writes both.

## Relationships and delete rules

Following spec §9:

- An **Account** has many **Transactions**; deleting an account **cascades** —
  its transaction records are removed with it.
- An **Envelope** has many **Transactions**; deleting an envelope **nullifies** the
  `envelope` reference on those transactions rather than deleting them. The money
  records survive; they simply lose their category.
- An **Envelope** has one **AllocationRule**, which is **cascaded** on delete.

## Balances and the sign convention

Amounts are always stored as positive numbers. The sign used in a balance is derived
from the transaction's `type` at calculation time (spec §6.3). This keeps stored data
clean and makes each balance a simple sum.

There is one subtlety the spec required reconciling: allocations must **not** change
account balances (spec §7.4), yet the sign convention lists allocation as positive.
The resolution, implemented in `BudgetMath` (`Liquid/Domain/BudgetMath.swift`):

| Balance | Formula |
|---------|---------|
| **Account balance** | Σ income (+), expense (−), transfer-out (−); + incoming transfers. **Allocations excluded.** |
| **Envelope balance** | Σ allocation (+) and expense (−) for that envelope. |
| **To Be Budgeted** | Σ(all income) − Σ(all allocations). |

So an allocation is positive *for the envelope it fills*, but is simply not counted
toward the account balance — which is exactly what "assigning existing dollars a job
without moving them" means. This invariant is locked down by the
`allocationsDoNotChangeAccountBalance` unit test.

### Credit cards, transfers & net worth

The same convention already models credit cards: **charging an expense to a card
drives its balance negative — that negative is the amount owed.** So (in `BudgetMath`):

- `amountOwed` = `max(0, -balance)`; `availableCredit` = `creditLimit − owed`;
  `creditUtilization` = `owed / limit` (0…1). Credit-card only.
- **Net worth** = Σ all account balances (assets positive + card debt negative). The
  Accounts screen also splits it magnitude-based: `totalAssets` = Σ `max(0, balance)`,
  `totalLiabilities` = Σ `max(0, -balance)`, so **assets − liabilities == net worth**
  always holds.
- A **`.transfer`** (e.g. paying a card) subtracts from the source account and adds to
  the destination — net worth is unchanged (cash becomes reduced liability). Transfers
  never touch envelopes, To Be Budgeted, or cash flow. Locked down by `AccountTests`.
