//
//  AllocationRule.swift
//  Liquid
//
//  A rule attached to an envelope describing how it should be filled when a
//  paycheck arrives (spec §6.1, §7).
//
//  SwiftData cannot persist an enum with associated values directly, so the
//  strategy is stored as a `kind` string plus a `value` Decimal, and exposed
//  through the computed `strategy` property.
//

import Foundation
import SwiftData

/// How an envelope claims money during paycheck distribution.
enum AllocationStrategy: Equatable, Hashable {
    /// Take a fixed amount.
    case fixed(Decimal)
    /// Take a fraction of the gross paycheck (0.10 == 10%).
    case percentage(Decimal)
    /// Top the envelope up to the given target balance.
    case fillToTarget(Decimal)
    /// Absorb whatever is left after all other rules run. At most one per budget.
    case remainder

    /// Stable identifier for the strategy kind, used for persistence and pickers.
    enum Kind: String, Codable, CaseIterable, Identifiable, Hashable {
        case fixed, percentage, fillToTarget, remainder
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .fixed: "Fixed amount"
            case .percentage: "Percentage of paycheck"
            case .fillToTarget: "Fill to target"
            case .remainder: "Remainder"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .fixed: .fixed
        case .percentage: .percentage
        case .fillToTarget: .fillToTarget
        case .remainder: .remainder
        }
    }

    /// The associated Decimal (unused for `.remainder`).
    var value: Decimal {
        switch self {
        case let .fixed(v), let .percentage(v), let .fillToTarget(v): v
        case .remainder: 0
        }
    }

    init(kind: Kind, value: Decimal) {
        switch kind {
        case .fixed: self = .fixed(value)
        case .percentage: self = .percentage(value)
        case .fillToTarget: self = .fillToTarget(value)
        case .remainder: self = .remainder
        }
    }
}

@Model
final class AllocationRule {
    var id: UUID = UUID()
    /// Persisted representation of the strategy kind. Use `strategy` to read/write.
    var strategyKind: AllocationStrategy.Kind = AllocationStrategy.Kind.fixed
    /// Persisted associated value for the strategy (amount, percentage, or target).
    var strategyValue: Decimal = 0
    /// Order of evaluation; lower runs first (spec §6.1).
    var priority: Int = 0
    /// Inverse of `Envelope.rule`; required for CloudKit sync.
    var envelope: Envelope?

    var strategy: AllocationStrategy {
        get { AllocationStrategy(kind: strategyKind, value: strategyValue) }
        set {
            strategyKind = newValue.kind
            strategyValue = newValue.value
        }
    }

    init(id: UUID = UUID(), strategy: AllocationStrategy, priority: Int = 0) {
        self.id = id
        self.strategyKind = strategy.kind
        self.strategyValue = strategy.value
        self.priority = priority
    }
}
