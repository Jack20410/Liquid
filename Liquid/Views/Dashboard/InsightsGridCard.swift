//
//  InsightsGridCard.swift
//  Liquid
//
//  The visual replacement for the old sentence-based Insights card: a 2×2 grid of
//  glanceable tiles — Trend, Top Spending, Planned, Saving Rate — each a big number
//  and a mini chart, scoped to the selected month. The section header taps through
//  to InsightsDetailView, which keeps the fuller, narrated read (including the
//  on-device AI summary). Facts come from MonthlyInsights; colors are assigned here.
//

import SwiftUI

struct InsightsGridCard: View {
    let transactions: [Transaction]
    let envelopes: [Envelope]
    let accounts: [Account]
    /// The month to summarize (its `asOf` reference point).
    let month: Date

    private static let palette: [Color] = Color.categoryPalette
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var insights: MonthlyInsights {
        MonthlyInsights.compute(transactions: transactions, envelopes: envelopes, asOf: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                InsightsDetailView(transactions: transactions, envelopes: envelopes, accounts: accounts)
            } label: {
                HStack(spacing: 4) {
                    Text("Insights").font(.headline)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .tint(.primary)
            .accessibilityHint("Opens a fuller, narrated breakdown")

            LazyVGrid(columns: columns, spacing: 12) {
                trendTile
                topSpendingTile
                plannedTile
                savingRateTile
            }
        }
    }

    // MARK: Trend

    @ViewBuilder private var trendTile: some View {
        let icon = "chart.line.uptrend.xyaxis"
        if let trend = insights.trend {
            // Spending up is the concerning direction (coral); down is good (green).
            let tint = trend.isUp ? Color.decrease : Color.increase
            InsightTile(icon: icon, title: "Trend",
                        value: "\(trend.percent > 0 ? "+" : "")\(trend.percent)%",
                        status: trend.isUp ? "Increasing" : "Decreasing",
                        statusTint: tint, trendUp: trend.isUp) {
                Sparkline(values: trend.series, tint: tint)
            }
        } else {
            emptyTile(icon: icon, title: "Trend")
        }
    }

    // MARK: Top spending

    @ViewBuilder private var topSpendingTile: some View {
        let icon = "chart.pie"
        if let top = insights.topSpending {
            let slices = top.slices.enumerated().map { i, slice in
                DonutSlice(id: slice.id, amount: slice.amount.asDouble,
                           color: Self.palette[i % Self.palette.count])
            }
            InsightTile(icon: icon, title: "Top Spending", value: top.amount.asCurrency,
                        status: top.category, statusTint: Self.palette.first ?? .accentColor) {
                MiniDonut(slices: slices)
            }
        } else {
            emptyTile(icon: icon, title: "Top Spending")
        }
    }

    // MARK: Planned (bills)

    @ViewBuilder private var plannedTile: some View {
        let icon = "calendar.badge.clock"
        if let planned = insights.planned {
            InsightTile(icon: icon, title: "Planned", value: planned.total.asCurrency,
                        status: "\(planned.items.count) bill\(planned.items.count == 1 ? "" : "s")",
                        statusTint: .secondary) {
                MiniBars(values: planned.items.map { $0.amount.asDouble }, tint: .deepTeal)
            }
        } else {
            emptyTile(icon: icon, title: "Planned")
        }
    }

    // MARK: Saving rate

    @ViewBuilder private var savingRateTile: some View {
        let icon = "leaf"
        if let saving = insights.savingRate {
            let percent = Int((saving.rate * 100).rounded())
            let tint = tint(for: saving.rating)
            InsightTile(icon: icon, title: "Saving Rate",
                        value: "\(percent >= 0 ? "+" : "")\(percent)%",
                        status: saving.rating.label, statusTint: tint) {
                ZStack {
                    ProgressRing(progress: saving.rate, lineWidth: 9,
                                 colors: [tint.opacity(0.7), tint])
                        .frame(width: 52, height: 52)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            emptyTile(icon: icon, title: "Saving Rate")
        }
    }

    // MARK: Helpers

    private func tint(for rating: SavingsRating) -> Color {
        switch rating {
        case .excellent, .good: Color.increase
        case .fair: .secondary
        case .low: Color.decrease
        }
    }

    private func emptyTile(icon: String, title: String) -> some View {
        InsightTile(icon: icon, title: title, value: "—", status: "No data yet",
                    statusTint: .secondary) {
            Color.clear
        }
    }
}
