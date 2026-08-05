//
//  BudgetMath.swift
//  Liquid
//
//  Balance calculations — the two independent views of the same transactions
//  (spec §6): where money is (accounts) and what it is for (envelopes).
//
//  Sign convention (spec §6.3, reconciled with §7.4):
//    • Account balance  = Σ income (+) and expense (−).  Allocations are EXCLUDED
//      because they only reassign existing dollars a job — they must not change
//      where the money physically sits (spec §7.4).
//    • Envelope balance = Σ allocation (+) and expense (−) assigned to it.
//    • To Be Budgeted   = Σ(all income) − Σ(all allocations): income that has
//      arrived but has not yet been given a job.
//

import Foundation

enum BudgetMath {

    // MARK: Account

    /// Balance of a single account: income in minus expenses out. Allocations do
    /// not affect account balances.
    static func accountBalance(_ account: Account) -> Decimal {
        account.transactions.reduce(0) { sum, tx in
            switch tx.type {
            case .income: sum + tx.amount
            case .expense: sum - tx.amount
            case .allocation: sum
            }
        }
    }

    /// Combined balance across every account (spec FR-15).
    static func totalAccountsBalance(_ accounts: [Account]) -> Decimal {
        accounts.reduce(0) { $0 + accountBalance($1) }
    }

    // MARK: Envelope

    /// Balance of a single envelope: allocations in minus expenses out (spec FR-8).
    static func envelopeBalance(_ envelope: Envelope) -> Decimal {
        envelope.transactions.reduce(0) { sum, tx in
            switch tx.type {
            case .allocation: sum + tx.amount
            case .expense: sum - tx.amount
            case .income: sum   // income is never assigned to an envelope
            }
        }
    }

    /// Progress toward an envelope's savings target in 0...1, or nil when no
    /// target is set (spec FR-14).
    static func targetProgress(_ envelope: Envelope) -> Double? {
        guard let target = envelope.target, target > 0 else { return nil }
        let balance = envelopeBalance(envelope)
        let ratio = (balance / target) as NSDecimalNumber
        return min(1, max(0, ratio.doubleValue))
    }

    // MARK: To Be Budgeted

    /// Income that has arrived but has not yet been allocated to any envelope
    /// (spec FR-13). Computed globally across all transactions.
    static func toBeBudgeted(transactions: [Transaction]) -> Decimal {
        transactions.reduce(0) { sum, tx in
            switch tx.type {
            case .income: sum + tx.amount
            case .allocation: sum - tx.amount
            case .expense: sum
            }
        }
    }
}
