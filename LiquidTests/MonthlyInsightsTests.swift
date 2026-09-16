//
//  MonthlyInsightsTests.swift
//  LiquidTests
//
//  Tests for BudgetMath.savingsRate and the MonthlyInsights tile aggregator that
//  powers the visual dashboard. Both take an explicit `asOf`/calendar, so every
//  case is deterministic.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct MonthlyInsightsTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// The 15th of March 2026 — mid-month.
    private var asOf: Date { date(2026, 3, 15) }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func compute(_ context: ModelContext) throws -> MonthlyInsights {
        try context.save()
        return MonthlyInsights.compute(
            transactions: try context.fetch(FetchDescriptor<Transaction>()),
            envelopes: try context.fetch(FetchDescriptor<Envelope>()),
            asOf: asOf, calendar: calendar)
    }

    // MARK: savingsRate

    @Test func savingsRate_nilWithoutIncome() {
        let march = DateInterval(start: date(2026, 3, 1), end: date(2026, 3, 31))
        #expect(BudgetMath.savingsRate([], in: march) == nil)
    }

    @Test func savingsRate_keptShareOfIncome() {
        let march = DateInterval(start: date(2026, 3, 1), end: date(2026, 3, 31))
        let txs = [
            Transaction(date: date(2026, 3, 1), amount: 1000, type: .income),
            Transaction(date: date(2026, 3, 5), amount: 250, type: .expense),
            // Allocations/transfers never count toward the rate.
            Transaction(date: date(2026, 3, 6), amount: 400, type: .allocation),
        ]
        let rate = try? #require(BudgetMath.savingsRate(txs, in: march))
        #expect(abs((rate ?? 0) - 0.75) < 0.0001)   // (1000 − 250) / 1000
    }

    @Test func savingsRate_negativeWhenOverspent() {
        let march = DateInterval(start: date(2026, 3, 1), end: date(2026, 3, 31))
        let txs = [
            Transaction(date: date(2026, 3, 1), amount: 100, type: .income),
            Transaction(date: date(2026, 3, 5), amount: 150, type: .expense),
        ]
        let rate = BudgetMath.savingsRate(txs, in: march) ?? 0
        #expect(rate < 0)
        #expect(SavingsRating(rate: rate) == .low)
    }

    @Test func savingsRating_buckets() {
        #expect(SavingsRating(rate: 0.30) == .excellent)
        #expect(SavingsRating(rate: 0.15) == .good)
        #expect(SavingsRating(rate: 0.05) == .fair)
        #expect(SavingsRating(rate: -0.10) == .low)
    }

    // MARK: MonthlyInsights.compute

    @Test func emptyWhenNoData() throws {
        let insights = try compute(try makeContext())
        #expect(insights.trend == nil)
        #expect(insights.topSpending == nil)
        #expect(insights.planned == nil)
        #expect(insights.savingRate == nil)
    }

    @Test func trend_comparesSamePointLastMonth_withCumulativeSeries() throws {
        let context = try makeContext()
        let env = Envelope(name: "Groceries", kind: .spending)
        context.insert(env)
        // Feb 1–15: 100 spent. March 1–15: 150 → up 50%.
        context.insert(Transaction(date: date(2026, 2, 10), amount: 100, type: .expense, envelope: env))
        context.insert(Transaction(date: date(2026, 3, 5), amount: 50, type: .expense, envelope: env))
        context.insert(Transaction(date: date(2026, 3, 12), amount: 100, type: .expense, envelope: env))

        let trend = try #require(try compute(context).trend)
        #expect(trend.percent == 50)
        #expect(trend.isUp)
        // The two figures the tile's caption compares.
        #expect(trend.current == 150)
        #expect(trend.previous == 100)
        // Cumulative series is monotonic and ends at the month-to-date total.
        #expect(trend.series.last == 150)
        #expect(trend.series == trend.series.sorted())
    }

    @Test func topSpending_isLargestCategory_withShareAndSlices() throws {
        let context = try makeContext()
        let groceries = Envelope(name: "Groceries", kind: .spending)
        let fun = Envelope(name: "Fun", kind: .spending)
        context.insert(groceries); context.insert(fun)
        context.insert(Transaction(date: date(2026, 3, 3), amount: 300, type: .expense, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 4), amount: 100, type: .expense, envelope: fun))

        let top = try #require(try compute(context).topSpending)
        #expect(top.category == "Groceries")
        #expect(top.amount == 300)
        #expect(top.share == 75)              // 300 / 400
        #expect(top.slices.count == 2)
        #expect(top.slices.first?.name == "Groceries")
        #expect(top.categoryCount == 2)
        #expect(top.other == 0)               // every category got its own slice
    }

    @Test func topSpending_foldsCategoriesBeyondTheSixthIntoOther() throws {
        let context = try makeContext()
        // Eight categories spending 80, 70, 60, 50, 40, 30, 20, 10 → the last two
        // (30 total) fall outside the six named slices.
        for (index, amount) in [80, 70, 60, 50, 40, 30, 20, 10].enumerated() {
            let env = Envelope(name: "Cat \(index)", kind: .spending)
            context.insert(env)
            context.insert(Transaction(date: date(2026, 3, 4), amount: Decimal(amount),
                                       type: .expense, envelope: env))
        }

        let top = try #require(try compute(context).topSpending)
        #expect(top.slices.count == 6)
        #expect(top.categoryCount == 8)
        #expect(top.other == 30)              // 20 + 10
        // The donut still represents the whole month.
        #expect(top.slices.reduce(Decimal(0)) { $0 + $1.amount } + top.other == 360)
    }

    @Test func planned_sumsBillEnvelopeBalances() throws {
        let context = try makeContext()
        let rent = Envelope(name: "Rent", kind: .bill)
        let power = Envelope(name: "Power", kind: .bill)
        let fun = Envelope(name: "Fun", kind: .spending)   // not a bill → excluded
        context.insert(rent); context.insert(power); context.insert(fun)
        context.insert(Transaction(date: date(2026, 3, 1), amount: 1200, type: .allocation, envelope: rent))
        context.insert(Transaction(date: date(2026, 3, 1), amount: 80, type: .allocation, envelope: power))
        context.insert(Transaction(date: date(2026, 3, 1), amount: 500, type: .allocation, envelope: fun))

        let planned = try #require(try compute(context).planned)
        #expect(planned.total == 1280)
        #expect(planned.items.count == 2)
        #expect(planned.items.first?.name == "Rent")   // richest first
    }

    @Test func savingRate_isMonthToDate() throws {
        let context = try makeContext()
        context.insert(Transaction(date: date(2026, 3, 1), amount: 2000, type: .income))
        context.insert(Transaction(date: date(2026, 3, 8), amount: 500, type: .expense))
        // April income must not leak into March.
        context.insert(Transaction(date: date(2026, 4, 1), amount: 9999, type: .income))

        let rate = try #require(try compute(context).savingRate)
        #expect(abs(rate.rate - 0.75) < 0.0001)
        #expect(rate.rating == .excellent)
        // The amounts the tile's caption spells out, April income excluded.
        #expect(rate.income == 2000)
        #expect(rate.kept == 1500)
    }

    @Test func incomeAndSpending_ignoresAllocationsAndTransfers() {
        let march = DateInterval(start: date(2026, 3, 1), end: date(2026, 3, 31))
        let txs = [
            Transaction(date: date(2026, 3, 1), amount: 900, type: .income),
            Transaction(date: date(2026, 3, 5), amount: 200, type: .expense),
            Transaction(date: date(2026, 3, 6), amount: 400, type: .allocation),
            Transaction(date: date(2026, 3, 7), amount: 300, type: .transfer),
            Transaction(date: date(2026, 2, 20), amount: 500, type: .income),   // out of range
        ]
        let totals = BudgetMath.incomeAndSpending(txs, in: march)
        #expect(totals.income == 900)
        #expect(totals.spending == 200)
    }
}
