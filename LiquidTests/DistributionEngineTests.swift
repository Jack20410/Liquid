//
//  DistributionEngineTests.swift
//  LiquidTests
//
//  Tests for the paycheck distribution algorithm (spec §7), including the
//  worked example from §7.2.
//

import Testing
import Foundation
@testable import Liquid

struct DistributionEngineTests {

    private func snapshot(_ name: String, _ balance: Decimal,
                          _ strategy: AllocationStrategy, _ priority: Int) -> EnvelopeSnapshot {
        EnvelopeSnapshot(id: UUID(), name: name, currentBalance: balance,
                         strategy: strategy, priority: priority)
    }

    // MARK: Spec §7.2 worked example

    @Test func workedExample_fullyAssignsPaycheck() {
        // $2,000 paycheck, Utilities already holds $50 (fill to $150 → +$100).
        let envelopes = [
            snapshot("Rent", 0, .fixed(800), 0),
            snapshot("Groceries", 0, .fixed(400), 1),
            snapshot("Utilities", 50, .fillToTarget(150), 2),
            snapshot("Fun", 0, .percentage(0.10), 3),
            snapshot("Savings", 0, .remainder, 4),
        ]

        let result = DistributionEngine.distribute(paycheck: 2000, envelopes: envelopes)

        func amount(_ name: String) -> Decimal? { result.lines.first { $0.name == name }?.amount }
        #expect(amount("Rent") == 800)
        #expect(amount("Groceries") == 400)
        #expect(amount("Utilities") == 100)
        #expect(amount("Fun") == 200)
        #expect(amount("Savings") == 500)

        #expect(result.totalAssigned == 2000)
        #expect(result.remaining == 0)        // zero-based outcome
        #expect(result.overcommitted == false)
    }

    // MARK: Ordering & clamping

    @Test func percentageUsesGrossPaycheck_notRunningRemainder() {
        // 10% of the gross $1,000 is $100 even though a fixed rule ran first.
        let envelopes = [
            snapshot("Rent", 0, .fixed(600), 0),
            snapshot("Fun", 0, .percentage(0.10), 1),
        ]
        let result = DistributionEngine.distribute(paycheck: 1000, envelopes: envelopes)
        #expect(result.lines.first { $0.name == "Fun" }?.amount == 100)
    }

    @Test func rulesAreEvaluatedInPriorityOrder() {
        // Lower priority number runs first regardless of array order.
        let envelopes = [
            snapshot("Second", 0, .fixed(100), 5),
            snapshot("First", 0, .fixed(100), 1),
        ]
        let result = DistributionEngine.distribute(paycheck: 1000, envelopes: envelopes)
        #expect(result.lines.map(\.name) == ["First", "Second"])
    }

    @Test func overcommitted_clampsToRemaining() {
        // Claims total $1,500 but only $1,000 available: Rent full, Groceries clamped.
        let envelopes = [
            snapshot("Rent", 0, .fixed(1000), 0),
            snapshot("Groceries", 0, .fixed(500), 1),
        ]
        let result = DistributionEngine.distribute(paycheck: 1000, envelopes: envelopes)
        #expect(result.totalAssigned == 1000)
        #expect(result.overcommitted == true)
        // Groceries got nothing left, so it is omitted from the lines.
        #expect(result.lines.contains { $0.name == "Groceries" } == false)
        #expect(result.remaining == 0)
    }

    // MARK: Remainder & unassigned

    @Test func leftoverGoesToRemainderEnvelope() {
        let envelopes = [
            snapshot("Rent", 0, .fixed(500), 0),
            snapshot("Savings", 0, .remainder, 1),
        ]
        let result = DistributionEngine.distribute(paycheck: 1200, envelopes: envelopes)
        #expect(result.lines.first { $0.name == "Savings" }?.amount == 700)
        #expect(result.remaining == 0)
    }

    @Test func noRemainderEnvelope_surfacesUnassignedMoney() {
        let envelopes = [
            snapshot("Rent", 0, .fixed(500), 0),
        ]
        let result = DistributionEngine.distribute(paycheck: 1200, envelopes: envelopes)
        #expect(result.totalAssigned == 500)
        #expect(result.remaining == 700)   // "To Be Budgeted"
    }

    @Test func fillToTarget_neverGoesNegative_whenAlreadyOverTarget() {
        let envelopes = [
            snapshot("Utilities", 200, .fillToTarget(150), 0),
        ]
        let result = DistributionEngine.distribute(paycheck: 1000, envelopes: envelopes)
        #expect(result.lines.contains { $0.name == "Utilities" } == false)
        #expect(result.remaining == 1000)
    }
}
