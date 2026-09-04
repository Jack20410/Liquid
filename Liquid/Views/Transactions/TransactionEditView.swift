//
//  TransactionEditView.swift
//  Liquid
//
//  Form for entering or editing a transaction; validates required fields
//  (spec UC-1, FR-3–FR-5).
//

import SwiftUI

struct TransactionEditView: View {
    /// Initial values for a brand-new transaction — used by the Pay Balance flow
    /// (a pre-filled transfer) and by natural-language "Say it" capture (a parsed
    /// draft). Ignored when editing an existing one. All fields past `type` default
    /// to nil, so callers set only what they know.
    struct Prefill {
        var type: TransactionType
        var toAccountID: UUID? = nil
        var amount: Decimal? = nil
        var date: Date? = nil
        var note: String? = nil
        var accountID: UUID? = nil
        var envelopeID: UUID? = nil
    }

    let target: TransactionEditTarget
    let repository: SwiftDataBudgetRepository
    let accounts: [Account]
    let envelopes: [Envelope]
    var prefill: Prefill? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType = .expense
    @State private var amount: Decimal?
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var accountID: UUID?
    @State private var toAccountID: UUID?
    @State private var envelopeID: UUID?
    @FocusState private var amountFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    /// Expenses must name the envelope they draw from (spec FR-4). Income and
    /// allocations do not require one here.
    private var requiresEnvelope: Bool { type == .expense }
    private var isTransfer: Bool { type == .transfer }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        if isTransfer {
            guard let accountID, let toAccountID, accountID != toAccountID else { return false }
            return true
        }
        guard accountID != nil else { return false }
        if requiresEnvelope && envelopeID == nil { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Allocations are produced by paycheck distribution, not entered
                    // by hand — offer expense, income, and transfer.
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                        Text("Transfer").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Amount") {
                    CurrencyField(title: "0", amount: $amount, focused: $amountFocused)
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    if isTransfer {
                        Picker("From", selection: $accountID) {
                            Text("Select…").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?.some(account.id))
                            }
                        }
                        Picker("To", selection: $toAccountID) {
                            Text("Select…").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?.some(account.id))
                            }
                        }
                    } else {
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
                    }
                } footer: {
                    if isTransfer, let a = accountID, a == toAccountID {
                        Text("Choose two different accounts.")
                            .foregroundStyle(.orange)
                    } else if requiresEnvelope && envelopes.isEmpty {
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
                if type != .transfer { toAccountID = nil }
            }
        }
    }

    private func load() {
        switch target {
        case .new:
            if let prefill {
                type = prefill.type
                toAccountID = prefill.toAccountID
                amount = prefill.amount
                if let d = prefill.date { date = d }
                if let n = prefill.note { note = n }
                envelopeID = prefill.envelopeID
                // Use the prefilled account if given (Say it); otherwise default to
                // the first eligible account that isn't the target (Pay Balance).
                accountID = prefill.accountID ?? accounts.first { $0.id != prefill.toAccountID }?.id
            } else {
                accountID = accounts.first?.id
                amountFocused = true
            }
        case let .existing(tx):
            type = tx.type == .allocation ? .expense : tx.type
            amount = tx.amount
            date = tx.date
            note = tx.note
            accountID = tx.account?.id
            toAccountID = tx.toAccount?.id
            envelopeID = tx.envelope?.id
        }
    }

    private func save() {
        guard let amount, amount > 0, let accountID else { return }
        let account = accounts.first { $0.id == accountID }

        if isTransfer {
            guard let toAccountID, accountID != toAccountID,
                  let from = account, let to = accounts.first(where: { $0.id == toAccountID })
            else { return }
            switch target {
            case .new:
                repository.addTransfer(amount: amount, date: date, from: from, to: to, note: note)
            case let .existing(tx):
                tx.amount = amount
                tx.date = date
                tx.type = .transfer
                tx.note = note
                tx.account = from
                tx.toAccount = to
                tx.envelope = nil
                repository.save()
            }
            dismiss()
            return
        }

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
            tx.toAccount = nil
            tx.envelope = envelope
            repository.save()
        }
        dismiss()
    }
}
