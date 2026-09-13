//
//  InsightTile.swift
//  Liquid
//
//  One compact insight tile for the dashboard grid: a small icon+title header, a
//  big value, a mini chart that carries the meaning, and a one-word status. The
//  chart does the talking — the words are deliberately minimal. Generic over its
//  chart content so each tile drops in a Sparkline, MiniDonut, MiniBars, or ring.
//

import SwiftUI

struct InsightTile<Chart: View>: View {
    let icon: String
    let title: String
    let value: String
    var status: String?
    var statusTint: Color = .secondary
    /// When set, the status line leads with an up/down arrow instead of a dot.
    var trendUp: Bool?
    @ViewBuilder var chart: () -> Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            chart()
                .frame(height: 52)

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
        .accessibilityLabel("\(title): \(value)\(status.map { ", \($0)" } ?? "")")
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        InsightTile(icon: "chart.line.uptrend.xyaxis", title: "Trend", value: "+20%",
                    status: "Increasing", statusTint: .decrease, trendUp: true) {
            Sparkline(values: [2, 4, 3, 6, 8, 12], tint: .decrease)
        }
        InsightTile(icon: "chart.pie", title: "Top Spending", value: "$1,000",
                    status: "Savings", statusTint: .seafoam) {
            MiniDonut(slices: [
                DonutSlice(id: "a", amount: 6, color: .seafoam),
                DonutSlice(id: "b", amount: 3, color: .deepTeal),
            ])
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
