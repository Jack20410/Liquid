//
//  InsightsGridCard.swift
//  Liquid
//
//  The visual replacement for the old sentence-based Insights card: a 2×2 grid of
//  glanceable tiles — Spending Trend, Top Spending, Bills Set Aside, Saving Rate —
//  each a big number and a mini chart, scoped to the selected month. The section
//  header taps through to InsightsDetailView, which keeps the fuller, narrated read
//  (including the on-device AI summary). Facts come from MonthlyInsights; colors
//  are assigned here.
//
//  Every tile carries a caption saying what its number is measured *against*: a
//  percentage with nothing to compare it to ("+13%") is trivia, and the donut's
//  wedges are named in a legend rather than left as colors the reader has to
//  decode.
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

    // MARK: Spending trend

    @ViewBuilder private var trendTile: some View {
        let icon = "chart.line.uptrend.xyaxis"
        if let trend = insights.trend {
            // Spending up is the concerning direction (coral); down is good (green).
            let tint = trend.isUp ? Color.decrease : Color.increase
            InsightTile(icon: icon, title: "Spending Trend",
                        value: "\(trend.percent > 0 ? "+" : "")\(trend.percent)%",
                        caption: "\(trend.current.asCurrency) so far vs \(trend.previous.asCurrency) by this day last month",
                        status: trend.isUp ? "Spending is up" : "Spending is down",
                        statusTint: tint, trendUp: trend.isUp) {
                Sparkline(values: trend.series, tint: tint)
            }
        } else {
            emptyTile(icon: icon, title: "Spending Trend",
                      caption: "Needs spending this month and last to compare")
        }
    }

    // MARK: Top spending

    @ViewBuilder private var topSpendingTile: some View {
        let icon = "chart.pie"
        if let top = insights.topSpending {
            InsightTile(icon: icon, title: "Top Spending", value: top.amount.asCurrency,
                        caption: "\(top.category) — \(top.share)% of what you spent this month",
                        status: "Across \(top.categoryCount) categor\(top.categoryCount == 1 ? "y" : "ies")",
                        statusTint: Self.palette.first ?? .accentColor) {
                topSpendingChart(top)
            }
        } else {
            emptyTile(icon: icon, title: "Top Spending", caption: "No spending recorded this month")
        }
    }

    /// Donut on the left, named legend on the right — the wedges are identified by
    /// name and share rather than by remembering which color meant which category.
    private func topSpendingChart(_ top: MonthlyInsights.TopSpending) -> some View {
        let total = top.slices.reduce(Decimal(0)) { $0 + $1.amount } + top.other
        var wedges = top.slices.enumerated().map { index, slice in
            DonutSlice(id: slice.id, amount: slice.amount.asDouble,
                       color: Self.palette[index % Self.palette.count])
        }
        if top.other > 0 {
            wedges.append(DonutSlice(id: "other", amount: top.other.asDouble, color: .gray))
        }

        // Up to three named rows, then one muted row counting whatever is left.
        let named = Array(top.slices.prefix(3))
        let remainder = top.other
            + top.slices.dropFirst(named.count).reduce(Decimal(0)) { $0 + $1.amount }
        let moreCount = max(top.categoryCount - named.count, 0)

        return HStack(spacing: 8) {
            MiniDonut(slices: wedges, innerRatio: 0.58)
                .frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(named.enumerated()), id: \.element.id) { index, slice in
                    legendRow(name: slice.name,
                              color: Self.palette[index % Self.palette.count],
                              share: share(slice.amount, of: total))
                }
                if remainder > 0, moreCount > 0 {
                    // No dot: these are several wedges of their own colors, not one
                    // category — the row counts them rather than naming a color.
                    legendRow(name: "\(moreCount) more", color: nil,
                              share: share(remainder, of: total))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendRow(name: String, color: Color?, share: Int) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color ?? .clear).frame(width: 6, height: 6)
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(color == nil ? .secondary : .primary)
            Spacer(minLength: 2)
            Text("\(share)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 10))
    }

    private func share(_ amount: Decimal, of total: Decimal) -> Int {
        guard total > 0 else { return 0 }
        return Int(((amount / total).asDouble * 100).rounded())
    }

    // MARK: Bills set aside

    @ViewBuilder private var plannedTile: some View {
        let icon = "calendar.badge.clock"
        if let planned = insights.planned {
            let count = planned.items.count
            let biggest = planned.items.first
            InsightTile(icon: icon, title: "Bills Set Aside", value: planned.total.asCurrency,
                        caption: "Money saved so far for \(count) upcoming bill\(count == 1 ? "" : "s")",
                        status: biggest.map { "\($0.name) \($0.amount.asCurrency)" },
                        statusTint: Self.palette.first ?? .accentColor) {
                MiniBars(values: planned.items.map { $0.amount.asDouble },
                         colors: planned.items.indices.map { Self.palette[$0 % Self.palette.count] })
            }
        } else {
            emptyTile(icon: icon, title: "Bills Set Aside",
                      caption: "Fund a bill envelope to see what's covered")
        }
    }

    // MARK: Saving rate

    @ViewBuilder private var savingRateTile: some View {
        let icon = "leaf"
        if let saving = insights.savingRate {
            let percent = Int((saving.rate * 100).rounded())
            let tint = tint(for: saving.rating)
            let verb = saving.kept < 0 ? "You overspent by" : "You kept"
            InsightTile(icon: icon, title: "Saving Rate",
                        value: "\(percent >= 0 ? "+" : "")\(percent)%",
                        caption: "\(verb) \(abs(saving.kept).asCurrency) of \(saving.income.asCurrency) income",
                        status: saving.rating.label, statusTint: tint) {
                ZStack {
                    ProgressRing(progress: saving.rate, lineWidth: 9,
                                 colors: [tint.opacity(0.7), tint])
                        .frame(width: 52, height: 52)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            emptyTile(icon: icon, title: "Saving Rate", caption: "No income recorded this month")
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

    private func emptyTile(icon: String, title: String, caption: String) -> some View {
        InsightTile(icon: icon, title: title, value: "—", caption: caption,
                    status: "No data yet", statusTint: .secondary) {
            Color.clear
        }
    }
}
