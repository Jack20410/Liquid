//
//  CategoryBadge.swift
//  Liquid
//
//  A small SF Symbol in a tinted circle — the glanceable category marker used on
//  transaction rows and envelope rows so a long list reads by color + icon, not
//  just text. Colors are never stored on the model; `CategoryStyle` assigns them
//  from the shared palette by a stable index (never a UUID hash, which collided).
//

import SwiftUI

struct CategoryBadge: View {
    let systemImage: String
    var color: Color = .accentColor
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: .circle)
    }
}

/// Resolves the icon and color for a transaction or envelope. Category colors come
/// from a stable `[Envelope.ID: Color]` map the caller builds once per list.
enum CategoryStyle {
    private static let palette = Color.categoryPalette

    /// A stable color per envelope, assigned by alphabetical index so the same
    /// envelope always gets the same hue across a list (and across launches).
    static func colorMap(for envelopes: [Envelope]) -> [UUID: Color] {
        let sorted = envelopes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var map: [UUID: Color] = [:]
        for (index, envelope) in sorted.enumerated() {
            map[envelope.id] = palette[index % palette.count]
        }
        return map
    }

    // MARK: Transactions

    static func icon(for transaction: Transaction) -> String {
        switch transaction.type {
        case .income: "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right"
        case .expense, .allocation:
            transaction.envelope?.kind.icon ?? transaction.account?.type.icon ?? "cart"
        }
    }

    static func color(for transaction: Transaction, categoryColors: [UUID: Color]) -> Color {
        switch transaction.type {
        case .income: return .increase
        case .transfer: return .accentColor
        case .expense, .allocation:
            if let id = transaction.envelope?.id, let color = categoryColors[id] { return color }
            return .secondary
        }
    }

    // MARK: Envelopes

    static func icon(for envelope: Envelope) -> String { envelope.kind.icon }

    static func color(for envelope: Envelope, categoryColors: [UUID: Color]) -> Color {
        categoryColors[envelope.id] ?? fallbackColor(for: envelope.kind)
    }

    private static func fallbackColor(for kind: EnvelopeKind) -> Color {
        switch kind {
        case .spending: .aqua
        case .bill: .deepTeal
        case .goal: .seafoam
        }
    }
}
