//
//  BudgetMathTests.swift
//  LiquidTests
//
//  Tests for balance calculations and the sign convention (spec §6.3, §7.4).
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct BudgetMathTests {

    /// A fresh in-memory context so tests never touch the real store.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Account.self, Envelope.self, Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func accountBalance_sumsIncomeMinusExpenses() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        context.insert(account)
        context.insert(Transaction(amount: 2000, type: .income, account: account))
        context.insert(Transaction(amount: 300, type: .expense, account: account))
        try context.save()

        #expect(BudgetMath.accountBalance(account) == 1700)
    }

    @Test func allocationsDoNotChangeAccountBalance() throws {
        // Spec §7.4: applying a distribution must not move account balances.
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Rent")
        context.insert(account)
        context.insert(envelope)
        context.insert(Transaction(amount: 2000, type: .income, account: account))
        context.insert(Transaction(amount: 800, type: .allocation, account: account, envelope: envelope))
        try context.save()

        #expect(BudgetMath.accountBalance(account) == 2000)   // unchanged by allocation
        #expect(BudgetMath.envelopeBalance(envelope) == 800)  // envelope did move
    }

    @Test func envelopeBalance_allocationsInMinusExpensesOut() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Groceries")
        context.insert(account)
        context.insert(envelope)
        context.insert(Transaction(amount: 400, type: .allocation, account: account, envelope: envelope))
        context.insert(Transaction(amount: 62, type: .expense, account: account, envelope: envelope))
        try context.save()

        #expect(BudgetMath.envelopeBalance(envelope) == 338)
    }

    @Test func toBeBudgeted_isIncomeMinusAllocations() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let rent = Envelope(name: "Rent")
        context.insert(account)
        context.insert(rent)
        context.insert(Transaction(amount: 2000, type: .income, account: account))
        context.insert(Transaction(amount: 800, type: .allocation, account: account, envelope: rent))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        #expect(BudgetMath.toBeBudgeted(transactions: all) == 1200)
    }

    @Test func targetProgress_clampsToUnitInterval() throws {
        let context = try makeContext()
        let account = Account(name: "Checking")
        let envelope = Envelope(name: "Savings", target: 1000)
        context.insert(account)
        context.insert(envelope)
        context.insert(Transaction(amount: 1500, type: .allocation, account: account, envelope: envelope))
        try context.save()

        // Balance exceeds target → progress clamps to 1.0.
        #expect(BudgetMath.targetProgress(envelope) == 1.0)
    }
}
