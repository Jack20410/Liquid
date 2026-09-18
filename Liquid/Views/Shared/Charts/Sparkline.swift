//
//  Sparkline.swift
//  Liquid
//
//  A tiny line chart with no axes, labels, or legend — just the shape of a trend,
//  with a soft fill beneath and a dot on the latest point. Feed it a series of
//  values; the caller supplies the tint.
//

import SwiftUI
import Charts

struct Sparkline: View {
    var values: [Double]
    var tint: Color = .accentColor

    private var points: [(index: Int, value: Double)] {
        values.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.index) { point in
                LineMark(x: .value("Index", point.index), y: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                AreaMark(x: .value("Index", point.index), y: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
            if let last = points.last {
                PointMark(x: .value("Index", last.index), y: .value("Value", last.value))
                    .foregroundStyle(tint)
                    .symbolSize(60)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

#Preview {
    Sparkline(values: [2, 5, 4, 8, 7, 12, 15], tint: .seafoam)
        .frame(width: 140, height: 56)
        .padding()
}
