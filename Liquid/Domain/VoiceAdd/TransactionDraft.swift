//
//  TransactionDraft.swift
//  Liquid
//
//  Natural-language transaction capture ("Say it"): the seam types between a spoken
//  sentence and the transaction editor. A `TransactionDraft` is a parsed-but-unsaved
//  transaction the edit sheet pre-fills — nothing is written without the user's
//  review. Kept free of any speech/LLM framework so the domain stays pure and
//  testable; on-device inference lives behind `TransactionParsing`.
//

import Foundation

/// A parsed, not-yet-saved transaction. Every field maps onto what
/// `TransactionEditView` already holds. `amount`/`accountID`/`envelopeID` are
/// optional: a `nil` means "the sentence didn't say, let the user pick in the sheet".
struct TransactionDraft: Equatable {
    var type: TransactionType
    var amount: Decimal?
    var date: Date
    var note: String
    var accountID: UUID?
    var envelopeID: UUID?
}

/// A name→id pair the resolver matches spoken names against (an account or envelope).
struct NamedItem: Equatable {
    let id: UUID
    let name: String
}

/// The user's real accounts and envelopes, handed to the parser so it can match names
/// and (for the LLM) constrain its choices to what actually exists.
struct ParseCatalog {
    let accounts: [NamedItem]
    let envelopes: [NamedItem]
    /// Used when the sentence names no account (the common case).
    let defaultAccountID: UUID?
}

/// Turns natural language into a `TransactionDraft`. The UI depends only on this, so
/// the on-device implementation (or a fake, in tests) is swappable.
protocol TransactionParsing {
    func parse(_ text: String, catalog: ParseCatalog) async throws -> TransactionDraft
}
