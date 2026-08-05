//
//  AccountEditView.swift
//  Liquid
//
//  Create or rename an account (spec FR-1).
//

import SwiftUI

struct AccountEditView: View {
    let target: AccountEditTarget
    let repository: SwiftDataBudgetRepository

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
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
                        .submitLabel(.done)
                        .onSubmit(save)
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
            .onAppear {
                if case let .existing(account) = target {
                    name = account.name
                }
                nameFocused = true
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch target {
        case .new:
            _ = repository.createAccount(name: trimmed)
        case let .existing(account):
            repository.renameAccount(account, to: trimmed)
        }
        dismiss()
    }
}
