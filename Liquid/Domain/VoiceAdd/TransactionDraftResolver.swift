//
//  TransactionDraftResolver.swift
//  Liquid
//
//  The pure heart of natural-language capture: it maps the raw fields a language
//  model extracts onto the user's real data, with no model or SwiftData in sight —
//  so it's fully unit-testable (see TransactionDraftResolverTests), in the spirit of
//  DistributionEngine. Unmatched names degrade to nil rather than guessing, leaving
//  the choice to the user in the edit sheet.
//

import Foundation

/// Raw fields as extracted from language, before matching to the user's accounts and
/// envelopes. Framework-free on purpose: both the on-device parser and the tests
/// construct it directly.
struct ParsedFields: Equatable {
    var kind: String            // "expense" or "income"
    var amount: Decimal
    var daysAgo: Int            // 0 = today, 1 = yesterday, …
    var envelopeName: String?   // nil = not mentioned
    var accountName: String?    // nil = not mentioned
    var note: String
}

enum TransactionDraftResolver {

    /// Resolve raw parsed fields against the user's catalog into a draft the edit
    /// sheet can present.
    static func resolve(_ fields: ParsedFields, catalog: ParseCatalog,
                        now: Date = .now, calendar: Calendar = .current) -> TransactionDraft {
        let type = transactionType(from: fields.kind)

        let date = calendar.date(byAdding: .day, value: -max(0, fields.daysAgo), to: now) ?? now

        // An envelope only makes sense for an expense; income and everything else
        // ignore it (matching TransactionEditView's own rule).
        let envelopeID = type == .expense
            ? fields.envelopeName.flatMap { match($0, in: catalog.envelopes) }
            : nil

        // A named account wins; otherwise fall back to the user's default account.
        let accountID = fields.accountName.flatMap { match($0, in: catalog.accounts) }
            ?? catalog.defaultAccountID

        // Amounts must be positive to be usable; anything else is left for the user.
        let amount = fields.amount > 0 ? fields.amount : nil

        return TransactionDraft(
            type: type,
            amount: amount,
            date: date,
            note: fields.note.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: accountID,
            envelopeID: envelopeID)
    }

    /// Map a free-text kind to a `TransactionType`; unknown → `.expense` (the common
    /// case, and the safest default since it's the most reviewed in the sheet).
    static func transactionType(from kind: String) -> TransactionType {
        kind.trimmingCharacters(in: .whitespaces).lowercased() == "income" ? .income : .expense
    }

    /// Best-effort name match, case- and diacritic-insensitive: an exact match first,
    /// then a containment match in either direction ("trader joe" ↔ "Trader Joe's"),
    /// else nil.
    static func match(_ name: String, in items: [NamedItem]) -> UUID? {
        let needle = fold(name)
        guard !needle.isEmpty else { return nil }

        if let hit = items.first(where: { fold($0.name) == needle }) {
            return hit.id
        }
        if let hit = items.first(where: {
            let hay = fold($0.name)
            return !hay.isEmpty && (hay.contains(needle) || needle.contains(hay))
        }) {
            return hit.id
        }
        return nil
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
