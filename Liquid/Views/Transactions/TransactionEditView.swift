//
//  TransactionEditView.swift
//  Liquid
//
//  Form for entering or editing a transaction; validates required fields
//  (spec UC-1, FR-3–FR-5).
//

import SwiftUI

struct TransactionEditView: View {
    let target: TransactionEditTarget
    let repository: SwiftDataBudgetRepository
    let accounts: [Account]
    let envelopes: [Envelope]

    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType = .expense
    @State private var amount: Decimal?
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var accountID: UUID?
    @State private var envelopeID: UUID?
    @FocusState private var amountFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    /// Expenses must name the envelope they draw from (spec FR-4). Income and
    /// allocations do not require one here.
    private var requiresEnvelope: Bool { type == .expense }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        guard accountID != nil else { return false }
        if requiresEnvelope && envelopeID == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        // Allocations are produced by paycheck distribution, not
                        // entered by hand — offer only income and expense.
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Amount") {
                    CurrencyField(title: "0", amount: $amount, focused: $amountFocused)
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Picker("Account", selection: $accountID) {
                        Text("Select…").tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(UUID?.some(account.id))
                        }
                    }

                    if requiresEnvelope {
                        Picker("Envelope", selection: $envelopeID) {
                            Text("Select…").tag(UUID?.none)
                            ForEach(envelopes) { envelope in
                                Text(envelope.name).tag(UUID?.some(envelope.id))
                            }
                        }
                    }
                } footer: {
                    if requiresEnvelope && envelopes.isEmpty {
                        Text("Create an envelope first to assign this expense.")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Note (optional)") {
                    TextField("e.g. Weekly shop", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(isNew ? "New Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: type) {
                if type != .expense { envelopeID = nil }
            }
        }
    }

    private func load() {
        switch target {
        case .new:
            accountID = accounts.first?.id
            amountFocused = true
        case let .existing(tx):
            type = tx.type == .allocation ? .expense : tx.type
            amount = tx.amount
            date = tx.date
            note = tx.note
            accountID = tx.account?.id
            envelopeID = tx.envelope?.id
        }
    }

    private func save() {
        guard let amount, amount > 0, let accountID else { return }
        let account = accounts.first { $0.id == accountID }
        let envelope = requiresEnvelope ? envelopes.first { $0.id == envelopeID } : nil

        switch target {
        case .new:
            repository.addTransaction(amount: amount, date: date, type: type,
                                      note: note, account: account, envelope: envelope)
        case let .existing(tx):
            tx.amount = amount
            tx.date = date
            tx.type = type
            tx.note = note
            tx.account = account
            tx.envelope = envelope
            repository.save()
        }
        dismiss()
    }
}
