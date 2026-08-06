//
//  BudgetMathDailyTests.swift
//  LiquidTests
//
//  Tests for the per-day cash-flow summary used by the spending calendar.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct BudgetMathDailyTests {

    /// A fixed, time-zone-stable calendar so day bucketing is deterministic.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Account.self, Envelope.self, Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test func groupsByDay_andSumsIncomeAndSpending() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Groceries")
        context.insert(account)
        context.insert(envelope)

        // Two expenses + one income on the same day, at different times.
        context.insert(Transaction(date: date(2026, 8, 5, hour: 9), amount: 20,
                                   type: .expense, account: account, envelope: envelope))
        context.insert(Transaction(date: date(2026, 8, 5, hour: 18), amount: 30,
                                   type: .expense, account: account, envelope: envelope))
        context.insert(Transaction(date: date(2026, 8, 5, hour: 8), amount: 2000,
                                   type: .income, account: account))
        // A different day.
        context.insert(Transaction(date: date(2026, 8, 6), amount: 15,
                                   type: .expense, account: account, envelope: envelope))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        let summaries = BudgetMath.dailySummaries(all, calendar: calendar)

        let aug5 = calendar.startOfDay(for: date(2026, 8, 5))
        let aug6 = calendar.startOfDay(for: date(2026, 8, 6))

        #expect(summaries.count == 2)
        #expect(summaries[aug5]?.income == 2000)
        #expect(summaries[aug5]?.spending == 50)   // 20 + 30, unsigned
        #expect(summaries[aug5]?.net == 1950)      // 2000 − 50
        #expect(summaries[aug6]?.spending == 15)
        #expect(summaries[aug6]?.income == 0)
        #expect(summaries[aug6]?.net == -15)
    }

    @Test func excludesAllocations() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Rent")
        context.insert(account)
        context.insert(envelope)

        context.insert(Transaction(date: date(2026, 8, 5), amount: 2000,
                                   type: .income, account: account))
        context.insert(Transaction(date: date(2026, 8, 5), amount: 800,
                                   type: .allocation, account: account, envelope: envelope))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        let summaries = BudgetMath.dailySummaries(all, calendar: calendar)
        let aug5 = calendar.startOfDay(for: date(2026, 8, 5))

        // The allocation must not appear as income or spending.
        #expect(summaries[aug5]?.income == 2000)
        #expect(summaries[aug5]?.spending == 0)
        #expect(summaries[aug5]?.net == 2000)
    }

    @Test func emptyWhenNoCashFlow() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Rent")
        context.insert(account)
        context.insert(envelope)
        // Only an allocation exists — no real cash flow.
        context.insert(Transaction(date: date(2026, 8, 5), amount: 800,
                                   type: .allocation, account: account, envelope: envelope))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        #expect(BudgetMath.dailySummaries(all, calendar: calendar).isEmpty)
    }
}
