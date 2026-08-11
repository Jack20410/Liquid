//
//  Envelope.swift
//  Liquid
//
//  A budget category — a "job" assigned to money (Rent, Groceries, Fun). Its
//  balance is allocations in minus expenses out — see BudgetMath.envelopeBalance(_:).
//

import Foundation
import SwiftData

@Model
final class Envelope: Identifiable {
    var id: UUID
    var name: String
    /// Optional savings target for the envelope (spec FR-14).
    var target: Decimal?

    /// The allocation rule used at distribution time. Deleting an envelope
    /// deletes its rule (spec §9).
    @Relationship(deleteRule: .cascade)
    var rule: AllocationRule?

    /// Allocations in and expenses out. Deleting an envelope nullifies the
    /// envelope reference on these transactions rather than deleting the money
    /// records (spec §9).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.envelope)
    var transactions: [Transaction]

    init(
        id: UUID = UUID(),
        name: String,
        target: Decimal? = nil,
        rule: AllocationRule? = nil,
        transactions: [Transaction] = []
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.rule = rule
        self.transactions = transactions
    }
}
