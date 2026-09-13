//
//  BudgetBar.swift
//  Liquid
//
//  A horizontal capsule progress bar — a track plus a colored fill scaled to a
//  0...1 fraction. Used for spend-vs-budget on envelope rows and the ranked
//  category bars on the dashboard, so both draw the same bar instead of
//  re-implementing the capsules inline.
//

import SwiftUI

struct BudgetBar: View {
    /// Fill fraction, clamped to 0...1.
    var fraction: Double
    var color: Color = .accentColor
    var height: CGFloat = 10

    private var clamped: Double { min(1, max(0, fraction)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * clamped))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 12) {
        BudgetBar(fraction: 0.3, color: .deepTeal)
        BudgetBar(fraction: 0.75, color: .aqua)
        BudgetBar(fraction: 1.1, color: .decrease)
    }
    .padding()
}
