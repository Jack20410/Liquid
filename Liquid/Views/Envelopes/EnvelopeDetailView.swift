//
//  EnvelopeDetailView.swift
//  Liquid
//
//  History for a single envelope: its balance, target progress, rule, and every
//  transaction that touched it (allocations in, expenses out).
//

import SwiftUI

struct EnvelopeDetailView: View {
    let envelope: Envelope

    private var history: [Transaction] {
        envelope.transactions.sorted { $0.date > $1.date }
    }

    private var balance: Decimal { BudgetMath.envelopeBalance(envelope) }

    private var ruleDescription: String? {
        guard let rule = envelope.rule else { return nil }
        return switch rule.strategy {
        case let .fixed(v): "Fixed \(v.asCurrency) each payday"
        case let .percentage(p): "\((p * 100).formatted())% of each paycheck"
        case let .fillToTarget(t): "Fill up to \(t.asCurrency) each payday"
        case .remainder: "Receives whatever is left after other rules"
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(balance.asCurrency)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(balance < 0 ? .decrease : .primary)
                    if let target = envelope.target, target > 0,
                       let progress = BudgetMath.targetProgress(envelope) {
                        ProgressView(value: progress) {
                            Text("Target \(target.asCurrency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let ruleDescription {
                        Label(ruleDescription, systemImage: "arrow.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("History") {
                if history.isEmpty {
                    Text("No transactions yet. Money arrives here when you distribute a paycheck, and leaves when you record an expense against this envelope.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { tx in
                        TransactionRow(transaction: tx, showsEnvelope: false)
                    }
                }
            }
        }
        .navigationTitle(envelope.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
