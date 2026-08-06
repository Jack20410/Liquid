//
//  AccountTests.swift
//  LiquidTests
//
//  Tests for account types, credit-card math, transfers, and net worth.
//

import Testing
import Foundation
import SwiftData
@testable import Liquid

@MainActor
struct AccountTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Institution.self, Account.self, Envelope.self,
                             Transaction.self, AllocationRule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: Credit card

    @Test func creditCard_owedAndAvailableFromCharges() throws {
        let context = try makeContext()
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let envelope = Envelope(name: "Fun")
        context.insert(card)
        context.insert(envelope)
        context.insert(Transaction(amount: 300, type: .expense, account: card, envelope: envelope))
        try context.save()

        #expect(BudgetMath.accountBalance(card) == -300)   // negative = owed
        #expect(BudgetMath.amountOwed(card) == 300)
        #expect(BudgetMath.availableCredit(card) == 700)
        #expect(BudgetMath.creditUtilization(card) == 0.3)
    }

    @Test func availableCredit_isNilForNonCreditAccounts() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        context.insert(checking)
        try context.save()
        #expect(BudgetMath.availableCredit(checking) == nil)
        #expect(BudgetMath.creditUtilization(checking) == nil)
    }

    // MARK: Transfers

    @Test func transfer_movesBalanceBetweenAccounts_leavesNetWorth() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let envelope = Envelope(name: "Fun")
        context.insert(checking)
        context.insert(card)
        context.insert(envelope)

        // Start: checking has 500 income; card charged 300 (owes 300).
        context.insert(Transaction(amount: 500, type: .income, account: checking))
        context.insert(Transaction(amount: 300, type: .expense, account: card, envelope: envelope))
        try context.save()

        let netBefore = BudgetMath.totalAccountsBalance([checking, card])
        #expect(netBefore == 200)   // 500 − 300

        // Pay 300 from checking to the card.
        context.insert(Transaction(amount: 300, type: .transfer, account: checking, toAccount: card))
        try context.save()

        #expect(BudgetMath.accountBalance(checking) == 200)   // 500 − 300 paid
        #expect(BudgetMath.accountBalance(card) == 0)         // −300 + 300 = paid off
        #expect(BudgetMath.amountOwed(card) == 0)
        // Net worth unchanged: paying debt converts cash to reduced liability.
        #expect(BudgetMath.totalAccountsBalance([checking, card]) == netBefore)
    }

    @Test func transfer_doesNotAffectEnvelopesTBBorCashFlow() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let envelope = Envelope(name: "Fun")
        context.insert(checking)
        context.insert(card)
        context.insert(envelope)

        context.insert(Transaction(amount: 500, type: .income, account: checking))
        context.insert(Transaction(amount: 200, type: .allocation, account: checking, envelope: envelope))
        context.insert(Transaction(amount: 150, type: .transfer, account: checking, toAccount: card))
        try context.save()

        let all = try context.fetch(FetchDescriptor<Transaction>())
        // To Be Budgeted = income − allocations, transfers ignored.
        #expect(BudgetMath.toBeBudgeted(transactions: all) == 300)
        // Envelope only reflects its allocation, not the transfer.
        #expect(BudgetMath.envelopeBalance(envelope) == 200)
        // Cash flow (daily summaries) excludes the transfer entirely.
        let summaries = BudgetMath.dailySummaries(all)
        let totalSpending = summaries.values.reduce(Decimal(0)) { $0 + $1.spending }
        #expect(totalSpending == 0)   // the only non-income/expense tx was a transfer
    }

    // MARK: Net worth split

    @Test func assetsMinusLiabilities_equalsNetWorth() throws {
        let context = try makeContext()
        let checking = Account(name: "Checking", type: .checking)
        let savings = Account(name: "Savings", type: .savings)
        let card = Account(name: "Visa", type: .creditCard, creditLimit: 1000)
        let envelope = Envelope(name: "Fun")
        context.insert(checking); context.insert(savings); context.insert(card); context.insert(envelope)

        context.insert(Transaction(amount: 1000, type: .income, account: checking))
        context.insert(Transaction(amount: 2500, type: .income, account: savings))
        context.insert(Transaction(amount: 400, type: .expense, account: card, envelope: envelope))
        try context.save()

        let accounts = [checking, savings, card]
        let assets = BudgetMath.totalAssets(accounts)
        let liabilities = BudgetMath.totalLiabilities(accounts)
        #expect(assets == 3500)
        #expect(liabilities == 400)
        #expect(assets - liabilities == BudgetMath.totalAccountsBalance(accounts))
    }
}
