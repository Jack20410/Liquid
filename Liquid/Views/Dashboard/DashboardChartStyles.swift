//
//  DashboardChartStyles.swift
//  Liquid
//
//  User customization of the dashboard: which chart form a card uses and the
//  order cards appear in. Choices are stored in UserDefaults via @AppStorage, so
//  the on-card menus and the Settings screen read and write the same keys and
//  stay in sync automatically.
//

import SwiftUI

/// UserDefaults keys shared by the cards and the Settings screen.
enum ChartStyleKey {
    static let category = "dashboard.categoryChartStyle"
    static let cashFlow = "dashboard.cashFlowChartStyle"
    static let cardOrder = "dashboard.cardOrder"
}

/// A chart-form choice a card exposes (name + SF Symbol), shared by the on-card
/// menu and the Settings customization screen.
protocol ChartStyleOption: CaseIterable, Identifiable, Hashable {
    var displayName: String { get }
    var icon: String { get }
}

enum CategoryChartStyle: String, CaseIterable, Identifiable, ChartStyleOption {
    case bars, donut
    var id: String { rawValue }
    var displayName: String { self == .bars ? "Bars" : "Donut" }
    var icon: String { self == .bars ? "chart.bar" : "chart.pie" }
}

enum CashFlowChartStyle: String, CaseIterable, Identifiable, ChartStyleOption {
    case bars, line
    var id: String { rawValue }
    var displayName: String { self == .bars ? "Bars" : "Line" }
    var icon: String { self == .bars ? "chart.bar.xaxis" : "chart.xyaxis.line" }
}

/// The dashboard's cards, in a user-arrangeable order. Net worth defaults to the
/// bottom: this is a money-tracking app, not an investing app, so the budget
/// cards lead and the trend is context.
enum DashboardCardID: String, CaseIterable, Identifiable {
    case toBeBudgeted, safeToSpend, accounts, envelopes, cashFlow, spending, netWorth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toBeBudgeted: "To Be Budgeted"
        case .safeToSpend: "Safe to Spend"
        case .accounts: "Accounts"
        case .envelopes: "Envelopes"
        case .cashFlow: "Cash flow"
        case .spending: "Spending by category"
        case .netWorth: "Net worth trend"
        }
    }

    var icon: String {
        switch self {
        case .toBeBudgeted: "tray.and.arrow.down"
        case .safeToSpend: "dollarsign.circle"
        case .accounts: "building.columns"
        case .envelopes: "tray.full"
        case .cashFlow: "chart.bar.xaxis"
        case .spending: "chart.pie"
        case .netWorth: "chart.line.uptrend.xyaxis"
        }
    }

    static let defaultOrder: [DashboardCardID] = [
        .toBeBudgeted, .safeToSpend, .accounts, .envelopes, .cashFlow, .spending, .netWorth,
    ]

    /// Parse a stored order string, dropping unknown entries and appending any
    /// cards missing from it (so new cards appear after an app update).
    static func order(from raw: String) -> [DashboardCardID] {
        var order = raw.split(separator: ",").compactMap { DashboardCardID(rawValue: String($0)) }
        for card in defaultOrder where !order.contains(card) {
            order.append(card)
        }
        return order
    }

    static func rawValue(for order: [DashboardCardID]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }
}

extension View {
    /// Standard dashboard card chrome (surface, padding, rounded corners).
    func dashboardCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

/// A card's header: a title that opens the owning tab, plus a trailing accessory
/// (typically a chart-style menu).
struct CardHeader<Accessory: View>: View {
    let title: String
    var onOpen: (() -> Void)?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            if let onOpen {
                Button(action: onOpen) {
                    HStack(spacing: 4) {
                        Text(title).font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
                .accessibilityHint("Opens the \(title) tab")
            } else {
                Text(title).font(.headline)
            }
            Spacer()
            accessory
        }
    }
}

/// Compact on-card menu to pick a chart form.
struct ChartStyleMenu<Style: ChartStyleOption>: View where Style.AllCases: RandomAccessCollection {
    @Binding var selection: Style
    var options: Style.AllCases

    var body: some View {
        Menu {
            Picker("Chart type", selection: $selection) {
                ForEach(Array(options)) { style in
                    Label(style.displayName, systemImage: style.icon).tag(style)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
        }
        .accessibilityLabel("Change chart style")
    }
}
