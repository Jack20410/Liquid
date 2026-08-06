# Testing

Tests use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) and
live in `LiquidTests/`. There are **12 unit tests**, all passing. They focus on the
domain layer — the distribution engine and balance math — which is where the app's
correctness actually lives.

## `DistributionEngineTests.swift`

Covers the paycheck-distribution algorithm (spec §7):

| Test | What it proves |
|------|----------------|
| `workedExample_fullyAssignsPaycheck` | The spec §7.2 example: $2,000 → 800/400/100/200/500, remainder 0 |
| `percentageUsesGrossPaycheck_notRunningRemainder` | 10% is taken from the gross paycheck, not the leftover |
| `rulesAreEvaluatedInPriorityOrder` | Lower priority number runs first, regardless of array order |
| `overcommitted_clampsToRemaining` | When rules over-claim, later envelopes are clamped and the result is flagged |
| `leftoverGoesToRemainderEnvelope` | The remainder envelope absorbs what's left |
| `noRemainderEnvelope_surfacesUnassignedMoney` | With no remainder envelope, leftover surfaces as `remaining` (To Be Budgeted) |
| `fillToTarget_neverGoesNegative_whenAlreadyOverTarget` | An already-full fill-to-target envelope claims nothing |

## `BudgetMathTests.swift`

Covers balances and the sign convention (spec §6.3, §7.4). These use a fresh
**in-memory** `ModelContainer` so they never touch the real store:

| Test | What it proves |
|------|----------------|
| `accountBalance_sumsIncomeMinusExpenses` | Account balance = income − expenses |
| `allocationsDoNotChangeAccountBalance` | Allocations move the envelope but **not** the account (the key invariant) |
| `envelopeBalance_allocationsInMinusExpensesOut` | Envelope balance = allocations − expenses |
| `toBeBudgeted_isIncomeMinusAllocations` | To Be Budgeted = income − allocations |
| `targetProgress_clampsToUnitInterval` | Target progress clamps to 0…1 even when the balance exceeds the target |

## Running the tests

From the project root (see [Build & Run](BuildAndRun.md) for why `DEVELOPER_DIR` is
needed on this machine):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Liquid.xcodeproj -scheme Liquid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:LiquidTests
```

A successful run ends with `** TEST SUCCEEDED **`.

## Notes and gaps

- The View layer is verified manually in the simulator rather than by UI tests. The
  template `LiquidUITests` target still exists but only contains the default launch
  test.
- The pure-domain design means the most failure-prone logic (distribution, balances)
  is fully covered without needing a running app.
