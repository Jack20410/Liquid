//
//  NetWorthTrendCard.swift
//  Liquid
//
//  Net worth over time: a hero value with a range selector and a scrubable
//  Swift Charts area trend.
//

import SwiftUI
import Charts

struct NetWorthTrendCard: View {
    let transactions: [Transaction]

    @State private var rangeDays: Int = 30
    @State private var selectedDate: Date?

    private let ranges: [(label: String, days: Int)] = [("W", 7), ("M", 30), ("3M", 90), ("Y", 365)]

    private var series: [BudgetMath.NetWorthPoint] {
        BudgetMath.netWorthSeries(transactions, days: rangeDays)
    }

    private var current: Decimal { series.last?.value ?? 0 }
    private var change: Decimal { current - (series.first?.value ?? 0) }

    private var selectedPoint: BudgetMath.NetWorthPoint? {
        guard let selectedDate else { return nil }
        let day = Calendar.current.startOfDay(for: selectedDate)
        return series.min { abs($0.date.timeIntervalSince(day)) < abs($1.date.timeIntervalSince(day)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(current.asCurrency)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                changeLabel
            }

            Picker("Range", selection: $rangeDays) {
                ForEach(ranges, id: \.days) { Text($0.label).tag($0.days) }
            }
            .pickerStyle(.segmented)

            chart
                .frame(height: 150)
        }
        .dashboardCard()
        .onChange(of: rangeDays) { selectedDate = nil }
    }

    private var changeLabel: some View {
        let up = change >= 0
        let word = ["7": "week", "30": "month", "90": "quarter", "365": "year"]["\(rangeDays)"] ?? "period"
        return Label {
            Text("\(up ? "+" : "−")\(abs(change).asCurrency) this \(word)")
        } icon: {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
        }
        .font(.caption)
        .foregroundStyle(up ? Color.increase : Color.decrease)
    }

    @ViewBuilder
    private var chart: some View {
        Chart(series) { point in
            AreaMark(x: .value("Day", point.date),
                     y: .value("Net worth", point.value.asDouble))
            .foregroundStyle(Color.accentColor.opacity(0.15))
            .interpolationMethod(.monotone)

            LineMark(x: .value("Day", point.date),
                     y: .value("Net worth", point.value.asDouble))
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.monotone)

            if let selectedPoint {
                RuleMark(x: .value("Selected", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(selectedPoint.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(selectedPoint.value.asCurrency)
                                .font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        .padding(6)
                        .background(.background.secondary, in: .rect(cornerRadius: 6))
                    }
                PointMark(x: .value("Selected", selectedPoint.date),
                          y: .value("Net worth", selectedPoint.value.asDouble))
                .foregroundStyle(Color.accentColor)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartXSelection(value: $selectedDate)
    }
}
