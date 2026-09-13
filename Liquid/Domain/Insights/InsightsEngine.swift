//
//  InsightsEngine.swift
//  Liquid
//
//  Turns the user's transactions, envelopes, and accounts into a short, ordered
//  list of grounded insights. Pure and deterministic — it reuses BudgetMath for
//  every balance, takes an explicit `asOf`/`calendar` so it is unit-testable, and
//  never touches storage or the language model. Warnings come first, then
//  neutral facts, then good news.
//

import Foundation

enum InsightsEngine {

    /// Compute up to `limit` insights, most important first.
    static func insights(transactions: [Transaction], envelopes: [Envelope], accounts: [Account],
                         calendar: Calendar = .current, asOf: Date = .now,
                         limit: Int = 4) -> [Insight] {
        guard limit > 0 else { return [] }
        var found: [Insight] = []

        // The current month, to date.
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: asOf)) ?? asOf
        let dayOfMonth = calendar.component(.day, from: asOf)
        let daysInMonth = calendar.range(of: .day, in: .month, for: asOf)?.count ?? 30
        let elapsed = Double(dayOfMonth) / Double(daysInMonth)

        func inThisMonth(_ date: Date) -> Bool { date >= monthStart && date <= asOf }
        func monthSpend(_ txs: [Transaction]) -> Decimal {
            txs.filter { $0.type == .expense && inThisMonth($0.date) }
               .reduce(Decimal(0)) { $0 + $1.amount }
        }
        let monthTotal = monthSpend(transactions)

        // Overspent envelopes.
        for env in envelopes {
            let balance = BudgetMath.envelopeBalance(env)
            if balance < 0 { found.append(.overspent(envelope: env.name, by: -balance)) }
        }

        // Running low: at this month's pace, projected remaining spend exceeds what's
        // left. Needs a meaningful slice of the month to have elapsed.
        if elapsed >= 0.25 {
            for env in envelopes where env.kind.isSafeToSpend {
                let balance = BudgetMath.envelopeBalance(env)
                let spent = monthSpend(env.transactions)
                guard balance > 0, spent > 0 else { continue }
                let projectedRemaining = spent * Decimal((1 - elapsed) / elapsed)
                if projectedRemaining > balance {
                    found.append(.runningLow(envelope: env.name, balance: balance))
                }
            }
        }

        // Spending trend vs the same number of days into last month.
        if let lastStart = calendar.date(byAdding: .month, value: -1, to: monthStart),
           let lastCutoff = calendar.date(byAdding: .day, value: dayOfMonth, to: lastStart) {
            let lastSamePoint = transactions
                .filter { $0.type == .expense && $0.date >= lastStart && $0.date < lastCutoff }
                .reduce(Decimal(0)) { $0 + $1.amount }
            if lastSamePoint > 0, monthTotal > 0 {
                let change = ((monthTotal - lastSamePoint) / lastSamePoint) as NSDecimalNumber
                let percent = Int((change.doubleValue * 100).rounded())
                if abs(percent) >= 10 {
                    found.append(.spendingTrend(percent: abs(percent), up: percent > 0))
                }
            }
        }

        // Credit cards using a notable share of their limit.
        for account in accounts {
            if let utilization = BudgetMath.creditUtilization(account), utilization >= 0.3 {
                found.append(.creditUtilization(account: account.name,
                                                percent: Int((utilization * 100).rounded())))
            }
        }

        // Income still waiting for a job — the actionable headline, so it leads the
        // neutral tier ahead of the top-category stat.
        let unbudgeted = BudgetMath.toBeBudgeted(transactions: transactions)
        if unbudgeted > 0 { found.append(.unbudgeted(amount: unbudgeted)) }

        // Biggest spending envelope this month.
        var top: (name: String, amount: Decimal)?
        for env in envelopes {
            let spent = monthSpend(env.transactions)
            if spent > 0, spent > (top?.amount ?? 0) { top = (env.name, spent) }
        }
        if let top, monthTotal > 0 {
            let share = ((top.amount / monthTotal) as NSDecimalNumber).doubleValue * 100
            found.append(.topCategory(envelope: top.name, amount: top.amount,
                                      share: Int(share.rounded())))
        }

        // What's free to spend across the day-to-day envelopes.
        if envelopes.contains(where: { $0.kind.isSafeToSpend }) {
            found.append(.safeToSpend(amount: BudgetMath.safeToSpend(envelopes)))
        }

        // Warnings first, then neutral, then positive — stable within a tier.
        let ordered = found.enumerated()
            .sorted { ($0.element.severity.rawValue, $0.offset) < ($1.element.severity.rawValue, $1.offset) }
            .map(\.element)
        return Array(ordered.prefix(limit))
    }
}
