//
//  DistributeView.swift
//  Liquid
//
//  The Distribute tab's landing screen: a report of where paychecks go. It leads
//  with To Be Budgeted and a call to action, then — once there's history — shows a
//  Sankey-style flow of where distributed money has gone and a log of past
//  distributions (each drills into its own breakdown). The paycheck input itself is
//  the focused `DistributePaycheckView`, presented as a sheet.
//

import SwiftUI
import SwiftData

struct DistributeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]

    @State private var showingForm = false

    private var toBeBudgeted: Decimal { BudgetMath.toBeBudgeted(transactions: transactions) }
    private var history: [BudgetMath.DistributionEvent] {
        BudgetMath.distributionHistory(transactions: transactions)
    }
    private var totals: [BudgetMath.DistributionShare] {
        BudgetMath.distributionTotalsByEnvelope(transactions: transactions)
    }
    private var totalDistributed: Decimal { totals.reduce(0) { $0 + $1.amount } }
    private var flowSlices: [DistributionFlowView.Slice] { aggregateSlices(from: totals, maxSlices: 8) }
    private var canDistribute: Bool { toBeBudgeted > 0 && !envelopes.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    if history.isEmpty {
                        emptyHistory
                    } else {
                        flowCard
                        historyCard
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Distribute")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingForm = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!canDistribute)
                    .accessibilityLabel("Distribute a paycheck")
                }
            }
            .sheet(isPresented: $showingForm) {
                DistributePaycheckView()
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To Be Budgeted")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(toBeBudgeted.asCurrency)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(toBeBudgeted > 0 ? Color.primary : .secondary)
                .contentTransition(.numericText())
            Text(toBeBudgeted > 0
                 ? "Income that hasn't been given a job yet."
                 : "Every dollar has a job.")
                .font(.footnote).foregroundStyle(.secondary)

            Button { showingForm = true } label: {
                Label("Distribute a paycheck", systemImage: "arrow.branch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canDistribute)

            if toBeBudgeted > 0 && envelopes.isEmpty {
                Text("Create envelopes with allocation rules first.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .dashboardCard()
    }

    // MARK: Flow

    private var flowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where your money goes").font(.headline)
            Text("\(totalDistributed.asCurrency) distributed across \(history.count) paycheck\(history.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
            DistributionFlowView(slices: flowSlices)
                .padding(.top, 4)
        }
        .dashboardCard()
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(Array(history.enumerated()), id: \.element.id) { index, event in
                NavigationLink {
                    DistributionEventDetailView(event: event)
                } label: {
                    historyRow(event)
                }
                .buttonStyle(.plain)
                if index < history.count - 1 { Divider() }
            }
        }
        .dashboardCard()
    }

    private func historyRow(_ event: BudgetMath.DistributionEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.branch")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 30, height: 30)
                .background(Color.green.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                Text(rowSubtitle(event))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.total.asCurrency)
                .font(.subheadline.weight(.semibold)).monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func rowSubtitle(_ event: BudgetMath.DistributionEvent) -> String {
        let envelopes = "\(event.envelopeCount) envelope\(event.envelopeCount == 1 ? "" : "s")"
        if let account = event.accountName { return "\(envelopes) · \(account)" }
        return envelopes
    }

    private var emptyHistory: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.branch")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No distributions yet").font(.headline)
            Text("Distribute a paycheck to see where your money goes and build a history here.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .dashboardCard()
    }

    // MARK: Helpers

    /// Turn per-envelope totals into colored flow slices, grouping the long tail
    /// beyond `maxSlices` into a single "Other" slice (like the reference report).
    private func aggregateSlices(from shares: [BudgetMath.DistributionShare],
                                 maxSlices: Int) -> [DistributionFlowView.Slice] {
        guard !shares.isEmpty else { return [] }
        func slice(_ s: BudgetMath.DistributionShare) -> DistributionFlowView.Slice {
            .init(id: s.id, name: s.name, amount: s.amount, color: FlowPalette.color(for: s.id))
        }
        guard shares.count > maxSlices else { return shares.map(slice) }

        var result = shares.prefix(maxSlices - 1).map(slice)
        let otherTotal = shares.dropFirst(maxSlices - 1).reduce(Decimal(0)) { $0 + $1.amount }
        result.append(.init(id: UUID(), name: "Other", amount: otherTotal, color: FlowPalette.other))
        return result
    }
}

#if DEBUG
#Preview {
    DistributeView()
        .modelContainer(for: [Institution.self, Account.self, Envelope.self,
                              Transaction.self, AllocationRule.self], inMemory: true)
}
#endif
