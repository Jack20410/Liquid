//
//  BudgetRingCard.swift
//  Liquid
//
//  The dashboard hero: a progress ring showing how much of your budgeted money is
//  still free to spend, with the "left to spend" amount at its center and a
//  Budget / Allocated / Available trio beneath. This replaces the old text-only
//  "To Be Budgeted" and "Safe to Spend" hero tiles — the ring carries the story,
//  the numbers are the detail.
//
//  Mapping (the app is envelope-based, not a top-down monthly budget):
//    • Available = safe to spend now (day-to-day spending envelopes).
//    • Budget    = every dollar that has a job (all envelope balances).
//    • Allocated = Budget − Available (money committed to bills and goals).
//  The ring is point-in-time (envelope balances are cumulative), so it is not
//  scoped by the dashboard's month selector.
//

import SwiftUI

struct BudgetRingCard: View {
    let envelopes: [Envelope]
    let transactions: [Transaction]
    var onDistribute: (() -> Void)?

    private var available: Decimal { BudgetMath.safeToSpend(envelopes) }
    private var budget: Decimal { envelopes.reduce(0) { $0 + BudgetMath.envelopeBalance($1) } }
    private var allocated: Decimal { budget - available }
    private var toBeBudgeted: Decimal { BudgetMath.toBeBudgeted(transactions: transactions) }

    private var fill: Double {
        guard budget > 0 else { return 0 }
        return (available / budget).asDouble
    }

    private var availableColor: Color {
        if available > 0 { .primary }
        else if available < 0 { Color.decrease }
        else { .secondary }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: fill,
                             colors: available < 0 ? [Color.decrease, Color.decrease] : [.aqua, .deepTeal])
                VStack(spacing: 2) {
                    Text("Left to spend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(available.asCurrency)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(availableColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 44)
            }
            .frame(height: 210)

            HStack(spacing: 0) {
                stat("Budget", budget, .primary)
                divider
                stat("Allocated", allocated, .secondary)
                divider
                stat("Available", available, availableColor)
            }

            if toBeBudgeted > 0, let onDistribute {
                Button(action: onDistribute) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.branch")
                        Text("\(toBeBudgeted.asCurrency) to give a job")
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .dashboardCard()
        .accessibilityElement(children: .contain)
    }

    private func stat(_ label: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 28)
    }
}

#Preview {
    let envelopes = [
        Envelope(name: "Groceries", kind: .spending),
        Envelope(name: "Rent", kind: .bill),
        Envelope(name: "Savings", kind: .goal),
    ]
    return BudgetRingCard(envelopes: envelopes, transactions: [])
        .padding()
        .background(Color(.systemGroupedBackground))
}
