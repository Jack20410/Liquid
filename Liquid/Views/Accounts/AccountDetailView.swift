//
//  AccountDetailView.swift
//  Liquid
//
//  A single account's statement: its balance (or, for a credit card, amount owed,
//  available credit, and utilization), a Pay Balance action for cards, and the
//  full history of transactions that touched it.
//

import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let account: Account
    let repository: SwiftDataBudgetRepository

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]

    @State private var payingBalance = false

    /// Everything that touched this account: its own transactions plus transfers
    /// where it is the destination, newest first.
    private var history: [Transaction] {
        (account.transactions + account.incomingTransfers)
            .sorted { $0.date > $1.date }
    }

    private var isCreditCard: Bool { account.type.isLiability }

    /// Asset accounts the user could pay a card from.
    private var payFromAccounts: [Account] {
        accounts.filter { !$0.type.isLiability && $0.id != account.id }
    }

    var body: some View {
        List {
            Section {
                header
            }

            if isCreditCard, BudgetMath.amountOwed(account) > 0, !payFromAccounts.isEmpty {
                Section {
                    Button {
                        payingBalance = true
                    } label: {
                        Label("Pay Balance", systemImage: "arrow.left.arrow.right")
                    }
                }
            }

            Section("History") {
                if history.isEmpty {
                    Text("No transactions yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { tx in
                        TransactionRow(transaction: tx)
                    }
                }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $payingBalance) {
            TransactionEditView(
                target: .new,
                repository: repository,
                accounts: accounts,
                envelopes: envelopes,
                prefill: .init(type: .transfer,
                               toAccountID: account.id,
                               amount: BudgetMath.amountOwed(account))
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        if isCreditCard {
            let owed = BudgetMath.amountOwed(account)
            VStack(alignment: .leading, spacing: 8) {
                Text("Owed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(owed.asCurrency)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(owed > 0 ? .red : .primary)
                if let available = BudgetMath.availableCredit(account), let limit = account.creditLimit {
                    if let utilization = BudgetMath.creditUtilization(account) {
                        ProgressView(value: utilization) {
                            Text("\(available.asCurrency) available of \(limit.asCurrency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tint(utilization > 0.7 ? .red : .accentColor)
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            let balance = BudgetMath.accountBalance(account)
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(balance.asCurrency)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(balance < 0 ? .red : .primary)
            }
            .padding(.vertical, 4)
        }
    }
}
