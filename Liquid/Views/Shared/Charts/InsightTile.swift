//
//  InsightTile.swift
//  Liquid
//
//  One compact insight tile for the dashboard grid: a small icon+title header, a
//  big value, a caption saying what that value is *of*, a mini chart, and a short
//  status. A bare number ("+13%") reads as trivia, so the caption carries the
//  comparison that makes it mean something; it reserves its two lines even when
//  empty, which keeps tiles in a grid row the same height. Generic over its chart
//  content so each tile drops in a Sparkline, MiniDonut, MiniBars, or ring.
//

import SwiftUI

struct InsightTile<Chart: View>: View {
    let icon: String
    let title: String
    let value: String
    /// What the value is measured against — the sentence around the number.
    var caption: String?
    var status: String?
    var statusTint: Color = .secondary
    /// When set, the status line leads with an up/down arrow instead of a dot.
    var trendUp: Bool?
    @ViewBuilder var chart: () -> Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(caption ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)

            chart()
                .frame(height: 52)
                .padding(.top, 2)

            if let status {
                HStack(spacing: 3) {
                    if let trendUp {
                        Image(systemName: trendUp ? "arrow.up" : "arrow.down")
                            .font(.caption2.weight(.bold))
                    } else {
                        Circle().fill(statusTint).frame(width: 7, height: 7)
                    }
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(statusTint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title + ": " + value, caption, status]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", "))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        InsightTile(icon: "chart.line.uptrend.xyaxis", title: "Spending Trend", value: "+20%",
                    caption: "$1,200 vs $1,000 last month",
                    status: "Spending is up", statusTint: .decrease, trendUp: true) {
            Sparkline(values: [2, 4, 3, 6, 8, 12], tint: .decrease)
        }
        InsightTile(icon: "chart.pie", title: "Top Spending", value: "$1,000",
                    caption: "Groceries — 40% of this month",
                    status: "Across 5 categories", statusTint: .seafoam) {
            MiniDonut(slices: [
                DonutSlice(id: "a", amount: 6, color: .seafoam),
                DonutSlice(id: "b", amount: 3, color: .deepTeal),
            ])
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
