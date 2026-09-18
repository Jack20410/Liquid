//
//  MiniDonut.swift
//  Liquid
//
//  The shared donut recipe — a Swift Charts ring (open center) with an optional
//  label in the middle. Extracted so the Envelopes card, the Spending-by-category
//  card, and the Top-Spending insight tile all draw the same donut instead of
//  re-implementing SectorMark three times. Colors are baked into each slice by the
//  caller, from the Liquid palette.
//

import SwiftUI
import Charts

/// One wedge of a `MiniDonut`. `id` keeps slices stable across updates.
struct DonutSlice: Identifiable {
    let id: String
    let amount: Double
    let color: Color
}

struct MiniDonut<Center: View>: View {
    var slices: [DonutSlice]
    var innerRatio: CGFloat = 0.62
    @ViewBuilder var center: () -> Center

    init(slices: [DonutSlice], innerRatio: CGFloat = 0.62,
         @ViewBuilder center: @escaping () -> Center = { EmptyView() }) {
        self.slices = slices
        self.innerRatio = innerRatio
        self.center = center
    }

    var body: some View {
        ZStack {
            Chart(slices) { slice in
                SectorMark(angle: .value("Amount", slice.amount),
                           innerRadius: .ratio(innerRatio),
                           angularInset: 1.5)
                .cornerRadius(4)
                .foregroundStyle(slice.color)
            }
            center()
        }
    }
}

#Preview {
    MiniDonut(slices: [
        DonutSlice(id: "a", amount: 5, color: .deepTeal),
        DonutSlice(id: "b", amount: 3, color: .aqua),
        DonutSlice(id: "c", amount: 2, color: .seafoam),
    ]) {
        Text("$1,000").font(.callout.weight(.semibold))
    }
    .frame(height: 160)
    .padding()
}
