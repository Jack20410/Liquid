# Distribution Engine

Distributing a paycheck is the signature feature of Liquid (spec §7). Income arrives
as unassigned money and is swept into envelopes according to their rules. Correct
ordering guarantees every dollar gets a job and none is lost.

The engine lives in `Liquid/Domain/DistributionEngine.swift`. It is a **pure
function** over value-type snapshots — no SwiftData, no side effects — which is why
it can be unit-tested directly and reused by a future Distribute Paycheck screen
without coupling to storage.

## Inputs and outputs

```swift
DistributionEngine.distribute(paycheck: Decimal,
                              envelopes: [EnvelopeSnapshot]) -> DistributionResult
```

- **`EnvelopeSnapshot`** — a read-only snapshot the engine needs: `id`, `name`,
  `currentBalance` (the balance *before* this run, used by fill-to-target),
  `strategy`, and `priority`.
- **`DistributionResult`** — `lines` (one `DistributionLine` per funded envelope),
  `remaining` (income left unassigned; > 0 means the plan didn't consume the whole
  paycheck), and `overcommitted` (the rules claimed more than was available, so later
  envelopes were clamped).

## Order of operations (spec §7.1)

1. Resolve concrete claims — **fixed** amounts and **fill-to-target** top-ups — in
   priority order (lower priority number first).
2. Resolve **percentage** rules, computed against the *original* (gross) paycheck for
   predictability — not against the running remainder.
3. Assign whatever remains to the single **remainder** envelope.

Every claim is clamped with `min(give, remaining)` so a rule never assigns more than
is still available. If a claim is clamped, `overcommitted` is set.

## The algorithm

```
remaining = paycheck
for env in envelopes sorted by priority:
    switch env.strategy:
        fixed(v):        desired = v
        percentage(p):   desired = paycheck * p     // gross, not remainder
        fillToTarget(t): desired = max(0, t - env.currentBalance)
        remainder:       remember env; continue      // resolved last
    give = min(desired, remaining)                    // never overspend
    remaining -= give
    record (env, give) if give > 0

if a remainder envelope exists and remaining > 0:
    record (remainderEnvelope, remaining)
    remaining = 0
```

## Worked example (spec §7.2)

Given a **$2,000** paycheck and these envelope rules (Utilities already holds $50):

| Envelope | Rule | Amount assigned |
|----------|------|-----------------|
| Rent | Fixed $800 | $800 |
| Groceries | Fixed $400 | $400 |
| Utilities | Fill to $150 | $100 |
| Fun | 10% of paycheck | $200 |
| Savings | Remainder | $500 |
| **Total** | | **$2,000** |

The paycheck is fully assigned and `remaining` reaches zero — the zero-based outcome
the app is built around. This exact scenario is asserted by the
`workedExample_fullyAssignsPaycheck` unit test.

## Applying a distribution

Confirming a distribution (via `BudgetRepository.applyDistribution`) creates one
`.allocation` transaction per funded envelope, all against the account the paycheck
landed in. **The account balance does not change** — the money was already there;
only envelope balances move. See the sign convention in [Data Model](DataModel.md).

> The repository method is already implemented. What remains is the **Distribute
> Paycheck screen** that lets the user record income, review the proposed split,
> adjust amounts, and confirm.
