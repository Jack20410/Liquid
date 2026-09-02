//
//  OnDeviceTransactionParser.swift
//  Liquid
//
//  The only file that touches Apple's on-device language model. It asks the model to
//  extract the fields of one transaction from a sentence (guided generation → a typed
//  struct, never free text we'd have to parse), then hands those raw fields to the
//  pure TransactionDraftResolver. Runs entirely on device — no network — so it keeps
//  Liquid's "private by construction" promise intact.
//
//  Availability is gated: `isAvailable` is false on hardware without Apple
//  Intelligence, and the UI hides the feature entirely in that case.
//

import Foundation
import FoundationModels

/// The model's raw view of a transaction. Names are plain (non-optional) strings —
/// empty means "not mentioned" — which the model handles more reliably than nullable
/// fields; the parser converts empty → nil before resolving.
@Generable(description: "A single personal-finance transaction described in a sentence.")
struct ParsedTransaction {
    @Guide(description: "Either 'expense' for money spent or 'income' for money received.",
           .anyOf(["expense", "income"]))
    var kind: String

    @Guide(description: "The amount of money, as a positive number.", .minimum(Decimal(0)))
    var amount: Decimal

    @Guide(description: "How many days before today it happened: 0 today, 1 yesterday.",
           .range(0...365))
    var daysAgo: Int

    @Guide(description: "The spending category name if one is mentioned, otherwise empty.")
    var envelopeName: String

    @Guide(description: "The account or card name if one is mentioned, otherwise empty.")
    var accountName: String

    @Guide(description: "A short label for the transaction, usually the merchant.")
    var note: String
}

/// On-device, LLM-backed implementation of `TransactionParsing`.
struct OnDeviceTransactionParser: TransactionParsing {

    enum ParseError: LocalizedError {
        case unavailable
        case couldNotUnderstand

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "On-device intelligence isn't available on this device."
            case .couldNotUnderstand:
                "Couldn't turn that into a transaction. Try rephrasing, e.g. \"spent 12 on coffee\"."
            }
        }
    }

    /// Whether the on-device model is ready. The UI shows the feature only when true.
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func parse(_ text: String, catalog: ParseCatalog) async throws -> TransactionDraft {
        guard Self.isAvailable else { throw ParseError.unavailable }

        let session = LanguageModelSession(instructions: instructions(for: catalog))
        let parsed: ParsedTransaction
        do {
            let response = try await session.respond(
                to: text,
                generating: ParsedTransaction.self,
                options: GenerationOptions(temperature: 0))
            parsed = response.content
        } catch {
            throw ParseError.couldNotUnderstand
        }

        let fields = ParsedFields(
            kind: parsed.kind,
            amount: parsed.amount,
            daysAgo: parsed.daysAgo,
            envelopeName: blankToNil(parsed.envelopeName),
            accountName: blankToNil(parsed.accountName),
            note: parsed.note)

        return TransactionDraftResolver.resolve(fields, catalog: catalog)
    }

    private func instructions(for catalog: ParseCatalog) -> String {
        let envelopes = catalog.envelopes.map(\.name).joined(separator: ", ")
        let accounts = catalog.accounts.map(\.name).joined(separator: ", ")
        return """
        Extract exactly one personal-finance transaction from the user's sentence.
        Spending categories that exist: \(envelopes.isEmpty ? "(none)" : envelopes).
        Accounts that exist: \(accounts.isEmpty ? "(none)" : accounts).
        Only use a category or account name from those lists. If none clearly fits,
        leave that field empty. Do not invent amounts, dates, or names.
        """
    }

    private func blankToNil(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
