//
//  DistributionEngine.swift
//  Liquid
//
//  The signature feature of Liquid (spec §7): sweeping an incoming paycheck into
//  envelopes according to their allocation rules.
//
//  This is a PURE function operating on value-type snapshots, not SwiftData
//  models. It takes no ModelContext and has no side effects, so it can be unit
//  tested directly (see LiquidTests/DistributionEngineTests.swift) and reused by
//  the Distribute Paycheck screen without coupling to storage.
//

import Foundation

/// A read-only snapshot of the envelope facts the engine needs to plan a split.
struct EnvelopeSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    /// The envelope's balance *before* this distribution runs (used by fillToTarget).
    let currentBalance: Decimal
    let strategy: AllocationStrategy
    let priority: Int
}

/// One envelope's share of a proposed distribution.
struct DistributionLine: Identifiable, Equatable {
    let id: UUID          // envelope id
    let name: String
    var amount: Decimal
}

/// The outcome of planning a paycheck split.
struct DistributionResult: Equatable {
    /// One line per funded envelope, in evaluation order. Zero-amount envelopes
    /// are omitted.
    var lines: [DistributionLine]
    /// Income left unassigned after all rules ran. > 0 means the plan did not
    /// consume the whole paycheck ("To Be Budgeted"); the UI should surface it.
    var remaining: Decimal
    /// True when the rules tried to claim more than the paycheck could cover, so
    /// later envelopes were clamped (spec UC-2 alternate flow).
    var overcommitted: Bool

    /// Total assigned across all lines.
    var totalAssigned: Decimal { lines.reduce(0) { $0 + $1.amount } }
}

enum DistributionEngine {
    /// Compute a proposed distribution of `paycheck` across `envelopes` following
    /// the order of operations in spec §7.1 / §7.3.
    ///
    /// - Concrete claims (fixed, fillToTarget) and percentages are resolved in
    ///   `priority` order (lower first).
    /// - Percentages are taken from the **gross** paycheck, not the running
    ///   remainder, for predictability (spec §7.1).
    /// - Every claim is clamped so it never assigns more than is still available.
    /// - Whatever is left goes to the single `.remainder` envelope, if any.
    static func distribute(paycheck: Decimal, envelopes: [EnvelopeSnapshot]) -> DistributionResult {
        var remaining = max(0, paycheck)
        var lines: [DistributionLine] = []
        var overcommitted = false
        var remainderEnvelope: EnvelopeSnapshot?

        for env in envelopes.sorted(by: { $0.priority < $1.priority }) {
            let desired: Decimal
            switch env.strategy {
            case let .fixed(v):
                desired = max(0, v)
            case let .percentage(p):
                desired = max(0, paycheck * p)
            case let .fillToTarget(t):
                desired = max(0, t - env.currentBalance)
            case .remainder:
                // Resolved last; the last-declared remainder envelope wins.
                remainderEnvelope = env
                continue
            }

            let give = min(desired, remaining)   // never overspend
            if give < desired { overcommitted = true }
            remaining -= give
            if give > 0 {
                lines.append(DistributionLine(id: env.id, name: env.name, amount: give))
            }
        }

        if let remainderEnvelope, remaining > 0 {
            lines.append(DistributionLine(id: remainderEnvelope.id,
                                          name: remainderEnvelope.name,
                                          amount: remaining))
            remaining = 0
        }

        return DistributionResult(lines: lines, remaining: remaining, overcommitted: overcommitted)
    }
}
