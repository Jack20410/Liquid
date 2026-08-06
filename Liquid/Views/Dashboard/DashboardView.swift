//
//  DashboardView.swift
//  Liquid
//
//  The first screen the user sees (spec FR-15, FR-13): the To Be Budgeted
//  headline, total across accounts, envelope balances with target progress, and
//  a 30-day cash-flow chart. Each card links into its tab.
//
//  Chart design notes:
//  • "To Be Budgeted" is a headline number, not a chart — a hero tile.
//  • Envelopes/accounts use horizontal bars: identity comes from the row label
//    (never from color alone); one hue for magnitude, red reserved as a status
//    color for negative (overspent) balances.
//  • Cash flow is a diverging daily bar chart around a zero baseline with a
//    legend, tap-to-inspect via chartXSelection.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var showingCalendar = false

    private var isEmpty: Bool {
        accounts.isEmpty && envelopes.isEmpty && transactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    EmptyStateView(
                        icon: "square.grid.2x2",
                        title: "Welcome to Liquid",
                        message: "Start by adding an account, then create envelopes to give your money a job.",
                        actionTitle: "Add an Account",
                        action: { selectedTab = .accounts }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ToBeBudgetedCard(amount: BudgetMath.toBeBudgeted(transactions: transactions))

                            if !accounts.isEmpty {
                                AccountsCard(accounts: accounts) { selectedTab = .accounts }
                            }
                            if !envelopes.isEmpty {
                                EnvelopesCard(envelopes: envelopes) { selectedTab = .envelopes }
                            }
                            CashFlowCard(transactions: transactions) { selectedTab = .transactions }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Spending calendar")
                }
            }
            .sheet(isPresented: $showingCalendar) {
                SpendingCalendarView()
            }
        }
    }
}

// MARK: - Card chrome

/// Shared card container with a tappable header that jumps to the owning tab.
private struct DashboardCard<Content: View>: View {
    let title: String
    let onOpen: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let onOpen {
                Button(action: onOpen) {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
                .accessibilityHint("Opens the \(title) tab")
            } else {
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 16))
    }
}

// MARK: - To Be Budgeted (hero tile)

private struct ToBeBudgetedCard: View {
    let amount: Decimal

    private var statusColor: Color {
        if amount > 0 { .green }
        else if amount < 0 { .red }
        else { .secondary }
    }

    private var caption: String {
        if amount > 0 { "Income waiting for a job — distribute it into envelopes." }
        else if amount < 0 { "Envelopes claim more than your income. Review allocations." }
        else { "Every dollar has a job. Nicely done." }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To Be Budgeted")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(statusColor)
                .contentTransition(.numericText())
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("To Be Budgeted: \(amount.asCurrency)")
    }
}

// MARK: - Accounts

private struct BarDatum: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    var target: Double?
}

private struct AccountsCard: View {
    let accounts: [Account]
    let onOpen: () -> Void

    private var data: [BarDatum] {
        accounts.map {
            BarDatum(id: $0.id, name: $0.name,
                     value: BudgetMath.accountBalance($0).asDouble)
        }
    }

