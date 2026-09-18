//
//  EnvelopesView.swift
//  Liquid
//
//  Budget categories grouped by kind (Spending / Bills / Goals), each row showing
//  a colored badge and a spend-vs-budget bar or goal ring, with a header summary
//  (spec FR-7–FR-9, FR-14).
//

import SwiftUI
import SwiftData

struct EnvelopesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]

    @State private var editing: EnvelopeEditTarget?

    private let calendar = Calendar.current

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    private var colorMap: [UUID: Color] { CategoryStyle.colorMap(for: envelopes) }

    /// The current calendar month, used for spend-vs-budget.
    private var monthInterval: DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(2_592_000)
        return DateInterval(start: start, end: end)
    }

    private func envelopes(of kind: EnvelopeKind) -> [Envelope] {
        envelopes
            .filter { $0.kind == kind }
            .sorted { BudgetMath.envelopeBalance($0) > BudgetMath.envelopeBalance($1) }
    }

    private func sectionTotal(_ kind: EnvelopeKind) -> Decimal {
        envelopes(of: kind).reduce(0) { $0 + BudgetMath.envelopeBalance($1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if envelopes.isEmpty {
                    EmptyStateView(
                        icon: "tray.full",
                        title: "No Envelopes",
                        message: "Create categories like Rent or Groceries to give your money a job.",
                        actionTitle: "Add Envelope",
                        action: { editing = .new }
                    )
                } else {
                    list
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Envelope", systemImage: "plus") { editing = .new }
                }
            }
            .sheet(item: $editing) { target in
                EnvelopeEditView(target: target,
                                 repository: repository,
                                 existingEnvelopes: envelopes)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(EnvelopeKind.allCases) { kind in
                let items = envelopes(of: kind)
                if !items.isEmpty {
                    Section {
                        ForEach(items) { envelope in
                            NavigationLink {
                                EnvelopeDetailView(envelope: envelope)
                            } label: {
                                EnvelopeRow(envelope: envelope,
                                            color: CategoryStyle.color(for: envelope, categoryColors: colorMap),
                                            monthInterval: monthInterval)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    repository.deleteEnvelope(envelope)
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editing = .existing(envelope)
                                }
                                .tint(.orange)
                            }
                        }
                    } header: {
                        sectionHeader(kind)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            EnvelopesSummaryCard(envelopes: envelopes, monthInterval: monthInterval)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
        }
    }

    private func sectionHeader(_ kind: EnvelopeKind) -> some View {
        let total = sectionTotal(kind)
        return HStack {
            Text(kind.sectionTitle)
            Spacer()
            Text(total.asCurrency)
                .monospacedDigit()
                .foregroundStyle(total < 0 ? Color.decrease : .secondary)
        }
        .font(.caption)
        .textCase(nil)
    }
}

// MARK: - Header summary

private struct EnvelopesSummaryCard: View {
    let envelopes: [Envelope]
    let monthInterval: DateInterval

    private var safeToSpend: Decimal { BudgetMath.safeToSpend(envelopes) }
    private var spent: Decimal {
        envelopes.reduce(0) { $0 + BudgetMath.envelopeSpend($1, in: monthInterval) }
    }
    private var budgeted: Decimal {
        envelopes.reduce(0) { $0 + BudgetMath.envelopeAllocated($1, in: monthInterval) }
    }
    private var fraction: Double {
        let base = max(budgeted, spent)
        return base > 0 ? (spent / base).asDouble : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe to spend").font(.caption).foregroundStyle(.secondary)
                    Text(safeToSpend.asCurrency)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(safeToSpend < 0 ? Color.decrease : .primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("This month").font(.caption2).foregroundStyle(.secondary)
                    Text("\(spent.asCurrency) of \(budgeted.asCurrency)")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            BudgetBar(fraction: fraction, color: spent > budgeted ? .decrease : .accentColor, height: 8)
        }
        .dashboardCard()
    }
}

// MARK: - Row

private struct EnvelopeRow: View {
    let envelope: Envelope
    let color: Color
    let monthInterval: DateInterval

    private var balance: Decimal { BudgetMath.envelopeBalance(envelope) }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(systemImage: CategoryStyle.icon(for: envelope), color: color)
            if envelope.kind == .goal {
                goalContent
            } else {
                spendingContent
            }
        }
    }

    // Spending / bills: name + rule chip + spend-vs-budget bar + balance.
    private var spendingContent: some View {
        let spent = BudgetMath.envelopeSpend(envelope, in: monthInterval)
        let budget = budgetBaseline(spent: spent)
        let fraction = budget > 0 ? (spent / budget).asDouble : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(envelope.name)
                ruleChip
                Spacer()
                Text(balance.asCurrency)
                    .foregroundStyle(balance < 0 ? Color.decrease : .secondary)
                    .monospacedDigit()
            }
            BudgetBar(fraction: fraction, color: spent > budget ? .decrease : color)
            HStack {
                Text("\(spent.asCurrency) spent").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("of \(budget.asCurrency)").font(.caption2).foregroundStyle(.tertiary)
            }
            .monospacedDigit()
        }
    }

    // Goals: name + saved/target + a progress ring.
    private var goalContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(envelope.name)
                    ruleChip
                }
                if let target = envelope.target, target > 0 {
                    Text("\(balance.asCurrency) of \(target.asCurrency)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text(balance.asCurrency)
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer()
            if let progress = BudgetMath.targetProgress(envelope) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 5, colors: [color.opacity(0.7), color])
                        .frame(width: 36, height: 36)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Budget baseline for the bar: the fixed-rule amount, else what was allocated
    /// this month, else fall back so a funded-but-unruled envelope still shows.
    private func budgetBaseline(spent: Decimal) -> Decimal {
        if case let .fixed(value)? = envelope.rule?.strategy, value > 0 { return value }
        let allocated = BudgetMath.envelopeAllocated(envelope, in: monthInterval)
        if allocated > 0 { return allocated }
        return max(spent + max(balance, 0), spent, 1)
    }

    @ViewBuilder private var ruleChip: some View {
        if let rule = envelope.rule {
            Text(ruleLabel(rule))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: .capsule)
        }
    }

    private func ruleLabel(_ rule: AllocationRule) -> String {
        switch rule.strategy {
        case let .fixed(v): "Fixed \(v.asCurrency)"
        case let .percentage(p): "\((p * 100).formatted())%"
        case let .fillToTarget(t): "Fill → \(t.asCurrency)"
        case .remainder: "Remainder"
        }
    }
}

private extension EnvelopeKind {
    var sectionTitle: String {
        switch self {
        case .spending: "Spending"
        case .bill: "Bills"
        case .goal: "Goals"
        }
    }
}

/// What the edit sheet is currently editing.
enum EnvelopeEditTarget: Identifiable {
    case new
    case existing(Envelope)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(envelope): envelope.id.uuidString
        }
    }
}
