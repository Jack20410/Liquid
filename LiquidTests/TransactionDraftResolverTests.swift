//
//  TransactionDraftResolverTests.swift
//  LiquidTests
//
//  Tests for TransactionDraftResolver — the pure step that maps a language model's
//  raw extraction onto the user's real accounts and envelopes. No model, no
//  SwiftData: ParsedFields is constructed directly, so these are deterministic.
//

import Testing
import Foundation
@testable import Liquid

struct TransactionDraftResolverTests {

    // Fixed catalog reused across cases.
    private let checkingID = UUID()
    private let cashID = UUID()
    private let groceriesID = UUID()
    private let funID = UUID()

    private var catalog: ParseCatalog {
        ParseCatalog(
            accounts: [NamedItem(id: checkingID, name: "Chase Checking"),
                       NamedItem(id: cashID, name: "Cash")],
            envelopes: [NamedItem(id: groceriesID, name: "Groceries"),
                        NamedItem(id: funID, name: "Fun")],
            defaultAccountID: checkingID)
    }

    private func fields(kind: String = "expense", amount: Decimal = 10, daysAgo: Int = 0,
                        envelope: String? = nil, account: String? = nil,
                        note: String = "note") -> ParsedFields {
        ParsedFields(kind: kind, amount: amount, daysAgo: daysAgo,
                     envelopeName: envelope, accountName: account, note: note)
    }

    @Test func expenseMatchesEnvelopeAndAccountByExactName() {
        let draft = TransactionDraftResolver.resolve(
            fields(amount: 45, envelope: "Groceries", account: "Cash"), catalog: catalog)
        #expect(draft.type == .expense)
        #expect(draft.amount == 45)
        #expect(draft.envelopeID == groceriesID)
        #expect(draft.accountID == cashID)
    }

    @Test func matchIsCaseAndDiacriticInsensitive() {
        let draft = TransactionDraftResolver.resolve(
            fields(envelope: "grOceries"), catalog: catalog)
        #expect(draft.envelopeID == groceriesID)
    }

    @Test func matchFallsBackToContains() {
        // A spoken merchant fragment should still land on the envelope by containment.
        let cat = ParseCatalog(
            accounts: [], envelopes: [NamedItem(id: funID, name: "Trader Joe's")],
            defaultAccountID: nil)
        let draft = TransactionDraftResolver.resolve(
            fields(envelope: "trader joe"), catalog: cat)
        #expect(draft.envelopeID == funID)
    }

    @Test func unknownEnvelopeIsLeftNil() {
        let draft = TransactionDraftResolver.resolve(
            fields(envelope: "Vacation"), catalog: catalog)
        #expect(draft.envelopeID == nil)
    }

    @Test func unknownAccountFallsBackToDefault() {
        let draft = TransactionDraftResolver.resolve(
            fields(account: "Wells Fargo"), catalog: catalog)
        #expect(draft.accountID == checkingID)   // the default
    }

    @Test func missingAccountUsesDefault() {
        let draft = TransactionDraftResolver.resolve(fields(account: nil), catalog: catalog)
        #expect(draft.accountID == checkingID)
    }

    @Test func unmatchedAccountWithNoDefaultIsNil() {
        let cat = ParseCatalog(accounts: [], envelopes: [], defaultAccountID: nil)
        let draft = TransactionDraftResolver.resolve(fields(account: "Nope"), catalog: cat)
        #expect(draft.accountID == nil)
    }

    @Test func incomeIgnoresEnvelope() {
        let draft = TransactionDraftResolver.resolve(
            fields(kind: "income", envelope: "Groceries"), catalog: catalog)
        #expect(draft.type == .income)
        #expect(draft.envelopeID == nil)   // income never uses an envelope
    }

    @Test func unknownKindDefaultsToExpense() {
        let draft = TransactionDraftResolver.resolve(fields(kind: "wibble"), catalog: catalog)
        #expect(draft.type == .expense)
    }

    @Test func daysAgoResolvesToPastDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar(identifier: .gregorian)
        let draft = TransactionDraftResolver.resolve(
            fields(daysAgo: 3), catalog: catalog, now: now, calendar: cal)
        let expected = cal.date(byAdding: .day, value: -3, to: now)!
        #expect(draft.date == expected)
    }

    @Test func zeroAmountIsLeftNil() {
        let draft = TransactionDraftResolver.resolve(fields(amount: 0), catalog: catalog)
        #expect(draft.amount == nil)
    }

    @Test func noteIsTrimmed() {
        let draft = TransactionDraftResolver.resolve(
            fields(note: "  coffee  "), catalog: catalog)
        #expect(draft.note == "coffee")
    }
}
