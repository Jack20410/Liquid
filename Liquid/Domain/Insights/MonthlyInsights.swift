//
//  MonthlyInsights.swift
//  Liquid
//
//  The four glanceable dashboard tiles — Trend, Top Spending, Planned, Saving Rate
//  — computed for a given month. Like InsightsEngine this is pure and
//  deterministic: it reuses BudgetMath, takes an explicit `asOf`/`calendar` so it
//  is unit-testable, and holds no presentation (colors are assigned by the view).
//  Every field is optional so a tile can show a graceful empty state when there is
//  nothing to measure yet.
//
//  Note: the "Planned" tile is sourced from bill envelopes (`kind == .bill`), the
//  closest thing the model has to recurring/scheduled spend — there is no
//  scheduled-transaction model yet.
//

import Foundation

struct MonthlyInsights {

    /// Month-to-date spending vs the same number of days into the previous month,
    /// plus a running cumulative-spend series for the sparkline.
    struct SpendingTrend: Equatable {
        let percent: Int        // signed whole percent: +up, −down
        let series: [Double]    // cumulative spend, one point per elapsed day
        let current: Decimal    // spent so far this month
        let previous: Decimal   // spent by the same day last month
        var isUp: Bool { percent > 0 }
    }

    /// The biggest spending category this month, with slices for a mini donut.
    struct TopSpending: Equatable {
        let category: String
        let amount: Decimal
        let share: Int          // whole percent of the month's spend
        let slices: [Slice]
        /// Spend beyond the named slices, so the donut still adds up to the
        /// month's real total. Zero when every category has its own slice.
        let other: Decimal
        /// How many categories the month's spending is spread across.
        let categoryCount: Int

        struct Slice: Identifiable, Equatable {
            let id: String
            let name: String
            let amount: Decimal
        }
    }

    /// Money set aside for bill envelopes — the closest proxy for "planned" spend.
    struct Planned: Equatable {
        let total: Decimal
        let items: [Item]       // one per funded bill envelope, richest first

        struct Item: Identifiable, Equatable {
            let id: String
            let name: String
            let amount: Decimal
        }
    }

    /// Share of this month's income kept, with a one-word rating.
    struct SavingRate: Equatable {
        let rate: Double        // raw (may be negative)
        let rating: SavingsRating
        let income: Decimal     // money in, month to date
        let kept: Decimal       // income − spending (may be negative)
    }

    let trend: SpendingTrend?
    let topSpending: TopSpending?
    let planned: Planned?
    let savingRate: SavingRate?

