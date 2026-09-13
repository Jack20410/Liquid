//
//  InsightsEngineTests.swift
//  LiquidTests
//
//  Tests for InsightsEngine (grounded facts from real balances) and the
//  InsightsGrounding guardrail that keeps the on-device narrator honest. The
//  engine takes an explicit `asOf` and calendar, so every case is deterministic.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct InsightsEngineTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// The 15th of March 2026 — mid-month, so pacing insights can fire.
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

    private func run(_ context: ModelContext, limit: Int = 4) throws -> [Insight] {
        try context.save()
        return InsightsEngine.insights(
            transactions: try context.fetch(FetchDescriptor<Transaction>()),
            envelopes: try context.fetch(FetchDescriptor<Envelope>()),
            accounts: try context.fetch(FetchDescriptor<Account>()),
            calendar: calendar, asOf: asOf, limit: limit)
    }

    @Test func nothingToSay_whenNoData() throws {
        let context = try makeContext()
        #expect(try run(context).isEmpty)
    }

    @Test func overspentEnvelope_isAWarning_andComesFirst() throws {
        let context = try makeContext()
        let fun = Envelope(name: "Fun", kind: .spending)
        context.insert(fun)
        context.insert(Transaction(date: date(2026, 3, 2), amount: 100, type: .allocation, envelope: fun))
        context.insert(Transaction(date: date(2026, 3, 10), amount: 140, type: .expense, envelope: fun))
        // A positive fact too, so ordering is observable.
        context.insert(Transaction(date: date(2026, 3, 1), amount: 500, type: .income))

        let insights = try run(context)
        #expect(insights.first == .overspent(envelope: "Fun", by: 40))
        #expect(insights.first?.severity == .warning)
    }

    @Test func unbudgetedIncome_isReported() throws {
        let context = try makeContext()
        let rent = Envelope(name: "Rent", kind: .bill)
        context.insert(rent)
        context.insert(Transaction(date: date(2026, 3, 1), amount: 2000, type: .income))
        context.insert(Transaction(date: date(2026, 3, 1), amount: 500, type: .allocation, envelope: rent))

        #expect(try run(context).contains(.unbudgeted(amount: 1500)))
    }

    @Test func safeToSpend_isPositiveWhenFunded_warningWhenOverspent() throws {
        let context = try makeContext()
        let groceries = Envelope(name: "Groceries", kind: .spending)
        context.insert(groceries)
        context.insert(Transaction(date: date(2026, 3, 1), amount: 300, type: .allocation, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 5), amount: 50, type: .expense, envelope: groceries))
        #expect(try run(context).contains(.safeToSpend(amount: 250)))
        #expect(Insight.safeToSpend(amount: 250).severity == .positive)
        #expect(Insight.safeToSpend(amount: -10).severity == .warning)
    }

    @Test func topCategory_isLargestThisMonth_withShare() throws {
        let context = try makeContext()
        let groceries = Envelope(name: "Groceries", kind: .spending)
        let fun = Envelope(name: "Fun", kind: .spending)
        context.insert(groceries); context.insert(fun)
        for env in [groceries, fun] {
            context.insert(Transaction(date: date(2026, 3, 1), amount: 1000, type: .allocation, envelope: env))
        }
        context.insert(Transaction(date: date(2026, 3, 3), amount: 300, type: .expense, envelope: groceries))
        context.insert(Transaction(date: date(2026, 3, 4), amount: 100, type: .expense, envelope: fun))

        #expect(try run(context, limit: 10).contains(.topCategory(envelope: "Groceries", amount: 300, share: 75)))
    }

    @Test func spendingTrend_comparesSamePointLastMonth() throws {
        let context = try makeContext()
        let env = Envelope(name: "Groceries", kind: .spending)
        context.insert(env)
        context.insert(Transaction(date: date(2026, 2, 1), amount: 1000, type: .allocation, envelope: env))
        // First 15 days of February: 100. First 15 days of March: 150 → up 50%.
        context.insert(Transaction(date: date(2026, 2, 10), amount: 100, type: .expense, envelope: env))
        context.insert(Transaction(date: date(2026, 2, 25), amount: 999, type: .expense, envelope: env)) // after the cutoff; ignored
        context.insert(Transaction(date: date(2026, 3, 10), amount: 150, type: .expense, envelope: env))

        #expect(try run(context, limit: 10).contains(.spendingTrend(percent: 50, up: true)))
    }

    @Test func creditUtilization_reportedAt30PercentOrMore() throws {
        let context = try makeContext()
        let card = Account(name: "Sapphire", type: .creditCard, creditLimit: 1000)
        context.insert(card)
        context.insert(Transaction(date: date(2026, 3, 2), amount: 500, type: .expense, account: card))

        let insights = try run(context, limit: 10)
        #expect(insights.contains(.creditUtilization(account: "Sapphire", percent: 50)))
        #expect(Insight.creditUtilization(account: "Sapphire", percent: 50).severity == .neutral)
        #expect(Insight.creditUtilization(account: "Sapphire", percent: 80).severity == .warning)
    }

    @Test func limit_isRespected() throws {
        let context = try makeContext()
        let a = Envelope(name: "A", kind: .spending)
        let b = Envelope(name: "B", kind: .spending)
        context.insert(a); context.insert(b)
        context.insert(Transaction(date: date(2026, 3, 1), amount: 10, type: .allocation, envelope: a))
        context.insert(Transaction(date: date(2026, 3, 2), amount: 50, type: .expense, envelope: a))   // overspent
        context.insert(Transaction(date: date(2026, 3, 1), amount: 10, type: .allocation, envelope: b))
        context.insert(Transaction(date: date(2026, 3, 2), amount: 50, type: .expense, envelope: b))   // overspent
        context.insert(Transaction(date: date(2026, 3, 1), amount: 500, type: .income))

        #expect(try run(context, limit: 2).count == 2)
    }

    // MARK: Grounding guardrail

    @Test func grounding_toleratesDroppedCentsAndGrouping() {
        let facts = ["$2,000.00 of income is still waiting.", "Spending is up 20%."]
        #expect(InsightsGrounding.preservesNumbers(
            in: "You have $2,000 waiting, and spending is up 20% this month.", facts: facts))
    }

    @Test func grounding_rejectsChangedOrMissingNumber() {
        let facts = ["Groceries is overspent by $40.00."]
        #expect(!InsightsGrounding.preservesNumbers(in: "Groceries is overspent by $45.", facts: facts))
        #expect(!InsightsGrounding.preservesNumbers(in: "Groceries is a bit overspent.", facts: facts))
    }

    @Test func grounding_extractsNumericTokens() {
        #expect(InsightsGrounding.numericTokens("$1,234.50 and 20%, then 7.") == ["1,234.50", "20", "7"])
    }

    /// The failure a whole-text number check misses: every number present, but
    /// shuffled between facts into false claims. Per-sentence checking catches it.
    @Test func grounding_rejectsRecombinedFacts_evenWhenAllNumbersPresent() {
        let facts = ["$2,000.00 of income is still waiting to be given a job.",
                     "Savings is 53% of what you spent, at $240.00."]
        let recombined = ["You're on track to spend $2,000.00 this month, 53% of your income.",
                          "$240.00 already went to Savings."]
        // Whole-text check would pass (all four numbers appear somewhere) …
        #expect(InsightsGrounding.preservesNumbers(in: recombined.joined(separator: " "), facts: facts))
        // … but per-sentence grounding sees "53" missing from sentence 2's own fact and rejects.
        #expect(!InsightsGrounding.sentencesPreserveNumbers(recombined, facts: facts))
    }

    @Test func grounding_perSentence_acceptsFaithfulRewrites_rejectsCountMismatch() {
        let facts = ["$2,000.00 of income is still waiting.", "Spending is up 20%."]
        let faithful = ["You still have $2,000 of income waiting for a job.", "Your spending is up 20%."]
        #expect(InsightsGrounding.sentencesPreserveNumbers(faithful, facts: facts))
        #expect(!InsightsGrounding.sentencesPreserveNumbers(["One merged sentence with $2,000 and 20%."], facts: facts))
    }
}
