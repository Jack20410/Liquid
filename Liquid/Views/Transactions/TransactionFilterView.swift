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
    /// nil means "any type".
    var type: TransactionType?
    /// nil means "any account" (matches either side of a transfer).
    var accountID: UUID?

    var isActive: Bool { useDateRange || envelopeID != nil || type != nil || accountID != nil }

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
        if let type {
            guard tx.type == type else { return false }
        }
        if let accountID {
            guard tx.account?.id == accountID || tx.toAccount?.id == accountID else { return false }
        }
        return true
    }
}

struct TransactionFilterView: View {
    @Binding var filter: TransactionFilter
    let envelopes: [Envelope]
    let accounts: [Account]

    @Environment(\.dismiss) private var dismiss

    /// Types a person can filter by (allocations are system-generated, so hidden).
    private let filterableTypes: [TransactionType] = [.expense, .income, .transfer]

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

                Section("Type") {
                    Picker("Type", selection: $filter.type) {
                        Text("Any").tag(TransactionType?.none)
                        ForEach(filterableTypes) { type in
                            Text(type.displayName).tag(TransactionType?.some(type))
                        }
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

                Section("Account") {
                    Picker("Account", selection: $filter.accountID) {
                        Text("Any").tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(UUID?.some(account.id))
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
