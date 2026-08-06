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

    /// Balance of a single account. Income in, expenses out, and transfers out
    /// (this account as source); allocations do not affect account balances.
    /// Incoming transfers (this account as destination) add to the balance.
    ///
    /// A credit card's balance goes negative as it is charged — that negative is
    /// the amount owed (see `amountOwed`).
    static func accountBalance(_ account: Account) -> Decimal {
        var sum: Decimal = 0
        for tx in account.transactions {
            switch tx.type {
            case .income: sum += tx.amount
            case .expense: sum -= tx.amount
            case .transfer: sum -= tx.amount   // this account is the source
            case .allocation: break            // never affects account balance
            }
        }
        for tx in account.incomingTransfers {  // this account is the destination
            sum += tx.amount
        }
        return sum
    }

    /// Combined net worth across every account: assets minus liabilities
    /// (spec FR-15). Equal to the signed sum of all balances.
    static func totalAccountsBalance(_ accounts: [Account]) -> Decimal {
        accounts.reduce(0) { $0 + accountBalance($1) }
    }

    // MARK: Assets, liabilities & net worth

    /// Everything held (positive balances). Magnitude-based so the identity
    /// assets − liabilities == net worth always holds, whatever the account type.
    static func totalAssets(_ accounts: [Account]) -> Decimal {
        accounts.reduce(0) { $0 + max(0, accountBalance($1)) }
    }

    /// Everything owed (negative balances, as a positive number).
    static func totalLiabilities(_ accounts: [Account]) -> Decimal {
        accounts.reduce(0) { $0 + max(0, -accountBalance($1)) }
    }

    // MARK: Credit cards

    /// Amount owed on an account (its negative balance as a positive number).
    static func amountOwed(_ account: Account) -> Decimal {
        max(0, -accountBalance(account))
    }

    /// Credit still available: limit minus owed. Nil unless the account is a
    /// credit card with a limit set.
    static func availableCredit(_ account: Account) -> Decimal? {
        guard account.type.usesCreditLimit, let limit = account.creditLimit else { return nil }
        return limit - amountOwed(account)
    }

    /// Fraction of the credit limit used, 0...1. Nil unless a credit card with a
    /// positive limit.
    static func creditUtilization(_ account: Account) -> Double? {
        guard account.type.usesCreditLimit, let limit = account.creditLimit, limit > 0 else { return nil }
        let ratio = (amountOwed(account) / limit) as NSDecimalNumber
        return min(1, max(0, ratio.doubleValue))
    }

    // MARK: Envelope

    /// Balance of a single envelope: allocations in minus expenses out (spec FR-8).
    static func envelopeBalance(_ envelope: Envelope) -> Decimal {
        envelope.transactions.reduce(0) { sum, tx in
            switch tx.type {
            case .allocation: sum + tx.amount
            case .expense: sum - tx.amount
            case .income, .transfer: sum   // never assigned to an envelope
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
            case .expense, .transfer: sum
            }
        }
    }

    // MARK: Daily cash flow

    /// Income and spending for a single calendar day. `spending` is the unsigned
    /// magnitude of expenses; `net` is income minus spending.
    struct DailySummary: Equatable {
        let day: Date          // start-of-day
        var income: Decimal
        var spending: Decimal
        var net: Decimal { income - spending }
    }

    /// Income and spending per calendar day, keyed by start-of-day. Allocations
    /// are budget moves, not cash flow, so they are excluded (consistent with the
    /// Cash Flow card). Only days with activity appear. The `calendar` parameter
    /// is shared with any view that renders these so the day a transaction lands
    /// on always matches how it is displayed.
    static func dailySummaries(_ transactions: [Transaction],
                               calendar: Calendar = .current) -> [Date: DailySummary] {
        var byDay: [Date: DailySummary] = [:]
        for tx in transactions where tx.type == .income || tx.type == .expense {
            let day = calendar.startOfDay(for: tx.date)
            var summary = byDay[day] ?? DailySummary(day: day, income: 0, spending: 0)
            switch tx.type {
            case .income: summary.income += tx.amount
            case .expense: summary.spending += tx.amount
            case .allocation, .transfer: break   // excluded by the filter above
            }
            byDay[day] = summary
        }
        return byDay
    }
}
