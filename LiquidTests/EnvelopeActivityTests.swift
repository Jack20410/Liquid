//
//  EnvelopeActivityTests.swift
//  LiquidTests
//
//  Tests for BudgetMath.envelopeSpend / envelopeAllocated — the per-envelope,
//  per-period aggregates behind the Envelopes screen's spend-vs-budget bars.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct EnvelopeActivityTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private var march: DateInterval {
        DateInterval(start: date(2026, 3, 1), end: date(2026, 4, 1))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func spendAndAllocated_countOnlyMatchingTypesInRange() throws {
        let context = try makeContext()
        let groceries = Envelope(name: "Groceries", kind: .spending)
        context.insert(groceries)
        context.insert(Transaction(date: date(2026, 3, 1), amount: 300, type: .allocation, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 5), amount: 80, type: .expense, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 20), amount: 45, type: .expense, envelope: groceries))
        // Out of range (February) and wrong type — both ignored.
        context.insert(Transaction(date: date(2026, 2, 25), amount: 999, type: .expense, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 10), amount: 500, type: .income, envelope: groceries))
        try context.save()

        #expect(BudgetMath.envelopeSpend(groceries, in: march) == 125)      // 80 + 45
        #expect(BudgetMath.envelopeAllocated(groceries, in: march) == 300)
    }

    @Test func zeroWhenNoActivity() throws {
        let context = try makeContext()
        let fun = Envelope(name: "Fun", kind: .spending)
        context.insert(fun)
        try context.save()
        #expect(BudgetMath.envelopeSpend(fun, in: march) == 0)
        #expect(BudgetMath.envelopeAllocated(fun, in: march) == 0)
    }
}
