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
    }
}
