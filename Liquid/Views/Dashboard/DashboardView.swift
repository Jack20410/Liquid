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
    @State private var showingSettings = false
    @AppStorage(ChartStyleKey.cardOrder) private var cardOrderRaw = DashboardCardID.rawValue(for: DashboardCardID.defaultOrder)

    private var isEmpty: Bool {
        accounts.isEmpty && envelopes.isEmpty && transactions.isEmpty
    }

    private var cardOrder: [DashboardCardID] {
        DashboardCardID.order(from: cardOrderRaw)
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
                            ForEach(cardOrder) { card in
                                dashboardCard(card)
                            }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingCalendar) {
                SpendingCalendarView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    /// Render one dashboard card by id, in the user's chosen order. Cards with
    /// nothing to show are skipped.
    @ViewBuilder
    private func dashboardCard(_ card: DashboardCardID) -> some View {
        switch card {
        case .toBeBudgeted:
            ToBeBudgetedCard(amount: BudgetMath.toBeBudgeted(transactions: transactions)) {
                selectedTab = .distribute
            }
        case .accounts:
            if !accounts.isEmpty {
                AccountsCard(accounts: accounts) { selectedTab = .accounts }
            }
        case .envelopes:
            if !envelopes.isEmpty {
                EnvelopesCard(envelopes: envelopes) { selectedTab = .envelopes }
            }
        case .cashFlow:
            CashFlowCard(transactions: transactions) { selectedTab = .transactions }
        case .spending:
            SpendingByCategoryCard(transactions: transactions)
        case .netWorth:
            NetWorthTrendCard(transactions: transactions)
        }
    }
}

// MARK: - To Be Budgeted (hero tile)

private struct ToBeBudgetedCard: View {
    let amount: Decimal
    var onDistribute: (() -> Void)?

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
            if amount > 0, let onDistribute {
                Button(action: onDistribute) {
                    Label("Distribute", systemImage: "arrow.branch")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("To Be Budgeted: \(amount.asCurrency)")
    }
}

private let dashboardPalette: [Color] = [.blue, .orange, .teal, .yellow, .pink]

// MARK: - Accounts

private struct AccountsCard: View {
    let accounts: [Account]
    let onOpen: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(ChartStyleKey.accounts) private var style: AccountsChartStyle = .bars

    private var repository: SwiftDataBudgetRepository { SwiftDataBudgetRepository(context: modelContext) }

    private var groups: [(bank: String, accounts: [Account])] {
        Dictionary(grouping: accounts) { $0.institution?.name ?? "" }
            .map { (bank: $0.key, accounts: $0.value.sorted { $0.name < $1.name }) }
            .sorted { l, r in
                if l.bank.isEmpty != r.bank.isEmpty { return !l.bank.isEmpty }
                return l.bank < r.bank
            }
    }

    private var maxMagnitude: Double {
        accounts.map { abs(BudgetMath.accountBalance($0).asDouble) }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Accounts", onOpen: onOpen) {
                ChartStyleMenu(selection: $style, options: AccountsChartStyle.allCases)
            }

            HStack {
                Text("Net Worth").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(BudgetMath.totalAccountsBalance(accounts).asCurrency)
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }

            if style == .stacked { stackedBar }

            ForEach(groups, id: \.bank) { group in
                VStack(alignment: .leading, spacing: 6) {
                    if let header = bankHeader(group.bank) {
                        Text(header).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(group.accounts) { account in
                        accountRow(account)
                    }
                }
            }
        }
        .dashboardCard()
    }

    private func bankHeader(_ bank: String) -> String? {
        if !bank.isEmpty { return bank }
        return groups.count > 1 ? "Other" : nil
    }

