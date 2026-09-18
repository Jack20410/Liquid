//
//  RecentTransactionsCard.swift
//  Liquid
//
//  The latest few transactions on the dashboard, so the most recent activity is
//  visible at a glance without opening the Transactions tab. Rows reuse the shared
//  TransactionRow; the header taps through to the full list.
//

import SwiftUI

struct RecentTransactionsCard: View {
    /// Transactions in reverse-chronological order (as the dashboard @Query provides).
    let transactions: [Transaction]
    var onOpen: (() -> Void)?

    private static let count = 4

    private var recent: [Transaction] { Array(transactions.prefix(Self.count)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Recent Transactions", onOpen: onOpen) {
                EmptyView()
            }
            VStack(spacing: 12) {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                    TransactionRow(transaction: tx)
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .dashboardCard()
    }
}
