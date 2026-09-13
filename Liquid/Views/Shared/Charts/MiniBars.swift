//
//  MiniBars.swift
//  Liquid
//
//  A tiny row of vertical bars scaled to the largest value — the compact bar
//  equivalent of a sparkline, used by the Planned insight tile. No axes or labels;
//  the caller supplies the tint.
//

import SwiftUI

struct MiniBars: View {
    var values: [Double]
    var tint: Color = .accentColor
    var spacing: CGFloat = 4

    /// Widest a single bar may get, so a tile with only a couple of values shows
    /// slim bars rather than fat blobs. With many values the bars shrink to fit.
    var maxBarWidth: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let maxValue = values.max() ?? 0
            let count = max(values.count, 1)
            let fitted = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let barWidth = max(4, min(maxBarWidth, fitted))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        .frame(width: barWidth,
                               height: barHeight(value, maxValue: maxValue, in: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func barHeight(_ value: Double, maxValue: Double, in height: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 3 }
        return max(3, height * CGFloat(value / maxValue))
    }
}

#Preview {
    MiniBars(values: [40, 75, 20, 60], tint: .deepTeal)
        .frame(width: 120, height: 56)
        .padding()
}
