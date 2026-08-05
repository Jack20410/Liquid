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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .allocation: "Allocation"
        }
    }
}

@Model
final class Transaction {
    var id: UUID
    var date: Date
    /// Always stored as a positive value (spec §6.3).
    var amount: Decimal
    var type: TransactionType
    var note: String
    var account: Account?
    var envelope: Envelope?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Decimal,
        type: TransactionType,
        note: String = "",
        account: Account? = nil,
        envelope: Envelope? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.note = note
        self.account = account
        self.envelope = envelope
    }
}
