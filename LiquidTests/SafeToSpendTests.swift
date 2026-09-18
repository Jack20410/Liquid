//
//  SafeToSpendTests.swift
//  LiquidTests
//
//  Tests for BudgetMath.safeToSpend — the combined balance of day-to-day
//  "spending" envelopes, excluding bills and savings goals.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct SafeToSpendTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func sumsOnlySpendingEnvelopes() throws {
        let context = try makeContext()
        let groceries = Envelope(name: "Groceries", kind: .spending)
        let fun = Envelope(name: "Fun", kind: .spending)
        let rent = Envelope(name: "Rent", kind: .bill)
        let savings = Envelope(name: "Savings", kind: .goal)
        for e in [groceries, fun, rent, savings] { context.insert(e) }

        context.insert(Transaction(amount: 400, type: .allocation, envelope: groceries))
        context.insert(Transaction(amount: 100, type: .expense, envelope: groceries))   // → 300
        context.insert(Transaction(amount: 200, type: .allocation, envelope: fun))
        context.insert(Transaction(amount: 50, type: .expense, envelope: fun))           // → 150
        context.insert(Transaction(amount: 800, type: .allocation, envelope: rent))       // excluded (bill)
        context.insert(Transaction(amount: 500, type: .allocation, envelope: savings))    // excluded (goal)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Envelope>())
        #expect(BudgetMath.safeToSpend(all) == 450)   // 300 + 150
    }

    @Test func overspentSpendingEnvelopeLowersTheNumber() throws {
        let context = try makeContext()
        let a = Envelope(name: "A", kind: .spending)
        let b = Envelope(name: "B", kind: .spending)
        context.insert(a); context.insert(b)
        context.insert(Transaction(amount: 100, type: .allocation, envelope: a))
        context.insert(Transaction(amount: 130, type: .expense, envelope: a))   // → -30
        context.insert(Transaction(amount: 200, type: .allocation, envelope: b)) // → 200
        try context.save()

        let all = try context.fetch(FetchDescriptor<Envelope>())
        #expect(BudgetMath.safeToSpend(all) == 170)   // 200 − 30
    }

    @Test func zeroWhenNoSpendingEnvelopes() throws {
        let context = try makeContext()
        let rent = Envelope(name: "Rent", kind: .bill)
        let savings = Envelope(name: "Savings", kind: .goal)
        context.insert(rent); context.insert(savings)
        context.insert(Transaction(amount: 800, type: .allocation, envelope: rent))
        context.insert(Transaction(amount: 500, type: .allocation, envelope: savings))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Envelope>())
        #expect(BudgetMath.safeToSpend(all) == 0)
    }

    @Test func emptyIsZero() throws {
        #expect(BudgetMath.safeToSpend([]) == 0)
    }

    @Test func defaultKindIsSpending() {
        // A plain envelope with no kind specified counts toward safe to spend.
        #expect(Envelope(name: "Misc").kind == .spending)
        #expect(EnvelopeKind.spending.isSafeToSpend)
        #expect(!EnvelopeKind.bill.isSafeToSpend)
        #expect(!EnvelopeKind.goal.isSafeToSpend)
    }
}
