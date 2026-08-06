//
//  AccountsView.swift
//  Liquid
//
//  Manage accounts and view balances, grouped by bank, with a net-worth summary
//  that accounts for credit-card debt (spec FR-1, FR-2).
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

    /// Accounts grouped by bank name; unassigned accounts fall under "Other".
    private var groups: [(bank: String, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts) { $0.institution?.name ?? "" }
        return grouped
            .map { (bank: $0.key, accounts: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                // Real banks first (alphabetical), "Other" (empty key) last.
                if lhs.bank.isEmpty != rhs.bank.isEmpty { return !lhs.bank.isEmpty }
                return lhs.bank < rhs.bank
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    EmptyStateView(
                        icon: "building.columns",
                        title: "No Accounts",
                        message: "Add a place your money lives, like Checking or a credit card.",
                        actionTitle: "Add Account",
                        action: { editing = .new }
                    )
                } else {
                    List {
                        NetWorthSummary(accounts: accounts)

                        ForEach(groups, id: \.bank) { group in
                            Section(group.bank.isEmpty ? "Other" : group.bank) {
                                ForEach(group.accounts) { account in
                                    NavigationLink {
                                        AccountDetailView(account: account, repository: repository)
                                    } label: {
                                        AccountRow(account: account)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            repository.deleteAccount(account)
                                        }
                                        Button("Edit", systemImage: "pencil") {
                                            editing = .existing(account)
                                        }
                                        .tint(.orange)
                                    }
                                }
                            }
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
}

// MARK: - Net worth summary

private struct NetWorthSummary: View {
    let accounts: [Account]

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Net Worth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(BudgetMath.totalAccountsBalance(accounts).asCurrency)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                HStack {
                    subtotal("Assets", BudgetMath.totalAssets(accounts), .green)
                    Spacer()
                    subtotal("Liabilities", BudgetMath.totalLiabilities(accounts), .red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func subtotal(_ title: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.asCurrency)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - Account row

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                Text(account.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if account.type.isLiability {
                creditCardTrailing
            } else {
                Text(BudgetMath.accountBalance(account).asCurrency)
                    .foregroundStyle(BudgetMath.accountBalance(account) < 0 ? .red : .secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var creditCardTrailing: some View {
        let owed = BudgetMath.amountOwed(account)
        VStack(alignment: .trailing, spacing: 3) {
            Text(owed.asCurrency)
                .foregroundStyle(owed > 0 ? .red : .secondary)
                .monospacedDigit()
            if let available = BudgetMath.availableCredit(account), let limit = account.creditLimit {
                Text("\(available.asCurrency) of \(limit.asCurrency)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            if let utilization = BudgetMath.creditUtilization(account) {
                ProgressView(value: utilization)
                    .frame(width: 90)
                    .tint(utilization > 0.7 ? .red : .accentColor)
            }
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
