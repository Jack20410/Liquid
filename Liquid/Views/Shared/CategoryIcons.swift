//
//  CategoryIcons.swift
//  Liquid
//
//  The icon vocabulary for budget categories: a short, opinionated list of the
//  things people actually budget for, plus a name → symbol guess so an envelope
//  looks like itself before anyone opens the picker. Twelve envelopes all drawing
//  the same shopping cart is a list you have to read word by word; a glyph per
//  category makes it scannable.
//
//  Deliberately small. A full SF Symbols browser would be a worse experience than
//  twenty good choices, and every symbol here is checked by a test so a typo can
//  never ship as a blank badge.
//

import Foundation

enum CategoryIcon {

    struct Option: Identifiable, Hashable {
        let symbol: String
        /// What this icon is *for*, shown as the picker's accessibility label.
        let label: String
        var id: String { symbol }
    }

    /// The picker's contents, roughly ordered by how often a category comes up in
    /// day-to-day spending.
    static let all: [Option] = [
        Option(symbol: "cart", label: "Groceries"),
        Option(symbol: "fork.knife", label: "Dining"),
        Option(symbol: "cup.and.saucer", label: "Coffee"),
        Option(symbol: "house", label: "Home"),
        Option(symbol: "bolt", label: "Utilities"),
        Option(symbol: "wifi", label: "Internet"),
        Option(symbol: "iphone", label: "Phone"),
        Option(symbol: "fuelpump", label: "Gas"),
        Option(symbol: "car", label: "Transport"),
        Option(symbol: "cross.case", label: "Health"),
        Option(symbol: "figure.run", label: "Fitness"),
        Option(symbol: "bag", label: "Shopping"),
        Option(symbol: "tshirt", label: "Clothes"),
        Option(symbol: "gamecontroller", label: "Fun"),
        Option(symbol: "tv", label: "Streaming"),
        Option(symbol: "music.note", label: "Music"),
        Option(symbol: "airplane", label: "Travel"),
        Option(symbol: "book", label: "Education"),
        Option(symbol: "pawprint", label: "Pets"),
        Option(symbol: "gift", label: "Gifts"),
        Option(symbol: "banknote", label: "Savings"),
        Option(symbol: "person.2", label: "Friends"),
    ]

    /// Keyword → symbol, matched in order: the first entry with a matching keyword
    /// wins, so more specific categories come first. Matching is word-based (see
    /// `matches(_:keyword:)`) — a plain substring search would read "Pet care" as a
    /// car and "steak" as tea.
    private static let keywords: [(words: [String], symbol: String)] = [
        (["grocer", "supermarket", "market", "food shop"], "cart"),
        (["coffee", "cafe", "café", "espresso", "starbucks"], "cup.and.saucer"),
        (["eating out", "restaurant", "dining", "dinner", "lunch", "takeout", "take-out", "food"], "fork.knife"),
        (["rent", "mortgage", "home", "house", "apartment", "housing"], "house"),
        (["utilit", "electric", "power", "water", "energy", "heating"], "bolt"),
        (["internet", "wifi", "broadband", "wi-fi"], "wifi"),
        (["phone", "mobile", "cell"], "iphone"),
        (["gas", "fuel", "petrol", "charging"], "fuelpump"),
        (["health", "medical", "doctor", "dentist", "pharmacy", "medicine", "insurance"], "cross.case"),
        (["car", "transport", "transit", "train", "uber", "taxi", "parking"], "car"),
        (["gym", "fitness", "workout", "sport", "yoga"], "figure.run"),
        (["clothes", "clothing", "shoes", "apparel"], "tshirt"),
        (["shopping", "amazon", "household", "supplies"], "bag"),
        (["fun", "game", "gaming", "entertainment", "hobby"], "gamecontroller"),
        (["streaming", "netflix", "tv", "movie", "cinema", "subscription"], "tv"),
        (["music", "spotify", "concert"], "music.note"),
        (["travel", "flight", "vacation", "holiday", "trip", "hotel"], "airplane"),
        (["education", "school", "tuition", "course", "book", "study"], "book"),
        (["pet", "dog", "cat", "vet"], "pawprint"),
        (["gift", "present", "charity", "donation"], "gift"),
        (["saving", "invest", "emergency", "fund", "retirement"], "banknote"),
        (["friend", "social", "party", "night out"], "person.2"),
    ]

    /// The best icon for a category name, or `nil` when nothing fits — callers
    /// then fall back to the envelope's kind icon.
    static func suggestion(for name: String) -> String? {
        let folded = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard !folded.isEmpty else { return nil }
        let words = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)

        return keywords.first { entry in
            entry.words.contains { keyword in
                // Phrases ("eating out", "wi-fi") are matched whole; single words
                // are matched word by word.
                if keyword.contains(where: { !$0.isLetter && !$0.isNumber }) {
                    return folded.contains(keyword)
                }
                return words.contains { matches($0, keyword: keyword) }
            }
        }?.symbol
    }

    /// A word matches a keyword when it *is* that keyword, is its simple plural,
    /// or — for keywords long enough that a coincidence is unlikely — starts with
    /// it ("grocer" → "groceries", "utilit" → "utilities"). Short keywords are
    /// held to exact matching, which is what keeps "care" from reading as "car".
    private static func matches(_ word: String, keyword: String) -> Bool {
        word == keyword
            || word == keyword + "s"
            || (keyword.count >= 5 && word.hasPrefix(keyword))
    }
}
