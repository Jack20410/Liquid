//
//  OnboardingAccountsStep.swift
//  Liquid
//
//  The hands-on Accounts step of onboarding: the user adds their real accounts and
//  cards here, using the same AccountEditView the Accounts tab uses (so there's one
//  editor, not two). Added accounts appear immediately via @Query.
//

import SwiftUI
import SwiftData

struct OnboardingAccountsStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var addingAccount = false

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingHeader(
                    icon: "building.columns.fill",
                    title: "Add your accounts",
                    message: "Add the accounts and cards you actually use — checking, "
                        + "savings, cash, or a credit card.")
                    .padding(.top, 8)

                if accounts.isEmpty {
                    Text("No accounts yet — add your first below.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(accounts) { account in
                            accountRow(account)
                        }
                    }
                }

                Button {
                    addingAccount = true
                } label: {
                    Label("Add account or card", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $addingAccount) {
            AccountEditView(target: .new, repository: repository)
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name).font(.subheadline.weight(.medium))
                Text(subtitle(account)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.increase)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func subtitle(_ account: Account) -> String {
        let type = account.type.displayName
        if let bank = account.institution?.name, !bank.isEmpty {
            return "\(type) · \(bank)"
        }
        return type
    }
}
