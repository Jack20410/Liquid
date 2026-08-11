//
//  DistributionHistoryTests.swift
//  LiquidTests
//
//  Tests for reconstructing distribution history and the aggregate "where the
//  money goes" totals from stored allocation transactions.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct DistributionHistoryTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// A store with two distributions (older 900, newer 1000) plus non-allocation
    /// noise (income + expense) that must be ignored.
    private func seedTwoDistributions(_ context: ModelContext) throws -> (older: Date, newer: Date) {
        let checking = Account(name: "Checking", type: .checking)
        let rent = Envelope(name: "Rent")
        let food = Envelope(name: "Food")
        let fun = Envelope(name: "Fun")
        for m in [checking as any PersistentModel, rent, food, fun] { context.insert(m) }

        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)

        // Older distribution: 500 + 400 = 900
        context.insert(Transaction(date: older, amount: 500, type: .allocation, account: checking, envelope: rent))
        context.insert(Transaction(date: older, amount: 400, type: .allocation, account: checking, envelope: food))
        // Newer distribution: 600 + 300 + 100 = 1000
        context.insert(Transaction(date: newer, amount: 600, type: .allocation, account: checking, envelope: rent))
        context.insert(Transaction(date: newer, amount: 300, type: .allocation, account: checking, envelope: food))
        context.insert(Transaction(date: newer, amount: 100, type: .allocation, account: checking, envelope: fun))
        // Noise that is not a distribution.
        context.insert(Transaction(date: newer, amount: 2000, type: .income, account: checking))
        context.insert(Transaction(date: newer, amount: 50, type: .expense, account: checking, envelope: food))
        try context.save()
        return (older, newer)
    }

    @Test func history_groupsByEvent_newestFirst_withTotals() throws {
        let context = try makeContext()
        let (older, newer) = try seedTwoDistributions(context)
        let all = try context.fetch(FetchDescriptor<Transaction>())

        let history = BudgetMath.distributionHistory(transactions: all)

        #expect(history.count == 2)                    // two events, income/expense ignored
        #expect(history[0].date == newer)              // newest first
        #expect(history[1].date == older)
        #expect(history[0].total == 1000)
        #expect(history[1].total == 900)
        #expect(history[0].envelopeCount == 3)
        #expect(history[1].envelopeCount == 2)
        #expect(history[0].accountName == "Checking")
    }

    @Test func history_sharesSortedByAmountDescending() throws {
        let context = try makeContext()
        _ = try seedTwoDistributions(context)
        let all = try context.fetch(FetchDescriptor<Transaction>())

        let newest = BudgetMath.distributionHistory(transactions: all)[0]
        #expect(newest.shares.map(\.amount) == [600, 300, 100])
        #expect(newest.shares.first?.name == "Rent")
    }

    @Test func totalsByEnvelope_sumAcrossDistributions_sortedDescending() throws {
        let context = try makeContext()
        _ = try seedTwoDistributions(context)
        let all = try context.fetch(FetchDescriptor<Transaction>())

        let totals = BudgetMath.distributionTotalsByEnvelope(transactions: all)
        // Rent 500+600=1100, Food 400+300=700, Fun 100.
        #expect(totals.map(\.name) == ["Rent", "Food", "Fun"])
        #expect(totals.map(\.amount) == [1100, 700, 100])
        #expect(totals.reduce(Decimal(0)) { $0 + $1.amount } == 1900)
    }

    @Test func emptyWhenNoAllocations() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        context.insert(checking)
        context.insert(Transaction(amount: 100, type: .income, account: checking))
        try context.save()
        let all = try context.fetch(FetchDescriptor<Transaction>())

        #expect(BudgetMath.distributionHistory(transactions: all).isEmpty)
        #expect(BudgetMath.distributionTotalsByEnvelope(transactions: all).isEmpty)
    }
}
