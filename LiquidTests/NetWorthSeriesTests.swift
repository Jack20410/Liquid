//
//  NetWorthSeriesTests.swift
//  LiquidTests
//
//  Tests for the running net-worth-over-time series used by the dashboard trend.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct NetWorthSeriesTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func series_accumulatesIncomeAndExpenseAndEndsAtNetWorth() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let env = Envelope(name: "Fun")
        context.insert(checking); context.insert(card); context.insert(env)

        let asOf = date(2026, 8, 10)
        context.insert(Transaction(date: date(2026, 8, 2), amount: 1000, type: .income, account: checking))
        context.insert(Transaction(date: date(2026, 8, 5), amount: 200, type: .expense, account: checking, envelope: env))
        context.insert(Transaction(date: date(2026, 8, 8), amount: 300, type: .expense, account: card, envelope: env))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        let series = BudgetMath.netWorthSeries(all, days: 14, calendar: calendar, asOf: asOf)

        #expect(series.count == 14)
        // Ends at current net worth: 1000 − 200 − 300 = 500.
        #expect(series.last?.value == 500)
        #expect(series.last?.value == BudgetMath.totalAccountsBalance([checking, card]))
        // Rises to 1000 by Aug 2, dips to 800 after Aug 5.
        #expect(series.first { calendar.isDate($0.date, inSameDayAs: date(2026, 8, 2)) }?.value == 1000)
        #expect(series.first { calendar.isDate($0.date, inSameDayAs: date(2026, 8, 6)) }?.value == 800)
    }

    @Test func series_includesOpeningBalanceBeforeWindow() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        context.insert(checking)
        // Income well before the window forms the opening balance.
        context.insert(Transaction(date: date(2026, 6, 1), amount: 5000, type: .income, account: checking))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        let series = BudgetMath.netWorthSeries(all, days: 7, calendar: calendar, asOf: date(2026, 8, 10))
        // Every day in the window already reflects the 5000 opening balance.
        #expect(series.first?.value == 5000)
        #expect(series.last?.value == 5000)
    }

    @Test func series_allocationsAndTransfersDoNotChangeNetWorth() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let env = Envelope(name: "Rent")
        context.insert(checking); context.insert(card); context.insert(env)

        context.insert(Transaction(date: date(2026, 8, 2), amount: 1000, type: .income, account: checking))
        context.insert(Transaction(date: date(2026, 8, 3), amount: 400, type: .allocation, account: checking, envelope: env))
        context.insert(Transaction(date: date(2026, 8, 4), amount: 250, type: .transfer, account: checking, toAccount: card))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        let series = BudgetMath.netWorthSeries(all, days: 14, calendar: calendar, asOf: date(2026, 8, 10))
        // Only the income moved net worth; allocation and transfer are net-zero.
        #expect(series.last?.value == 1000)
    }
}
