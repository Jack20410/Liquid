# Architecture

Liquid uses a layered **MVVM + repository** design (spec §5.1). Concerns are split
so any one layer can change with minimal impact on the others — in particular, the
UI depends on the domain layer rather than on storage, so the transaction *source*
(manual entry today) could later become automated import without rewriting screens.

## The three layers

| Layer | Responsibility | Where |
|-------|----------------|-------|
| **View** (presentation) | SwiftUI views that display state and capture input. No business logic. | `Liquid/Views/` |
| **Domain** | Business rules: balance math, the paycheck-distribution algorithm, and the repository seam. | `Liquid/Domain/` |
| **Data** (persistence) | SwiftData `@Model` types + a repository that reads and writes them. The UI talks to the repository, never to raw storage. | `Liquid/Models/`, `Liquid/Domain/BudgetRepository.swift` |

## Folder structure

```
Liquid/
  LiquidApp.swift              App entry: ModelContainer with the full schema; DEBUG seed
  Models/                      SwiftData @Model types (the Data layer)
    Account.swift
    Envelope.swift
    Transaction.swift
    AllocationRule.swift
  Domain/                      Business logic (the Domain layer)
    DistributionEngine.swift   Pure paycheck-distribution algorithm (§7)
    BudgetMath.swift           Account/envelope balances, To Be Budgeted
    BudgetRepository.swift      Protocol + SwiftData-backed implementation
  Views/                       SwiftUI screens (the View layer)
    RootTabView.swift          TabView; owns tab selection so cards can navigate
    Dashboard/
      DashboardView.swift      Charts + summary; the landing screen
    Accounts/
      AccountsView.swift
      AccountEditView.swift
    Envelopes/
      EnvelopesView.swift
      EnvelopeEditView.swift   Name, target, and allocation-rule editor
      EnvelopeDetailView.swift Per-envelope balance + transaction history
    Transactions/
      TransactionsView.swift
      TransactionEditView.swift
      TransactionFilterView.swift
    Shared/
      CurrencyField.swift      Reusable Decimal amount entry
      Formatters.swift         Currency/date formatting + Decimal helpers
      EmptyStateView.swift     Friendly empty-state placeholder
      TransactionRow.swift     Shared row used by lists and envelope history
  Support/
    SampleData.swift           DEBUG-only first-launch seeding
LiquidTests/
  DistributionEngineTests.swift
  BudgetMathTests.swift
```

## Key design conventions

**Pure domain, testable in isolation.** `DistributionEngine` and `BudgetMath` are
plain Swift with no `ModelContext` dependency. The engine operates on value-type
*snapshots* of envelopes, so the whole distribution algorithm is unit-testable
without spinning up SwiftData. See [Distribution Engine](DistributionEngine.md).

**The repository seam.** `BudgetRepository` is a protocol; `SwiftDataBudgetRepository`
is the concrete implementation. Views construct a repository from their
`@Environment(\.modelContext)` and call it for all mutations (create/rename/delete,
add transaction, apply distribution, save). This is the boundary that satisfies
NFR-5.

**State flow.** Views read data with SwiftData `@Query` and own transient UI state
with `private @State`. Tab selection lives in `RootTabView` as an `AppTab` enum and
is passed to the Dashboard as a `@Binding`, so a dashboard card can switch tabs.

**Modern SwiftUI, iOS 26 floor.** Because the deployment target is iOS 26.5, the code
uses current APIs directly without `#available` gating: the `Tab` API, `@Observable`
patterns, `NavigationStack`, Swift Charts selection, and native Liquid Glass on
toolbars, tab bar, and sheets.

**Filesystem-synchronized project.** The Xcode project uses
`PBXFileSystemSynchronizedRootGroup`, so files added under `Liquid/` or
`LiquidTests/` are picked up automatically — there is no `project.pbxproj` editing
when adding a file.
