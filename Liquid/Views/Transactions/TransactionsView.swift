//
//  TransactionsView.swift
//  Liquid
//
//  Chronological, day-grouped list of transactions with a header summary, search,
//  and filtering by date range, type, envelope, and account; entry point for
//  adding a transaction (spec FR-3–FR-6).
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
    @State private var searchText = ""

    // Natural-language "Say it" capture: speak → draft → pre-filled editor.
    @State private var showVoiceAdd = false
    @State private var pendingDraft: TransactionDraft?
    @State private var showDraftEditor = false

    private let calendar = Calendar.current

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    private var parseCatalog: ParseCatalog {
        ParseCatalog(
            accounts: accounts.map { NamedItem(id: $0.id, name: $0.name) },
            envelopes: envelopes.map { NamedItem(id: $0.id, name: $0.name) },
            defaultAccountID: accounts.first?.id)
    }

    private func prefill(from draft: TransactionDraft) -> TransactionEditView.Prefill {
        TransactionEditView.Prefill(
            type: draft.type, amount: draft.amount, date: draft.date,
            note: draft.note, accountID: draft.accountID, envelopeID: draft.envelopeID)
    }

    /// Stable per-envelope colors for the category badges.
    private var colorMap: [UUID: Color] { CategoryStyle.colorMap(for: envelopes) }

    private var filtered: [Transaction] {
        transactions.filter { filter.matches($0) && matchesSearch($0) }
    }

    private func matchesSearch(_ tx: Transaction) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        let haystack = [
            tx.note,
            tx.type.displayName,
            tx.envelope?.name ?? "",
            tx.account?.name ?? "",
            tx.toAccount?.name ?? "",
            tx.amount.asCurrency,
        ].joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(q)
    }

    /// The filtered transactions grouped into days, newest day first.
    private var days: [(day: Date, transactions: [Transaction])] {
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
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
                    list
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search transactions")
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
                    // Voice capture, only when on-device intelligence is available.
                    if OnDeviceTransactionParser.isAvailable {
                        Button("Say it", systemImage: "mic.fill") { showVoiceAdd = true }
                            .disabled(accounts.isEmpty)
                    }
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
                TransactionFilterView(filter: $filter, envelopes: envelopes, accounts: accounts)
            }
            // Dismiss the voice sheet first, then open the editor from onDismiss so
            // the two sheets don't compete in the same runloop.
            .sheet(isPresented: $showVoiceAdd, onDismiss: {
                if pendingDraft != nil { showDraftEditor = true }
            }) {
                VoiceAddView(catalog: parseCatalog) { draft in
                    pendingDraft = draft
                    showVoiceAdd = false
                }
            }
            .sheet(isPresented: $showDraftEditor, onDismiss: { pendingDraft = nil }) {
                if let draft = pendingDraft {
                    TransactionEditView(target: .new, repository: repository,
                                        accounts: accounts, envelopes: envelopes,
                                        prefill: prefill(from: draft))
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                TransactionsSummaryCard(transactions: filtered)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if filtered.isEmpty {
                ContentUnavailableView("No matches", systemImage: "line.3.horizontal.decrease.circle")
            }

            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.transactions) { tx in
                        Button {
                            editing = .existing(tx)
                        } label: {
                            TransactionRow(transaction: tx,
                                           showsDate: false,
                                           categoryColor: CategoryStyle.color(for: tx, categoryColors: colorMap))
                        }
                        .tint(.primary)
                    }
                    .onDelete { offsets in delete(group.transactions, at: offsets) }
                } header: {
                    dayHeader(group.day, transactions: group.transactions)
                }
            }
        }
    }

    private func dayHeader(_ day: Date, transactions txs: [Transaction]) -> some View {
        let income = txs.filter { $0.type == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let spending = txs.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        return HStack(spacing: 8) {
            Text(dayLabel(day))
            Spacer()
            if income > 0 {
                Text("+\(income.asCurrency)").foregroundStyle(Color.increase)
            }
            if spending > 0 {
                Text("−\(spending.asCurrency)").foregroundStyle(Color.decrease)
            }
        }
        .font(.caption)
        .monospacedDigit()
        .textCase(nil)
    }

    private func dayLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func delete(_ txs: [Transaction], at offsets: IndexSet) {
        for index in offsets {
            repository.deleteTransaction(txs[index])
        }
    }
}

// MARK: - Header summary

/// A compact activity summary above the list: In/Out totals for the visible set
/// plus a sparkline of daily net.
private struct TransactionsSummaryCard: View {
    let transactions: [Transaction]

    private var income: Decimal {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    private var spending: Decimal {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// Daily net (income − spending) across the visible set, oldest first.
    private var netSeries: [Double] {
        BudgetMath.dailySummaries(transactions)
            .values
            .sorted { $0.day < $1.day }
            .map { $0.net.asDouble }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                total("In", income, .increase)
                total("Out", spending, .decrease)
                total("Net", income - spending, (income - spending) < 0 ? .decrease : .primary)
            }
            if netSeries.count > 1 {
                Sparkline(values: netSeries, tint: .accentColor)
                    .frame(height: 40)
            }
        }
        .dashboardCard()
    }

    private func total(_ title: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.asCurrency)
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
