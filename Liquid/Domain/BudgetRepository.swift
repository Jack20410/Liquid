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
    // Accounts
    func createAccount(name: String) -> Account
    func renameAccount(_ account: Account, to name: String)
    func deleteAccount(_ account: Account)

    // Envelopes
    func createEnvelope(name: String, target: Decimal?) -> Envelope
    func updateEnvelope(_ envelope: Envelope, name: String, target: Decimal?)
    func setRule(_ strategy: AllocationStrategy, priority: Int, on envelope: Envelope)
    func deleteEnvelope(_ envelope: Envelope)

    // Transactions
    @discardableResult
    func addTransaction(amount: Decimal, date: Date, type: TransactionType,
                        note: String, account: Account?, envelope: Envelope?) -> Transaction
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

    // MARK: Accounts

    func createAccount(name: String) -> Account {
        let account = Account(name: name)
        context.insert(account)
        save()
        return account
    }

    func renameAccount(_ account: Account, to name: String) {
        account.name = name
        save()
    }

    func deleteAccount(_ account: Account) {
        context.delete(account)
        save()
    }

    // MARK: Envelopes

    func createEnvelope(name: String, target: Decimal?) -> Envelope {
        let envelope = Envelope(name: name, target: target)
        context.insert(envelope)
        save()
        return envelope
    }

    func updateEnvelope(_ envelope: Envelope, name: String, target: Decimal?) {
        envelope.name = name
        envelope.target = target
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
