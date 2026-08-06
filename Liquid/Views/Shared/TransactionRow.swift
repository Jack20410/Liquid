//
//  TransactionRow.swift
//  Liquid
//
//  Shared row for rendering a transaction in any list (Transactions tab,
//  envelope history). Sign and color derive from the transaction type.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    /// Hide the envelope name when the list is already scoped to one envelope.
    var showsEnvelope: Bool = true

    private var signedColor: Color {
        switch transaction.type {
        case .income: .green
        case .expense: .primary
        case .allocation: .blue
        case .transfer: .blue
        }
    }

    private var amountText: String {
        switch transaction.type {
        case .expense: "−" + transaction.amount.asCurrency
        case .transfer: transaction.amount.asCurrency   // neutral: money moved, not gained/lost
        case .income, .allocation: "+" + transaction.amount.asCurrency
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note.isEmpty ? transaction.type.displayName : transaction.note)
                HStack(spacing: 6) {
                    Text(transaction.date, format: .dateTime.month().day().year())
                    if transaction.type == .transfer {
                        // For a transfer, show the route rather than a single account.
                        Text("· \(transaction.account?.name ?? "?") → \(transaction.toAccount?.name ?? "?")")
                    } else {
                        if showsEnvelope, let envelope = transaction.envelope {
                            Text("· \(envelope.name)")
                        }
                        if let account = transaction.account {
                            Text("· \(account.name)")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amountText)
                .foregroundStyle(signedColor)
                .monospacedDigit()
        }
    }
}
