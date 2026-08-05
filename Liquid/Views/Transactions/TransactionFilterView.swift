//
//  TransactionFilterView.swift
//  Liquid
//
//  Filtering transactions by date range and envelope (spec FR-6).
//

import SwiftUI

/// Filter criteria applied in-memory to the transaction list.
struct TransactionFilter: Equatable {
    var useDateRange = false
    var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var endDate = Date.now
    /// nil means "any envelope".
    var envelopeID: UUID?

    var isActive: Bool { useDateRange || envelopeID != nil }

    func matches(_ tx: Transaction) -> Bool {
        if useDateRange {
            let start = Calendar.current.startOfDay(for: startDate)
            let end = Calendar.current.date(byAdding: .day, value: 1,
                                            to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            guard tx.date >= start && tx.date < end else { return false }
        }
        if let envelopeID {
            guard tx.envelope?.id == envelopeID else { return false }
        }
        return true
    }
}

struct TransactionFilterView: View {
    @Binding var filter: TransactionFilter
    let envelopes: [Envelope]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Toggle("Filter by date", isOn: $filter.useDateRange)
                    if filter.useDateRange {
                        DatePicker("From", selection: $filter.startDate, displayedComponents: .date)
                        DatePicker("To", selection: $filter.endDate, displayedComponents: .date)
                    }
                }

                Section("Envelope") {
                    Picker("Envelope", selection: $filter.envelopeID) {
                        Text("Any").tag(UUID?.none)
                        ForEach(envelopes) { envelope in
                            Text(envelope.name).tag(UUID?.some(envelope.id))
                        }
                    }
                }

                if filter.isActive {
                    Section {
                        Button("Clear all filters", role: .destructive) {
                            filter = TransactionFilter()
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
