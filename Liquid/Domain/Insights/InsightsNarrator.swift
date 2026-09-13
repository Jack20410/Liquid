//
//  InsightsNarrator.swift
//  Liquid
//
//  Rephrases already-computed insight sentences into warmer prose using Apple's
//  on-device language model. The model handles language, never money: every
//  figure comes from InsightsEngine.
//
//  Two guardrails, because a number check alone is not enough. A small model
//  given several facts at once will happily keep every number and still
//  recombine them into false claims ("on track to spend $2,000" from a fact
//  about unbudgeted income). So:
//    1. Structure — guided generation must return exactly one rewritten sentence
//       per input fact, in order, so each fact is rephrased in isolation and
//       cannot borrow words or numbers from another.
//    2. Numbers — each rewritten sentence must still contain its own fact's
//       numbers (InsightsGrounding); a changed or dropped figure rejects the
//       narration and the card shows the deterministic sentences instead.
//  Runs entirely on device — no network.
//

import Foundation
import FoundationModels

/// Produces a narrative from grounded fact sentences. The UI depends only on
/// this, so the on-device implementation is swappable (or a fake, in tests).
protocol InsightsNarrating {
    func narrate(_ facts: [String]) async throws -> String
}

/// Pure guardrails: did the numbers survive, sentence by sentence?
enum InsightsGrounding {

    /// True when there is exactly one rewritten sentence per fact and each one
    /// preserves the numbers of the fact at the same index. Catches both a
    /// changed figure and the recombination failure (numbers shuffled between
    /// facts), which a whole-text check would miss.
    static func sentencesPreserveNumbers(_ sentences: [String], facts: [String]) -> Bool {
        guard sentences.count == facts.count else { return false }
        return zip(sentences, facts).allSatisfy { sentence, fact in
            preservesNumbers(in: sentence, facts: [fact])
        }
    }

    /// True when the integer part of every numeric token in `facts` appears in
    /// `narration` (grouping commas ignored, so "$2,000.00" → "2000" still counts
    /// if the model wrote "$2,000"). Dropped cents are tolerated; a changed or
    /// missing magnitude is not.
    static func preservesNumbers(in narration: String, facts: [String]) -> Bool {
        let haystack = narration.replacingOccurrences(of: ",", with: "")
        return facts.flatMap(numericTokens).allSatisfy { token in
            let integerPart = token.split(separator: ".", maxSplits: 1).first.map(String.init) ?? token
            return haystack.contains(integerPart.replacingOccurrences(of: ",", with: ""))
        }
    }

    /// Maximal runs like "2,000.00", "669.46", "20" — trailing punctuation trimmed.
    static func numericTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            while let last = current.last, last == "," || last == "." { current.removeLast() }
            if !current.isEmpty { tokens.append(current) }
            current = ""
        }
        for ch in text {
            if ch.isNumber || ((ch == "," || ch == ".") && !current.isEmpty) {
                current.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }
}

/// The model's structured output: one rewrite per fact, same order. Guided
/// generation enforces the shape; the count is validated after generation.
@Generable(description: "Friendly rewrites of personal-budget facts, one sentence per fact, in the same order.")
struct NarratedFacts {
    @Guide(description: "Exactly one rewritten sentence for each input fact, in the same order. Each keeps its fact's numbers, percentages, and names unchanged.")
    var sentences: [String]
}

/// On-device, Foundation Models-backed narrator.
struct OnDeviceInsightsNarrator: InsightsNarrating {

    enum NarrationError: Error {
        case unavailable
        case ungrounded
    }

    /// Whether the on-device model is ready. The card narrates only when true and
    /// otherwise shows the deterministic sentences.
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func narrate(_ facts: [String]) async throws -> String {
        guard Self.isAvailable, !facts.isEmpty else { throw NarrationError.unavailable }

        let session = LanguageModelSession(instructions: """
            You rewrite short personal-budget facts to sound warm and natural, in \
            the second person, for a dashboard card. Rewrite each fact as exactly \
            one sentence, on its own, and return them in the same order — never \
            merge facts or move a number from one fact to another. Keep every \
            number, percentage, and name exactly as given. Envelope, category, and \
            account names are proper names: repeat them verbatim and never \
            reinterpret them (a category called "Savings" is a spending category, \
            not money saved). Do not add, change, or invent any figure, and do not \
            give advice beyond the facts. No headings, bullets, or emoji.
            """)
        let prompt = "Facts:\n" + facts.enumerated().map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let response = try await session.respond(
            to: prompt,
            generating: NarratedFacts.self,
            options: GenerationOptions(temperature: 0.2))
        let sentences = response.content.sentences.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard InsightsGrounding.sentencesPreserveNumbers(sentences, facts: facts) else {
            throw NarrationError.ungrounded
        }
        return sentences.joined(separator: " ")
    }
}
