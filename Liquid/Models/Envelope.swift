//
//  Envelope.swift
//  Liquid
//
//  A budget category — a "job" assigned to money (Rent, Groceries, Fun). Its
//  balance is allocations in minus expenses out — see BudgetMath.envelopeBalance(_:).
//

import Foundation
import SwiftData

/// What an envelope is *for*, which decides whether its balance counts as
/// "safe to spend" — money you can spend freely, versus money set aside for a
/// recurring bill or a savings goal. Only `.spending` counts (see
/// `BudgetMath.safeToSpend(_:)`).
enum EnvelopeKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case spending   // day-to-day, guilt-free (Groceries, Fun)
    case bill       // recurring obligations (Rent, Utilities)
    case goal       // savings targets (Savings)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spending: "Spending"
        case .bill: "Bill"
        case .goal: "Goal"
        }
    }

    var icon: String {
        switch self {
        case .spending: "cart"
        case .bill: "calendar.badge.clock"
        case .goal: "target"
        }
    }

    /// Whether this envelope's balance is available to spend freely.
    var isSafeToSpend: Bool { self == .spending }
}

@Model
final class Envelope: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    /// Optional savings target for the envelope (spec FR-14).
    var target: Decimal?
    /// What the envelope is for; decides whether it counts as "safe to spend".
    /// The declaration default lets SwiftData lightweight-migrate existing stores
    /// (older envelopes become `.spending`).
    var kind: EnvelopeKind = EnvelopeKind.spending

    /// The allocation rule used at distribution time. Deleting an envelope
    /// deletes its rule (spec §9). The inverse (`AllocationRule.envelope`) is
    /// required for CloudKit sync.
    @Relationship(deleteRule: .cascade, inverse: \AllocationRule.envelope)
    var rule: AllocationRule?

    /// Allocations in and expenses out. Deleting an envelope nullifies the
    /// envelope reference on these transactions rather than deleting the money
    /// records (spec §9).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.envelope)
    var transactions: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        target: Decimal? = nil,
        kind: EnvelopeKind = .spending,
        rule: AllocationRule? = nil,
        transactions: [Transaction] = []
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.kind = kind
        self.rule = rule
        self.transactions = transactions
    }
}