    var body: some View {
        DashboardCard(title: "Accounts", onOpen: onOpen) {
            HStack {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(BudgetMath.totalAccountsBalance(accounts).asCurrency)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            Chart(data) { item in
                BarMark(
                    x: .value("Balance", item.value),
                    y: .value("Account", item.name)
                )
                .foregroundStyle(item.value < 0 ? Color.red : Color.blue)
                .clipShape(.rect(cornerRadius: 4))
                .annotation(position: item.value < 0 ? .leading : .trailing, spacing: 6) {
                    Text(Decimal(item.value).asCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .chartXAxis(.hidden)                    // values are direct-labeled
            .chartYAxis {
                AxisMarks(preset: .extended) {      // recessive: names only
                    AxisValueLabel()
                }
            }
            .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 56))
            .frame(height: CGFloat(data.count) * 40)
        }
    }
}

// MARK: - Envelopes

private struct EnvelopesCard: View {
    let envelopes: [Envelope]
    let onOpen: () -> Void

    private var data: [BarDatum] {
        envelopes.map {
            BarDatum(id: $0.id, name: $0.name,
                     value: BudgetMath.envelopeBalance($0).asDouble,
                     target: $0.target.map(\.asDouble))
        }
    }

    var body: some View {
        DashboardCard(title: "Envelopes", onOpen: onOpen) {
            Chart(data) { item in
                BarMark(
                    x: .value("Balance", item.value),
                    y: .value("Envelope", item.name)
                )
                .foregroundStyle(item.value < 0 ? Color.red : Color.teal)
                .clipShape(.rect(cornerRadius: 4))
                .annotation(position: item.value < 0 ? .leading : .trailing, spacing: 6) {
                    // Balance, plus progress toward the savings target when one
                    // is set (FR-14). Progress is a label, not a bar, so one
                    // envelope's big target can't crush the shared scale.
                    HStack(spacing: 4) {
                        Text(Decimal(item.value).asCurrency)
                            .foregroundStyle(item.value < 0 ? Color.red : Color.secondary)
                        if let target = item.target, target > 0 {
                            Text("· \(Int((min(max(item.value / target, 0), 1) * 100).rounded()))% of \(Decimal(target).asCurrency)")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(preset: .extended) {
                    AxisValueLabel()
                }
            }
            .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 130))
            .frame(height: CGFloat(data.count) * 44)

            if data.contains(where: { $0.value < 0 }) {
                Label("Red bars are overspent envelopes.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Cash flow (last 30 days)

private struct DayFlow: Identifiable {
    let day: Date
    let kind: String        // "Income" | "Spending"
    let amount: Double      // signed: income +, spending −
    var id: String { "\(day.timeIntervalSince1970)-\(kind)" }
}

private struct CashFlowCard: View {
    let transactions: [Transaction]
    let onOpen: () -> Void

    @State private var selectedDay: Date?

    private static let windowDays = 30

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -(Self.windowDays - 1),
                              to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    /// Daily income (+) and spending (−) inside the window, built from the shared
    /// `BudgetMath.dailySummaries` helper (allocations excluded).
    private var data: [DayFlow] {
        BudgetMath.dailySummaries(transactions)
            .values
            .filter { $0.day >= windowStart }
            .flatMap { summary in
                [DayFlow(day: summary.day, kind: "Income", amount: summary.income.asDouble),
                 DayFlow(day: summary.day, kind: "Spending", amount: -summary.spending.asDouble)]
            }
            .filter { $0.amount != 0 }
            .sorted { $0.day < $1.day }
    }

    private var selectedSummary: (day: Date, income: Double, spending: Double)? {
        guard let selectedDay else { return nil }
        let day = Calendar.current.startOfDay(for: selectedDay)
        let entries = data.filter { $0.day == day }
        guard !entries.isEmpty else { return nil }
        let income = entries.first { $0.kind == "Income" }?.amount ?? 0
        let spending = entries.first { $0.kind == "Spending" }?.amount ?? 0
        return (day, income, spending)
    }

    var body: some View {
        DashboardCard(title: "Cash Flow · 30 Days", onOpen: onOpen) {
            if data.isEmpty {
                Text("No income or spending in the last 30 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(data) { flow in
                    BarMark(
                        x: .value("Day", flow.day, unit: .day),
                        y: .value("Amount", flow.amount)
                    )
                    .foregroundStyle(by: .value("Kind", flow.kind))
                    .clipShape(.rect(cornerRadius: 2))

                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.quaternary)
                        .lineStyle(StrokeStyle(lineWidth: 1))

                    if let summary = selectedSummary {
                        RuleMark(x: .value("Selected", summary.day, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .annotation(position: .top,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                SelectedDayCallout(day: summary.day,
                                                   income: summary.income,
                                                   spending: summary.spending)
                            }
                    }
                }
                .chartForegroundStyleScale(["Income": Color.green, "Spending": Color.red])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartXScale(domain: windowStart...Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisValueLabel()
                    }
                }
                .chartXSelection(value: $selectedDay)
                .frame(height: 180)

                Text("Tap a day to see its totals. Allocations aren't cash flow, so they're not shown.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Callout shown above the selected day in the cash-flow chart.
private struct SelectedDayCallout: View {
    let day: Date
    let income: Double
    let spending: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption.weight(.semibold))
            if income > 0 {
                Text("In \(Decimal(income).asCurrency)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            if spending < 0 {
                Text("Out \(Decimal(-spending).asCurrency)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .monospacedDigit()
        .padding(8)
        .background(.background.secondary, in: .rect(cornerRadius: 8))
        .shadow(radius: 2, y: 1)
    }
}

#Preview {
    @Previewable @State var tab: AppTab = .dashboard
    return DashboardView(selectedTab: $tab)
        .modelContainer(for: [Account.self, Envelope.self, Transaction.self, AllocationRule.self],
                        inMemory: true)
}
