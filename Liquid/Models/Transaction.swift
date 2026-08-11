//
//  Transaction.swift
//  Liquid
//
//  A single movement of money: income, an expense, or an allocation into an
//  envelope. Amounts are always stored as positive values (spec §6.3); the sign
//  used in balance calculations is derived from `type` in BudgetMath.
//

import Foundation
import SwiftData

/// The kind of money movement a transaction represents.
enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Money arriving into an account (a paycheck). Positive for account balance.
    case income
    /// Money leaving an account, assigned to an envelope. Negative everywhere.
    case expense
    /// Assigning existing money a job by moving it into an envelope. Positive for
    /// envelope balance; excluded from account balance (spec §7.4).
    case allocation
    /// Money moved between two accounts (e.g. paying a credit card). Leaves the
    /// source (`account`) and enters the destination (`toAccount`); touches no
    /// envelope and is excluded from cash flow, like an allocation.
    case transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .allocation: "Allocation"
        case .transfer: "Transfer"
        }
    }
}

@Model
final class Transaction: Identifiable {
    var id: UUID
    var date: Date
    /// Always stored as a positive value (spec §6.3).
    var amount: Decimal
    var type: TransactionType
    var note: String
    /// The source account (money in/out). For transfers, this is the "from" side.
    var account: Account?
    /// The destination account for transfers (the "to" side); nil otherwise.
    var toAccount: Account?
    var envelope: Envelope?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Decimal,
        type: TransactionType,
        note: String = "",
        account: Account? = nil,
        toAccount: Account? = nil,
        envelope: Envelope? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.note = note
        self.account = account
        self.toAccount = toAccount
        self.envelope = envelope
    }
}