    /// Compute all four tiles for the month containing `asOf`, measured up to that
    /// day. Flow metrics (trend, top spending, saving rate) are month-to-date;
    /// Planned reflects the current balance of bill envelopes.
    static func compute(transactions: [Transaction], envelopes: [Envelope],
                        asOf: Date = .now, calendar: Calendar = .current) -> MonthlyInsights {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: asOf)) ?? asOf
        let dayOfMonth = calendar.component(.day, from: asOf)
        // Month-to-date ends at the start of the day after `asOf`, so the whole
        // selected day is included.
        let mtdEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: asOf)) ?? asOf

        func expenseTotal(from: Date, to: Date) -> Decimal {
            transactions
                .filter { $0.type == .expense && $0.date >= from && $0.date < to }
                .reduce(Decimal(0)) { $0 + $1.amount }
        }
        let monthTotal = expenseTotal(from: monthStart, to: mtdEnd)

        let trend = computeTrend(transactions, monthStart: monthStart, mtdEnd: mtdEnd,
                                 dayOfMonth: dayOfMonth, monthTotal: monthTotal, calendar: calendar)
        let top = computeTopSpending(transactions, monthStart: monthStart, mtdEnd: mtdEnd,
                                     monthTotal: monthTotal)
        let bills = computePlanned(envelopes)
        let saving = computeSavingRate(transactions, monthStart: monthStart, mtdEnd: mtdEnd)

        return MonthlyInsights(trend: trend, topSpending: top, planned: bills, savingRate: saving)
    }

    // MARK: - Trend

    private static func computeTrend(_ transactions: [Transaction], monthStart: Date, mtdEnd: Date,
                                     dayOfMonth: Int, monthTotal: Decimal,
                                     calendar: Calendar) -> SpendingTrend? {
        guard monthTotal > 0,
              let lastStart = calendar.date(byAdding: .month, value: -1, to: monthStart),
              let lastCutoff = calendar.date(byAdding: .day, value: dayOfMonth, to: lastStart)
        else { return nil }

        let lastSamePoint = transactions
            .filter { $0.type == .expense && $0.date >= lastStart && $0.date < lastCutoff }
            .reduce(Decimal(0)) { $0 + $1.amount }
        guard lastSamePoint > 0 else { return nil }

        let change = ((monthTotal - lastSamePoint) / lastSamePoint).asDouble
        let percent = Int((change * 100).rounded())

        // Cumulative spend per elapsed day, for the sparkline shape.
        var perDay = [Decimal](repeating: 0, count: max(dayOfMonth, 1))
        for tx in transactions where tx.type == .expense && tx.date >= monthStart && tx.date < mtdEnd {
            let day = calendar.component(.day, from: tx.date)
            let index = min(max(day - 1, 0), perDay.count - 1)
            perDay[index] += tx.amount
        }
        var running: Decimal = 0
        let series = perDay.map { running += $0; return running.asDouble }

        return SpendingTrend(percent: percent, series: series,
                             current: monthTotal, previous: lastSamePoint)
    }

    // MARK: - Top spending

    private static func computeTopSpending(_ transactions: [Transaction], monthStart: Date, mtdEnd: Date,
                                           monthTotal: Decimal) -> TopSpending? {
        guard monthTotal > 0 else { return nil }
        var totals: [Envelope: Decimal] = [:]
        for tx in transactions where tx.type == .expense && tx.date >= monthStart && tx.date < mtdEnd {
            guard let env = tx.envelope else { continue }
            totals[env, default: 0] += tx.amount
        }
        let ranked = totals.sorted { $0.value > $1.value }
        guard let first = ranked.first else { return nil }

        let named = ranked.prefix(6)
        let slices = named.map {
            TopSpending.Slice(id: $0.key.id.uuidString, name: $0.key.name, amount: $0.value)
        }
        // Everything past the sixth category, kept as one remainder so the donut
        // still represents the whole month rather than silently dropping spend.
        let other = ranked.dropFirst(named.count).reduce(Decimal(0)) { $0 + $1.value }
        let share = Int(((first.value / monthTotal).asDouble * 100).rounded())
        return TopSpending(category: first.key.name, amount: first.value, share: share,
                           slices: Array(slices), other: other, categoryCount: ranked.count)
    }

    // MARK: - Planned (bill envelopes)

    private static func computePlanned(_ envelopes: [Envelope]) -> Planned? {
        let items = envelopes
            .filter { $0.kind == .bill }
            .map { Planned.Item(id: $0.id.uuidString, name: $0.name, amount: BudgetMath.envelopeBalance($0)) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
        guard !items.isEmpty else { return nil }
        return Planned(total: items.reduce(Decimal(0)) { $0 + $1.amount }, items: items)
    }

    // MARK: - Saving rate

    private static func computeSavingRate(_ transactions: [Transaction], monthStart: Date, mtdEnd: Date) -> SavingRate? {
        let interval = DateInterval(start: monthStart, end: mtdEnd)
        guard let rate = BudgetMath.savingsRate(transactions, in: interval) else { return nil }
        let (income, spending) = BudgetMath.incomeAndSpending(transactions, in: interval)
        return SavingRate(rate: rate, rating: SavingsRating(rate: rate),
                          income: income, kept: income - spending)
    }
}

/// A one-word quality rating for a savings rate. Presentation-free (the tint lives
/// in the view); the thresholds are the product judgment of what "good" looks like.
enum SavingsRating: Equatable {
    case excellent  // kept ≥ 20%
    case good       // kept ≥ 10%
    case fair       // kept ≥ 0%
    case low        // spent more than earned

    init(rate: Double) {
        switch rate {
        case 0.2...: self = .excellent
        case 0.1..<0.2: self = .good
        case 0..<0.1: self = .fair
        default: self = .low
        }
    }

    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .low: "Overspent"
        }
    }
}
