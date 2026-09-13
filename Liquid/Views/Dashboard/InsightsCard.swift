//
//  InsightsCard.swift
//  Liquid
//
//  "Insights": a plain-language read on the user's money. The facts come from
//  InsightsEngine and are always shown as deterministic sentences, so the card
//  works everywhere. When Apple's on-device model is available it rephrases those
//  sentences into a short narrative (badged "On-device AI"); if it isn't, or if
//  the narration fails the grounding check, the sentences stay as they are.
//

import SwiftUI

struct InsightsCard: View {
    let transactions: [Transaction]
    let envelopes: [Envelope]
    let accounts: [Account]

    @State private var narration: String?

    private var insights: [Insight] {
        InsightsEngine.insights(transactions: transactions, envelopes: envelopes, accounts: accounts)
    }

    private var sentences: [String] { insights.map(\.sentence) }

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Insights") {
                    if narration != nil { onDeviceBadge }
                }

                if let narration {
                    Text(narration)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(insights, id: \.self) { row($0) }
                    }
                }
            }
            .dashboardCard()
            .task(id: sentences) { await narrate() }
        }
    }

    private func row(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.severity.icon)
                .foregroundStyle(insight.severity.tint)
                .frame(width: 20)
            Text(insight.sentence)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var onDeviceBadge: some View {
        Label("On-device AI", systemImage: "sparkles")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: .capsule)
    }

    /// Ask the on-device model to rephrase the facts; keep the sentences on any
    /// failure (unavailable, error, or a narration that changed a number).
    private func narrate() async {
        narration = nil
        guard OnDeviceInsightsNarrator.isAvailable, !sentences.isEmpty else { return }
        narration = try? await OnDeviceInsightsNarrator().narrate(sentences)
    }
}

// MARK: - Presentation

extension Insight {
    /// The deterministic sentence for this fact — the grounding the narrator must
    /// preserve, and the fallback shown when it can't narrate.
    var sentence: String {
        switch self {
        case let .overspent(envelope, by):
            "\(envelope) is overspent by \(by.asCurrency)."
        case let .runningLow(envelope, balance):
            "At this month's pace, \(envelope) will run out — \(balance.asCurrency) left."
        case let .spendingTrend(percent, up):
            "Spending is \(up ? "up" : "down") \(percent)% compared with the same point last month."
        case let .creditUtilization(account, percent):
            "\(account) is at \(percent)% of its credit limit."
        case let .topCategory(envelope, amount, share):
            "Your biggest spending category this month is \(envelope) — \(amount.asCurrency), \(share)% of what you spent."
        case let .safeToSpend(amount):
            amount < 0
                ? "Your spending envelopes are overspent by \((-amount).asCurrency)."
                : "\(amount.asCurrency) is safe to spend across your spending envelopes."
        case let .unbudgeted(amount):
            "\(amount.asCurrency) of income is still waiting to be given a job."
        }
    }
}

extension Insight.Severity {
    var icon: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .neutral: "info.circle.fill"
        case .positive: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .warning: Color.decrease
        case .neutral: Color.accentColor
        case .positive: Color.increase
        }
    }
}
