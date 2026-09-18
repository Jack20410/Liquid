//
//  DistributionEventDetailView.swift
//  Liquid
//
//  Drill-in for a single past distribution: the paycheck total, when and where it
//  landed, the same Sankey-style flow scoped to just this event, and the exact
//  amount that went to each envelope.
//

import SwiftUI

struct DistributionEventDetailView: View {
    let event: BudgetMath.DistributionEvent

    private var slices: [DistributionFlowView.Slice] {
        event.shares.enumerated().map { index, share in
            .init(id: share.id, name: share.name, amount: share.amount,
                  color: FlowPalette.color(at: index))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                flow
                lines
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Distribution")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(spacing: 6) {
            Text(event.total.asCurrency)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(event.date.formatted(date: .complete, time: .omitted))
                .font(.subheadline).foregroundStyle(.secondary)
            if let account = event.accountName {
                Label(account, systemImage: "building.columns")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }

    private var flow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where it went").font(.headline)
            DistributionFlowView(slices: slices)
        }
        .dashboardCard()
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Envelopes")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(Array(event.shares.enumerated()), id: \.element.id) { index, share in
                HStack(spacing: 10) {
                    Circle().fill(FlowPalette.color(at: index))
                        .frame(width: 10, height: 10)
                    Text(share.name)
                    Spacer()
                    Text(share.amount.asCurrency)
                        .fontWeight(.medium).monospacedDigit()
                }
                .padding(.vertical, 10)
                if index < event.shares.count - 1 { Divider() }
            }
        }
        .dashboardCard()
    }
}
