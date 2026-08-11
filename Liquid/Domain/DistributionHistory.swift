//
//  DistributionHistory.swift
//  Liquid
//
//  Reconstructs past paycheck distributions from stored data. A confirmed
//  distribution is persisted as one `.allocation` transaction per funded envelope,
//  all sharing a single timestamp (see `SwiftDataBudgetRepository.applyDistribution`),
//  and allocations are only ever created by the Distribute flow. So grouping
//  allocation transactions by their date recovers each distribution "event" — no
//  extra bookkeeping or schema change needed.
//
//  These are pure functions over stored transactions, so they're unit-testable in
//  isolation (see LiquidTests/DistributionHistoryTests.swift).
//

import Foundation

extension BudgetMath {

    /// One envelope's share — either within a single distribution event, or within
    /// an aggregate "where the money goes" breakdown.
    struct DistributionShare: Identifiable, Equatable {
        /// The envelope's id, or the transaction's id if its envelope was deleted.
        let id: UUID
        let name: String
        let amount: Decimal
    }

    /// A single confirmed paycheck distribution: the allocations made together.
    struct DistributionEvent: Identifiable, Equatable {
        let date: Date
        /// The account the paycheck landed in (all shares agree). Nil if unknown.
        let accountName: String?
        /// Funded envelopes, largest share first.
        let shares: [DistributionShare]

        var id: Date { date }
        var total: Decimal { shares.reduce(0) { $0 + $1.amount } }
        var envelopeCount: Int { shares.count }
    }

    /// Group allocation transactions into distribution events, newest first.
    static func distributionHistory(transactions: [Transaction]) -> [DistributionEvent] {
        let allocations = transactions.filter { $0.type == .allocation }
        let grouped = Dictionary(grouping: allocations, by: \.date)
        return grouped
            .map { date, txs in
                let shares = txs
                    .map { tx in
                        DistributionShare(id: tx.envelope?.id ?? tx.id,
                                          name: tx.envelope?.name ?? "Deleted envelope",
                                          amount: tx.amount)
                    }
                    .sorted { $0.amount > $1.amount }
                return DistributionEvent(date: date,
                                         accountName: txs.first?.account?.name,
                                         shares: shares)
            }
            .sorted { $0.date > $1.date }
    }

    /// Total money distributed into each envelope across *all* distributions,
    /// largest first — the data behind the "where the money goes" flow.
    static func distributionTotalsByEnvelope(transactions: [Transaction]) -> [DistributionShare] {
        let allocations = transactions.filter { $0.type == .allocation }
        var order: [UUID] = []
        var byEnvelope: [UUID: (name: String, amount: Decimal)] = [:]
        for tx in allocations {
            let id = tx.envelope?.id ?? tx.id
            let name = tx.envelope?.name ?? "Deleted envelope"
            if byEnvelope[id] == nil { order.append(id) }
            byEnvelope[id, default: (name, 0)].amount += tx.amount
        }
        return order
            .compactMap { id in byEnvelope[id].map { DistributionShare(id: id, name: $0.name, amount: $0.amount) } }
            .sorted { $0.amount > $1.amount }
    }
}
