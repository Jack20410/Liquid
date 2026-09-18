//
//  Account.swift
//  Liquid
//
//  A place money lives or is owed. Assets (checking, savings, cash) hold money;
//  a credit card is a liability whose balance is what you owe. Balance is computed
//  from transactions — see BudgetMath.accountBalance(_:).
//

import Foundation
import SwiftData

/// The kind of account, which decides how it is displayed and whether it is an
/// asset or a liability. A debit/checking card is not a separate type — it is just
/// a `.checking` account.
enum AccountType: String, Codable, CaseIterable, Identifiable, Hashable {
    case checking
    case savings
    case creditCard
    case cash
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: "Checking"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .cash: "Cash"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .checking: "building.columns"
        case .savings: "banknote"
        case .creditCard: "creditcard"
        case .cash: "dollarsign.circle"
        case .other: "wallet.bifold"
        }
    }

    /// Credit cards are debts: their balance is money owed, not money held.
    var isLiability: Bool { self == .creditCard }

    /// Only credit cards carry a credit limit / available-credit concept.
    var usesCreditLimit: Bool { self == .creditCard }
}

@Model
final class Account: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var type: AccountType = AccountType.checking
    /// Credit limit, for credit cards only.
    var creditLimit: Decimal?
    /// The bank/brand this account belongs to (nil = unassigned).
    var institution: Institution?

    /// Transactions where this account is the source: income, expenses,
    /// allocations, and the "from" side of transfers. Deleting an account removes
    /// these records (spec §9).
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    /// Transfers where this account is the destination (the "to" side). Deleting
    /// the destination account nullifies the reference rather than deleting the
    /// transfer, which still belongs to its source account.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType = .checking,
        creditLimit: Decimal? = nil,
        institution: Institution? = nil,
        transactions: [Transaction] = [],
        incomingTransfers: [Transaction] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.creditLimit = creditLimit
        self.institution = institution
        self.transactions = transactions
        self.incomingTransfers = incomingTransfers
    }
}
