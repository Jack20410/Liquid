//
//  AccountEditView.swift
//  Liquid
//
//  Create or edit an account: name, type, bank (institution), and — for credit
//  cards — a credit limit (spec FR-1).
//

import SwiftUI
import SwiftData

struct AccountEditView: View {
    let target: AccountEditTarget
    let repository: SwiftDataBudgetRepository

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Institution.name) private var institutions: [Institution]

    @State private var name: String = ""
    @State private var type: AccountType = .checking
    @State private var creditLimit: Decimal?
    @State private var institutionID: UUID?
    @State private var newBankName: String = ""
    @FocusState private var nameFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Checking", text: $name)
                        .focused($nameFocused)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                }

                if type.usesCreditLimit {
                    Section {
                        CurrencyField(title: "No limit", amount: $creditLimit)
                    } header: {
                        Text("Credit Limit")
                    } footer: {
                        Text("Charges reduce your available credit; pay the balance to restore it.")
                    }
                }

                Section {
                    Picker("Bank", selection: $institutionID) {
                        Text("None").tag(UUID?.none)
                        ForEach(institutions) { bank in
                            Text(bank.name).tag(UUID?.some(bank.id))
                        }
                    }
                    TextField("Or add a new bank", text: $newBankName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Bank")
                } footer: {
                    if !newBankName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("A new bank “\(newBankName)” will be created and used.")
                    }
                }
            }
            .navigationTitle(isNew ? "New Account" : "Edit Account")
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
        }
    }

    private func load() {
        if case let .existing(account) = target {
            name = account.name
            type = account.type
            creditLimit = account.creditLimit
            institutionID = account.institution?.id
        } else {
            nameFocused = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let institution = resolveInstitution()

        switch target {
        case .new:
            repository.createAccount(name: trimmed, type: type,
                                     creditLimit: creditLimit, institution: institution)
        case let .existing(account):
            repository.updateAccount(account, name: trimmed, type: type,
                                     creditLimit: creditLimit, institution: institution)
        }
        dismiss()
    }

    /// A newly-typed bank name wins; otherwise the picked bank (matched by id).
    private func resolveInstitution() -> Institution? {
        let typed = newBankName.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty {
            if let existing = institutions.first(where: { $0.name.caseInsensitiveCompare(typed) == .orderedSame }) {
                return existing
            }
            return repository.createInstitution(name: typed)
        }
        return institutions.first { $0.id == institutionID }
    }
}
