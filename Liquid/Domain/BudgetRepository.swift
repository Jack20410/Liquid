//
//  BudgetRepository.swift
//  Liquid
//
//  The data layer's public seam (spec §5.1). The rest of the app talks to a
//  repository, never to raw storage, so the transaction source or persistence
//  layer can change without rewriting the UI (NFR-5).
//

import Foundation
import SwiftData

/// Operations the app performs against stored budget data.
@MainActor
protocol BudgetRepository {
    // Institutions
    func createInstitution(name: String) -> Institution
    func deleteInstitution(_ institution: Institution)

    // Accounts
    @discardableResult
    func createAccount(name: String, type: AccountType, creditLimit: Decimal?,
                       institution: Institution?) -> Account
    func updateAccount(_ account: Account, name: String, type: AccountType,
                       creditLimit: Decimal?, institution: Institution?)
    func deleteAccount(_ account: Account)

    // Envelopes
    func createEnvelope(name: String, target: Decimal?, kind: EnvelopeKind) -> Envelope
    func updateEnvelope(_ envelope: Envelope, name: String, target: Decimal?, kind: EnvelopeKind)
    func setRule(_ strategy: AllocationStrategy, priority: Int, on envelope: Envelope)
    func deleteEnvelope(_ envelope: Envelope)

    // Transactions
    @discardableResult
    func addTransaction(amount: Decimal, date: Date, type: TransactionType,
                        note: String, account: Account?, envelope: Envelope?) -> Transaction
    /// Move money between two accounts (e.g. paying a credit card). No envelope.
    @discardableResult
    func addTransfer(amount: Decimal, date: Date, from: Account, to: Account,
                     note: String) -> Transaction
    func deleteTransaction(_ transaction: Transaction)

    // Paycheck distribution
    /// Persist a confirmed distribution as one `.allocation` transaction per
    /// funded envelope, all against `account`. Account balance is unchanged by
    /// construction (spec §7.4).
    func applyDistribution(_ result: DistributionResult, from account: Account,
                           date: Date, envelopesByID: [UUID: Envelope])

    func save()
}

/// SwiftData-backed implementation.
@MainActor
struct SwiftDataBudgetRepository: BudgetRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Institutions

    func createInstitution(name: String) -> Institution {
        let institution = Institution(name: name)
        context.insert(institution)
        save()
        return institution
    }

    func deleteInstitution(_ institution: Institution) {
        context.delete(institution)   // accounts are nullified, not deleted
        save()
    }

    // MARK: Accounts

    @discardableResult
    func createAccount(name: String, type: AccountType, creditLimit: Decimal?,
                       institution: Institution?) -> Account {
        let account = Account(name: name, type: type,
                              creditLimit: type.usesCreditLimit ? creditLimit : nil,
                              institution: institution)
        context.insert(account)
        save()
        return account
    }

    func updateAccount(_ account: Account, name: String, type: AccountType,
                       creditLimit: Decimal?, institution: Institution?) {
        account.name = name
        account.type = type
        account.creditLimit = type.usesCreditLimit ? creditLimit : nil
        account.institution = institution
        save()
    }

    func deleteAccount(_ account: Account) {
        context.delete(account)
        save()
    }

    // MARK: Envelopes

    func createEnvelope(name: String, target: Decimal?, kind: EnvelopeKind) -> Envelope {
        let envelope = Envelope(name: name, target: target, kind: kind)
        context.insert(envelope)
        save()
        return envelope
    }

    func updateEnvelope(_ envelope: Envelope, name: String, target: Decimal?, kind: EnvelopeKind) {
        envelope.name = name
        envelope.target = target
        envelope.kind = kind
        save()
    }

    func setRule(_ strategy: AllocationStrategy, priority: Int, on envelope: Envelope) {
        if let existing = envelope.rule {
            existing.strategy = strategy
            existing.priority = priority
        } else {
            envelope.rule = AllocationRule(strategy: strategy, priority: priority)
        }
        save()
    }

    func deleteEnvelope(_ envelope: Envelope) {
        context.delete(envelope)
        save()
    }

    // MARK: Transactions

    @discardableResult
    func addTransaction(amount: Decimal, date: Date, type: TransactionType,
                        note: String, account: Account?, envelope: Envelope?) -> Transaction {
        let tx = Transaction(date: date, amount: amount, type: type,
                             note: note, account: account, envelope: envelope)
        context.insert(tx)
        save()
        return tx
    }

    @discardableResult
    func addTransfer(amount: Decimal, date: Date, from: Account, to: Account,
                     note: String) -> Transaction {
        let tx = Transaction(date: date, amount: amount, type: .transfer,
                             note: note, account: from, toAccount: to)
        context.insert(tx)
        save()
        return tx
    }

    func deleteTransaction(_ transaction: Transaction) {
        context.delete(transaction)
        save()
    }

    // MARK: Distribution

    func applyDistribution(_ result: DistributionResult, from account: Account,
                           date: Date, envelopesByID: [UUID: Envelope]) {
        for line in result.lines where line.amount > 0 {
            guard let envelope = envelopesByID[line.id] else { continue }
            let tx = Transaction(date: date, amount: line.amount, type: .allocation,
                                 note: "Paycheck allocation", account: account, envelope: envelope)
            context.insert(tx)
        }
        save()
    }

    // MARK: Persistence

    func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }
}
