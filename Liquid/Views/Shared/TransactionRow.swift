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
    /// Hide the date when the list is already grouped by day.
    var showsDate: Bool = true
    /// Category color for the leading badge; when nil, a sensible color is derived
    /// from the transaction's type/envelope.
    var categoryColor: Color?

    private var badgeColor: Color {
        categoryColor ?? CategoryStyle.color(for: transaction, categoryColors: [:])
    }

    /// The metadata line, composed so it never starts with a stray separator.
    private var metadata: String {
        var parts: [String] = []
        if showsDate {
            parts.append(transaction.date.formatted(.dateTime.month().day().year()))
        }
        if transaction.type == .transfer {
            parts.append("\(transaction.account?.name ?? "?") → \(transaction.toAccount?.name ?? "?")")
        } else {
            if showsEnvelope, let envelope = transaction.envelope { parts.append(envelope.name) }
            if let account = transaction.account { parts.append(account.name) }
        }
        return parts.joined(separator: " · ")
    }

    private var signedColor: Color {
        switch transaction.type {
        case .income: Color.increase
        case .expense: .primary
        case .allocation: Color.accentColor
        case .transfer: Color.accentColor
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
        HStack(spacing: 12) {
            CategoryBadge(systemImage: CategoryStyle.icon(for: transaction), color: badgeColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note.isEmpty ? transaction.type.displayName : transaction.note)
                    .lineLimit(1)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(amountText)
                .foregroundStyle(signedColor)
                .monospacedDigit()
        }
    }
}
