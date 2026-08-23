//
//  EnvelopesView.swift
//  Liquid
//
//  List of budget categories with balances, targets, and allocation rules
//  (spec FR-7–FR-9, FR-14).
//

import SwiftUI
import SwiftData

struct EnvelopesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]

    @State private var editing: EnvelopeEditTarget?

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    var body: some View {
        NavigationStack {
            Group {
                if envelopes.isEmpty {
                    EmptyStateView(
                        icon: "tray.full",
                        title: "No Envelopes",
                        message: "Create categories like Rent or Groceries to give your money a job.",
                        actionTitle: "Add Envelope",
                        action: { editing = .new }
                    )
                } else {
                    List {
                        ForEach(envelopes) { envelope in
                            NavigationLink {
                                EnvelopeDetailView(envelope: envelope)
                            } label: {
                                EnvelopeRow(envelope: envelope)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    repository.deleteEnvelope(envelope)
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editing = .existing(envelope)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Envelope", systemImage: "plus") { editing = .new }
                }
            }
            .sheet(item: $editing) { target in
                EnvelopeEditView(target: target,
                                 repository: repository,
                                 existingEnvelopes: envelopes)
            }
        }
    }

}

private struct EnvelopeRow: View {
    let envelope: Envelope

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(envelope.name)
                if let rule = envelope.rule {
                    Text(ruleLabel(rule))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                }
                Spacer()
                Text(BudgetMath.envelopeBalance(envelope).asCurrency)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let target = envelope.target, target > 0,
               let progress = BudgetMath.targetProgress(envelope) {
                ProgressView(value: progress) {
                    Text("Target \(target.asCurrency)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func ruleLabel(_ rule: AllocationRule) -> String {
        switch rule.strategy {
        case let .fixed(v): "Fixed \(v.asCurrency)"
        case let .percentage(p): "\((p * 100).formatted())%"
        case let .fillToTarget(t): "Fill → \(t.asCurrency)"
        case .remainder: "Remainder"
        }
    }
}

/// What the edit sheet is currently editing.
enum EnvelopeEditTarget: Identifiable {
    case new
    case existing(Envelope)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(envelope): envelope.id.uuidString
        }
    }
}
