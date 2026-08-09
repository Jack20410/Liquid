//
//  RootTabView.swift
//  Liquid
//
//  Primary navigation. The Dashboard is the first thing the user sees and links
//  into the other tabs; Distribute Paycheck remains a placeholder for the
//  follow-up (its engine + math already exist).
//

import SwiftUI
import SwiftData

/// The app's top-level destinations. Dashboard cards use this to jump the user
/// straight to the relevant tab.
enum AppTab: Hashable {
    case dashboard, accounts, envelopes, transactions, distribute
}

struct RootTabView: View {
    @State private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            Tab("Dashboard", systemImage: "square.grid.2x2", value: .dashboard) {
                DashboardView(selectedTab: $selection)
            }
            Tab("Accounts", systemImage: "building.columns", value: .accounts) {
                AccountsView()
            }
            Tab("Envelopes", systemImage: "tray.full", value: .envelopes) {
                EnvelopesView()
            }
            Tab("Transactions", systemImage: "list.bullet.rectangle", value: .transactions) {
                TransactionsView()
            }
            Tab("Distribute", systemImage: "arrow.branch", value: .distribute) {
                DistributePaycheckView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Account.self, Envelope.self, Transaction.self, AllocationRule.self],
                        inMemory: true)
}
