//
//  DistributePaycheckView.swift
//  Liquid
//
//  The signature flow (spec UC-2, FR-10–FR-12): take money that has arrived but
//  isn't yet budgeted (To Be Budgeted) and sweep it into envelopes by their rules.
//  The user reviews and adjusts the proposed split, then confirms — which records
//  one allocation per funded envelope (account balances are unchanged, §7.4).
//
//  The distribution math is the pure, unit-tested `DistributionEngine`; this view
//  only handles input, review, and applying the result.
//

import SwiftUI
import SwiftData

struct DistributePaycheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var amount: Decimal?
    @State private var accountID: UUID?
    @State private var edited: [UUID: Decimal] = [:]
    @State private var didSeed = false

    private var repository: SwiftDataBudgetRepository { SwiftDataBudgetRepository(context: modelContext) }

    private var toBeBudgeted: Decimal { BudgetMath.toBeBudgeted(transactions: transactions) }
    private var distributable: Decimal { amount ?? 0 }
    private var assigned: Decimal { edited.values.reduce(0, +) }
    private var remaining: Decimal { distributable - assigned }
    private var overAssigned: Bool { remaining < 0 }

    /// Envelopes shown in the proposal, ordered by rule priority then name.
    private var orderedEnvelopes: [Envelope] {
        envelopes.sorted { lhs, rhs in
            let lp = lhs.rule?.priority ?? Int.max
            let rp = rhs.rule?.priority ?? Int.max
            return lp == rp ? lhs.name < rhs.name : lp < rp
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if toBeBudgeted <= 0 {
                    ContentUnavailableView {
                        Label("Nothing to distribute", systemImage: "tray")
                    } description: {
                        Text("Record income first — any money that isn't yet in an envelope shows up here to distribute.")
                    }
                } else if envelopes.isEmpty {
                    ContentUnavailableView {
                        Label("No envelopes", systemImage: "tray.full")
                    } description: {
                        Text("Create some envelopes with allocation rules, then come back to distribute.")
                    }
                } else {
                    form
                }
            }
            .navigationTitle("Distribute")
            .toolbar {
                if toBeBudgeted > 0 && !envelopes.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm", action: confirm)
                            .disabled(assigned <= 0 || overAssigned)
                    }
                }
            }
            .onAppear(perform: seedIfNeeded)
        }
    }

    private var form: some View {
        Form {
            Section {
                CurrencyField(title: "Amount", amount: $amount)
                    .onChange(of: amount) { autoFill() }
                Picker("Into account", selection: $accountID) {
                    ForEach(accounts) { account in
                        Text(account.name).tag(UUID?.some(account.id))
                    }
                }
            } header: {
                Text("To distribute")
            } footer: {
                Text("Defaults to your To Be Budgeted. Allocations give this money a job; they don't move it out of the account.")
            }

            Section("Envelopes") {
                ForEach(orderedEnvelopes) { envelope in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(envelope.name)
                            if let rule = envelope.rule {
                                Text(ruleLabel(rule))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        CurrencyField(title: "0", amount: binding(for: envelope.id))
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                Button("Reset to suggested", systemImage: "wand.and.stars", action: autoFill)
            } footer: {
                summaryFooter
            }
        }
    }

    private var summaryFooter: some View {
        HStack {
            Text("Assigned \(assigned.asCurrency) of \(distributable.asCurrency)")
            Spacer()
            Text(remaining == 0 ? "All assigned"
                 : overAssigned ? "Over by \((-remaining).asCurrency)"
                 : "\(remaining.asCurrency) left")
            .foregroundStyle(remaining == 0 ? .green : overAssigned ? .red : .secondary)
        }
        .font(.callout)
        .monospacedDigit()
    }

    // MARK: Logic

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        if amount == nil { amount = toBeBudgeted }
        if accountID == nil { accountID = accounts.first?.id }
        autoFill()
    }

    /// Fill each envelope's amount from the engine's proposal for the current amount.
    private func autoFill() {
        let snapshots = envelopes.compactMap { env -> EnvelopeSnapshot? in
            guard let rule = env.rule else { return nil }
            return EnvelopeSnapshot(id: env.id, name: env.name,
                                    currentBalance: BudgetMath.envelopeBalance(env),
                                    strategy: rule.strategy, priority: rule.priority)
        }
        let result = DistributionEngine.distribute(paycheck: distributable, envelopes: snapshots)
        var next: [UUID: Decimal] = [:]
        for line in result.lines { next[line.id] = line.amount }
        edited = next
    }

    private func binding(for id: UUID) -> Binding<Decimal?> {
        Binding(
            get: { edited[id] },
            set: { edited[id] = max(0, $0 ?? 0) }
        )
    }

    private func confirm() {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return }
        let byID = Dictionary(uniqueKeysWithValues: envelopes.map { ($0.id, $0) })
        let lines = edited.compactMap { id, amt -> DistributionLine? in
            guard amt > 0 else { return nil }
            return DistributionLine(id: id, name: byID[id]?.name ?? "", amount: amt)
        }
        let result = DistributionResult(lines: lines,
                                        remaining: max(0, remaining),
                                        overcommitted: false)
        repository.applyDistribution(result, from: account, date: .now, envelopesByID: byID)
        // Reset so the screen reflects the new (lower) To Be Budgeted.
        didSeed = false
        amount = nil
        edited = [:]
    }

    private func ruleLabel(_ rule: AllocationRule) -> String {
        switch rule.strategy {
        case let .fixed(v): "Fixed \(v.asCurrency)"
        case let .percentage(p): "\((p * 100).formatted())% of paycheck"
        case let .fillToTarget(t): "Fill → \(t.asCurrency)"
        case .remainder: "Remainder"
        }
    }
}