    private func accountRow(_ account: Account) -> some View {
        let balance = BudgetMath.accountBalance(account)
        let negative = balance < 0
        return NavigationLink {
            AccountDetailView(account: account, repository: repository)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: account.type.icon)
                    .font(.footnote).foregroundStyle(.secondary).frame(width: 22)
                Text(account.name).font(.subheadline).lineLimit(1)
                    .frame(minWidth: 60, alignment: .leading)
                if style == .bars {
                    GeometryReader { geo in
                        Capsule().fill(negative ? Color.red : Color.blue)
                            .frame(width: max(4, geo.size.width * abs(balance.asDouble) / maxMagnitude))
                    }
                    .frame(height: 12)
                }
                Spacer(minLength: 6)
                Text(balance.asCurrency)
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(negative ? .red : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var stackedBar: some View {
        let assets = BudgetMath.totalAssets(accounts).asDouble
        let liabilities = BudgetMath.totalLiabilities(accounts).asDouble
        let total = max(assets + liabilities, 1)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: liabilities > 0 ? 2 : 0) {
                    Capsule().fill(.green).frame(width: geo.size.width * assets / total)
                    if liabilities > 0 {
                        Capsule().fill(.red).frame(width: geo.size.width * liabilities / total)
                    }
                }
            }
            .frame(height: 16)
            HStack {
                Text("Assets \(Decimal(assets).asCurrency)").foregroundStyle(.green)
                Spacer()
                Text("Liabilities \(Decimal(liabilities).asCurrency)").foregroundStyle(.red)
            }
            .font(.caption).monospacedDigit()
        }
    }
}

// MARK: - Envelopes

private struct EnvelopesCard: View {
    let envelopes: [Envelope]
    let onOpen: () -> Void

    @AppStorage(ChartStyleKey.envelopes) private var style: EnvelopeChartStyle = .bars

    private static let topN = 4

    private struct Item: Identifiable {
        let id: UUID
        let name: String
        let balance: Decimal
        let target: Decimal?
        let color: Color
        let envelope: Envelope
    }

    /// Envelopes ranked by balance, with a color assigned in fixed order.
    private var ranked: [Item] {
        envelopes
            .sorted { BudgetMath.envelopeBalance($0) > BudgetMath.envelopeBalance($1) }
            .enumerated()
            .map { i, env in
                Item(id: env.id, name: env.name, balance: BudgetMath.envelopeBalance(env),
                     target: env.target, color: dashboardPalette[i % dashboardPalette.count], envelope: env)
            }
    }

