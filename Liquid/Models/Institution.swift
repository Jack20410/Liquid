//
//  Institution.swift
//  Liquid
//
//  A bank or brand (e.g. Chase, Ally) that holds one or more accounts. Grouping
//  accounts under an institution lets the Accounts screen organize by bank.
//

import Foundation
import SwiftData

@Model
final class Institution: Identifiable {
    var id: UUID
    var name: String

    /// Accounts held at this institution. Deleting an institution un-assigns its
    /// accounts (nullify) rather than deleting the money records.
    @Relationship(deleteRule: .nullify, inverse: \Account.institution)
    var accounts: [Account]

    init(id: UUID = UUID(), name: String, accounts: [Account] = []) {
        self.id = id
        self.name = name
        self.accounts = accounts
    }
}
