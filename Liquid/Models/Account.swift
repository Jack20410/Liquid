//
//  Account.swift
//  Liquid
//
//  A real place money physically lives (Checking, Savings, Cash). Its balance is
//  computed from its transactions — see BudgetMath.accountBalance(_:).
//

import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String

    /// All transactions touching this account. Deleting an account removes its
    /// transaction records (spec §9).
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]

    init(id: UUID = UUID(), name: String, transactions: [Transaction] = []) {
        self.id = id
        self.name = name
        self.transactions = transactions
    }
}
