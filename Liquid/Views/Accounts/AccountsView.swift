//
//  AccountsView.swift
//  Liquid
//
//  Manage accounts and view their balances (spec FR-1, FR-2).
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var editing: AccountEditTarget?

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    EmptyStateView(
                        icon: "building.columns",
                        title: "No Accounts",
                        message: "Add a place your money lives, like Checking or Cash.",
                        actionTitle: "Add Account",
                        action: { editing = .new }
                    )
                } else {
                    List {
                        Section {
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text(BudgetMath.totalAccountsBalance(accounts).asCurrency)
                                    .font(.headline)
                            }
                        }
                        Section("Accounts") {
                            ForEach(accounts) { account in
                                Button {
                                    editing = .existing(account)
                                } label: {
                                    AccountRow(account: account)
                                }
                                .tint(.primary)
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Account", systemImage: "plus") { editing = .new }
                }
            }
            .sheet(item: $editing) { target in
                AccountEditView(target: target, repository: repository)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            repository.deleteAccount(accounts[index])
        }
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            Text(account.name)
            Spacer()
            Text(BudgetMath.accountBalance(account).asCurrency)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// What the edit sheet is currently editing.
enum AccountEditTarget: Identifiable {
    case new
    case existing(Account)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(account): account.id.uuidString
        }
    }
}
