//
//  TransactionsView.swift
//  Liquid
//
//  Chronological list of transactions with filtering by date range and envelope;
//  entry point for adding a transaction (spec FR-3–FR-6).
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var editing: TransactionEditTarget?
    @State private var filter = TransactionFilter()
    @State private var showFilters = false

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    private var filtered: [Transaction] {
        transactions.filter { filter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "No Transactions",
                        message: accounts.isEmpty
                            ? "Add an account first, then record income and expenses here."
                            : "Record your first income or expense.",
                        actionTitle: accounts.isEmpty ? nil : "Add Transaction",
                        action: accounts.isEmpty ? nil : { editing = .new }
                    )
                } else {
                    List {
                        if filter.isActive {
                            Section {
                                Button("Clear filters", systemImage: "xmark.circle") {
                                    filter = TransactionFilter()
                                }
                            }
                        }
                        ForEach(filtered) { tx in
                            Button {
                                editing = .existing(tx)
                            } label: {
                                TransactionRow(transaction: tx)
                            }
                            .tint(.primary)
                        }
                        .onDelete(perform: delete)

                        if filtered.isEmpty {
                            ContentUnavailableView("No matches", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Filter", systemImage: filter.isActive
                           ? "line.3.horizontal.decrease.circle.fill"
                           : "line.3.horizontal.decrease.circle") {
                        showFilters = true
                    }
                    .disabled(transactions.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Transaction", systemImage: "plus") { editing = .new }
                        .disabled(accounts.isEmpty)
                }
            }
            .sheet(item: $editing) { target in
                TransactionEditView(target: target, repository: repository,
                                    accounts: accounts, envelopes: envelopes)
            }
            .sheet(isPresented: $showFilters) {
                TransactionFilterView(filter: $filter, envelopes: envelopes)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = filtered
        for index in offsets {
            repository.deleteTransaction(items[index])
        }
    }
}

/// What the edit sheet is currently editing.
enum TransactionEditTarget: Identifiable {
    case new
    case existing(Transaction)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(tx): tx.id.uuidString
        }
    }
}
