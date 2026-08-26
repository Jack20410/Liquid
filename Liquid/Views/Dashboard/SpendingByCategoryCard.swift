//
//  SpendingByCategoryCard.swift
//  Liquid
//
//  Spending grouped by envelope over the last 30 days, shown as a ranked bar list
//  or a donut — the user's choice (also settable from Dashboard settings). Rows
//  navigate to that envelope's detail.
//

import SwiftUI
import Charts

struct SpendingByCategoryCard: View {
    let transactions: [Transaction]

    @AppStorage(ChartStyleKey.category) private var style: CategoryChartStyle = .bars

    /// A category = one envelope's expense total (plus an aggregated "Other").
    private struct Item: Identifiable {
        let id: String
        let name: String
        let amount: Decimal
        let color: Color
        let envelope: Envelope?   // nil for the "Other" bucket
    }

    private static let palette: [Color] = Color.categoryPalette
    private static let windowDays = 30
    private static let topN = 5

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -(Self.windowDays - 1),
                              to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private var items: [Item] {
        var totals: [Envelope: Decimal] = [:]
        for tx in transactions where tx.type == .expense && tx.date >= windowStart {
            guard let env = tx.envelope else { continue }
            totals[env, default: 0] += tx.amount
        }
        let ranked = totals.sorted { $0.value > $1.value }
        var result: [Item] = ranked.prefix(Self.topN).enumerated().map { i, pair in
            Item(id: pair.key.id.uuidString, name: pair.key.name, amount: pair.value,
                 color: Self.palette[i % Self.palette.count], envelope: pair.key)
        }
        let otherTotal = ranked.dropFirst(Self.topN).reduce(Decimal(0)) { $0 + $1.value }
        if otherTotal > 0 {
            result.append(Item(id: "other", name: "Other", amount: otherTotal,
                               color: .gray, envelope: nil))
        }
        return result
    }

    private var total: Decimal { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending · 30 Days")
                    .font(.headline)
                Spacer()
                styleMenu
            }
            Text("Where it went")
                .font(.caption).foregroundStyle(.secondary)

            if items.isEmpty {
                Text("No spending in the last 30 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else if style == .bars {
                barsView
            } else {
                donutView
            }
        }
        .dashboardCard()
    }

    private var styleMenu: some View {
        Menu {
            Picker("Chart style", selection: $style) {
                ForEach(CategoryChartStyle.allCases) { s in
                    Label(s.displayName, systemImage: s.icon).tag(s)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
        }
        .accessibilityLabel("Change chart style")
    }

    // MARK: Bars

    private var barsView: some View {
        let maxAmount = items.map(\.amount).max() ?? 1
        return VStack(spacing: 8) {
            ForEach(items) { item in
                categoryLink(item) {
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule().fill(item.color)
                                    .frame(width: max(6, geo.size.width * fraction(item.amount, maxAmount)))
                            }
                        }
                        .frame(height: 14)
                        Text(item.amount.asCurrency)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 68, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Donut

    private var donutView: some View {
        VStack(spacing: 12) {
            ZStack {
                Chart(items) { item in
                    SectorMark(angle: .value("Spent", item.amount.asDouble),
                               innerRadius: .ratio(0.62),
                               angularInset: 1.5)
                    .cornerRadius(4)
                    .foregroundStyle(item.color)
                }
                .frame(height: 170)

                VStack(spacing: 1) {
                    Text("total").font(.caption2).foregroundStyle(.secondary)
                    Text(total.asCurrency).font(.callout.weight(.semibold)).monospacedDigit()
                }
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    categoryLink(item) {
                        HStack(spacing: 8) {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            Text(item.name).font(.subheadline)
                            Spacer()
                            Text("\(percent(item.amount))%")
                                .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                            Text(item.amount.asCurrency)
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                .frame(width: 68, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    /// Wrap a row in a navigation link to its envelope; "Other" stays static.
    @ViewBuilder
    private func categoryLink<Content: View>(_ item: Item, @ViewBuilder content: () -> Content) -> some View {
        if let envelope = item.envelope {
            NavigationLink {
                EnvelopeDetailView(envelope: envelope)
            } label: {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func fraction(_ amount: Decimal, _ maxAmount: Decimal) -> Double {
        guard maxAmount > 0 else { return 0 }
        return min(1, max(0, (amount / maxAmount).asDouble))
    }

    private func percent(_ amount: Decimal) -> Int {
        guard total > 0 else { return 0 }
        return Int(((amount / total).asDouble * 100).rounded())
    }
}