    private var shown: [Item] { Array(ranked.prefix(Self.topN)) }
    private var maxBalance: Double { max(ranked.map { $0.balance.asDouble }.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Envelopes", onOpen: onOpen) {
                ChartStyleMenu(selection: $style, options: EnvelopeChartStyle.allCases)
            }
            Text("What's left to spend")
                .font(.caption).foregroundStyle(.secondary)

            if style == .bars {
                VStack(spacing: 10) {
                    ForEach(shown) { bulletRow($0) }
                }
            } else {
                donut
            }

            if ranked.count > shown.count {
                Button(action: onOpen) {
                    Text("See all \(ranked.count)")
                        .font(.subheadline)
                }
            }
        }
        .dashboardCard()
    }

    private func bulletRow(_ item: Item) -> some View {
        let overspent = item.balance < 0
        let fraction: Double = {
            if let t = item.target, t > 0 { return clampUnit(item.balance.asDouble / t.asDouble) }
            return clampUnit(item.balance.asDouble / maxBalance)
        }()
        return NavigationLink {
            EnvelopeDetailView(envelope: item.envelope)
        } label: {
            HStack(spacing: 10) {
                Text(item.name).font(.subheadline).lineLimit(1)
                    .frame(width: 76, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule().fill(overspent ? Color.red : item.color)
                            .frame(width: max(overspent ? 0 : 4, geo.size.width * fraction))
                        if item.target != nil {
                            Rectangle().fill(Color(.label).opacity(0.35))
                                .frame(width: 2, height: 16)
                                .position(x: geo.size.width - 1, y: 6)
                        }
                    }
                }
                .frame(height: 12)
                Text(label(item))
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(overspent ? .red : .secondary)
                    .frame(width: 96, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
    }

    private func label(_ item: Item) -> String {
        if let t = item.target, t > 0 {
            let pct = Int((clampUnit(item.balance.asDouble / t.asDouble) * 100).rounded())
            return "\(item.balance.asCurrency) · \(pct)%"
        }
        return item.balance.asCurrency
    }

    private var donut: some View {
        let positive = shown.filter { $0.balance > 0 }
        let total = positive.reduce(Decimal(0)) { $0 + $1.balance }
        return VStack(spacing: 12) {
            ZStack {
                Chart(positive) { item in
                    SectorMark(angle: .value("Balance", item.balance.asDouble),
                               innerRadius: .ratio(0.62), angularInset: 1.5)
                    .cornerRadius(4)
                    .foregroundStyle(item.color)
                }
                .frame(height: 160)
                VStack(spacing: 1) {
                    Text("budgeted").font(.caption2).foregroundStyle(.secondary)
                    Text(total.asCurrency).font(.callout.weight(.semibold)).monospacedDigit()
                }
            }
            VStack(spacing: 8) {
                ForEach(shown) { item in
                    NavigationLink {
                        EnvelopeDetailView(envelope: item.envelope)
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(item.balance < 0 ? Color.red : item.color)
                                .frame(width: 10, height: 10)
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text(item.balance.asCurrency)
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(item.balance < 0 ? .red : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func clampUnit(_ v: Double) -> Double { min(1, max(0, v)) }
}

// MARK: - Cash flow (last 30 days)

private struct DayFlow: Identifiable {
    let day: Date
    let kind: String        // "Income" | "Spending"
    let amount: Double      // signed: income +, spending −
    var id: String { "\(day.timeIntervalSince1970)-\(kind)" }
}

private struct DayNet: Identifiable {
    let day: Date
    let net: Double         // income − spending
    var id: Date { day }
}

private struct CashFlowCard: View {
    let transactions: [Transaction]
    let onOpen: () -> Void

    @State private var selectedDay: Date?
    @AppStorage(ChartStyleKey.cashFlow) private var style: CashFlowChartStyle = .bars

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

    /// Net (income − spending) for every day in the window, including zero days,
    /// so the line variant sits on the baseline on quiet days.
    private var dailyNet: [DayNet] {
        let summaries = BudgetMath.dailySummaries(transactions)
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        var day = windowStart
        var out: [DayNet] = []
        while day <= end {
            let s = summaries[day]
            out.append(DayNet(day: day, net: ((s?.income ?? 0) - (s?.spending ?? 0)).asDouble))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onOpen) {
                    HStack(spacing: 4) {
                        Text("Cash Flow · 30 Days").font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
                .accessibilityHint("Opens the Transactions tab")
                Spacer()
                styleMenu
            }

            if data.isEmpty {
                Text("No income or spending in the last 30 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                if style == .bars { barsChart } else { lineChart }
                Text("Tap a day to see its totals. Allocations aren't cash flow, so they're not shown.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .dashboardCard()
    }

    private var styleMenu: some View {
        Menu {
            Picker("Chart style", selection: $style) {
                ForEach(CashFlowChartStyle.allCases) { s in
                    Label(s.displayName, systemImage: s.icon).tag(s)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
        }
        .accessibilityLabel("Change chart style")
    }

    private var xDomain: ClosedRange<Date> {
        windowStart...Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
    }

    private var barsChart: some View {
        Chart(data) { flow in
            BarMark(x: .value("Day", flow.day, unit: .day),
                    y: .value("Amount", flow.amount))
            .foregroundStyle(by: .value("Kind", flow.kind))
            .clipShape(.rect(cornerRadius: 2))

            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.quaternary).lineStyle(StrokeStyle(lineWidth: 1))

            selectionRule
        }
        .chartForegroundStyleScale(["Income": Color.green, "Spending": Color.red])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXScale(domain: xDomain)
        .chartXAxis { cashFlowXAxis }
        .chartYAxis { cashFlowYAxis }
        .chartXSelection(value: $selectedDay)
        .frame(height: 180)
    }

    private var lineChart: some View {
        Chart {
            ForEach(dailyNet) { d in
                LineMark(x: .value("Day", d.day, unit: .day),
                         y: .value("Net", d.net))
                .interpolationMethod(.monotone)
                .foregroundStyle(.blue)
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.quaternary).lineStyle(StrokeStyle(lineWidth: 1))

            selectionRule
        }
        .chartXScale(domain: xDomain)
        .chartXAxis { cashFlowXAxis }
        .chartYAxis { cashFlowYAxis }
        .chartXSelection(value: $selectedDay)
        .frame(height: 180)
    }

    @ChartContentBuilder
    private var selectionRule: some ChartContent {
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

    private var cashFlowXAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7)) {
            AxisGridLine().foregroundStyle(.quaternary)
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    }

    private var cashFlowYAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 3)) {
            AxisGridLine().foregroundStyle(.quaternary)
            AxisValueLabel()
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
