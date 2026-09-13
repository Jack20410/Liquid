//
//  Insight.swift
//  Liquid
//
//  One grounded, deterministic fact about the user's money, computed by
//  InsightsEngine from the same math the rest of the app uses. Insights are pure
//  data: the view renders each as a templated sentence, and the on-device model
//  may rephrase those sentences — but every number originates here, never from
//  the model.
//

import Foundation

enum Insight: Hashable {
    /// An envelope's balance has gone negative.
    case overspent(envelope: String, by: Decimal)
    /// At this month's spending pace, the envelope will run out before month end.
    case runningLow(envelope: String, balance: Decimal)
    /// Month-to-date spending vs the same point last month (whole percent).
    case spendingTrend(percent: Int, up: Bool)
    /// A credit card's used share of its limit (whole percent).
    case creditUtilization(account: String, percent: Int)
    /// The biggest spending envelope this month and its share of the total.
    case topCategory(envelope: String, amount: Decimal, share: Int)
    /// Combined balance of the day-to-day spending envelopes (may be negative).
    case safeToSpend(amount: Decimal)
    /// Income that has not yet been given a job.
    case unbudgeted(amount: Decimal)

    enum Severity: Int {
        case warning = 0, neutral = 1, positive = 2
    }

    /// Warnings surface first; positives last.
    var severity: Severity {
        switch self {
        case .overspent, .runningLow:
            .warning
        case let .spendingTrend(_, up):
            up ? .warning : .positive
        case let .creditUtilization(_, percent):
            percent >= 70 ? .warning : .neutral
        case .topCategory, .unbudgeted:
            .neutral
        case let .safeToSpend(amount):
            amount < 0 ? .warning : .positive
        }
    }
}
