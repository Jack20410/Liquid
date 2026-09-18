//
//  CategoryIconTests.swift
//  LiquidTests
//
//  Tests for the envelope icon vocabulary and the stored-color round trip. The
//  symbol check is the important one: a typo'd SF Symbol name compiles fine and
//  ships as a blank badge, so every option is resolved here instead.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Liquid

struct CategoryIconTests {

    @Test func everyOptionResolvesToARealSymbol() {
        for option in CategoryIcon.all {
            #expect(UIImage(systemName: option.symbol) != nil,
                    "\(option.symbol) (\(option.label)) is not an SF Symbol")
        }
    }

    @Test func optionsAreUnique() {
        let symbols = CategoryIcon.all.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test func suggestsIconsForEverydayCategories() {
        #expect(CategoryIcon.suggestion(for: "Groceries") == "cart")
        #expect(CategoryIcon.suggestion(for: "Coffee") == "cup.and.saucer")
        #expect(CategoryIcon.suggestion(for: "Eating Out") == "fork.knife")
        #expect(CategoryIcon.suggestion(for: "Lunch") == "fork.knife")
        #expect(CategoryIcon.suggestion(for: "Gas") == "fuelpump")
        #expect(CategoryIcon.suggestion(for: "Rent") == "house")
        #expect(CategoryIcon.suggestion(for: "Gym") == "figure.run")
        #expect(CategoryIcon.suggestion(for: "YouTube Music") == "music.note")
        #expect(CategoryIcon.suggestion(for: "Invest") == "banknote")
    }

    @Test func suggestionIsCaseAndAccentInsensitive() {
        #expect(CategoryIcon.suggestion(for: "GROCERIES") == "cart")
        #expect(CategoryIcon.suggestion(for: "café") == "cup.and.saucer")
    }

    /// Matching is word-based precisely so short keywords can't hide inside longer
    /// words — "Pet care" is not a car, and "steak" is not tea.
    @Test func suggestionAvoidsAccidentalSubstringMatches() {
        #expect(CategoryIcon.suggestion(for: "Pet care") == "pawprint")
        #expect(CategoryIcon.suggestion(for: "Health care") == "cross.case")
        #expect(CategoryIcon.suggestion(for: "Steak night") != "cup.and.saucer")
        #expect(CategoryIcon.suggestion(for: "Las Vegas") != "fuelpump")
    }

    /// Plurals and longer forms of a keyword still match.
    @Test func suggestionHandlesPluralsAndLongerForms() {
        #expect(CategoryIcon.suggestion(for: "Cars") == "car")
        #expect(CategoryIcon.suggestion(for: "Books") == "book")
        #expect(CategoryIcon.suggestion(for: "Utilities") == "bolt")
        #expect(CategoryIcon.suggestion(for: "Transportation") == "car")
        #expect(CategoryIcon.suggestion(for: "Savings") == "banknote")
    }

    @Test func suggestionIsNilWhenNothingFits() {
        #expect(CategoryIcon.suggestion(for: "") == nil)
        #expect(CategoryIcon.suggestion(for: "Zzyzx") == nil)
    }

    // MARK: Stored colors

    @Test func paletteRoundTripsThroughItsStoredForm() {
        #expect(Color.categoryPaletteHexStrings.count == Color.categoryPalette.count)
        for (hex, color) in zip(Color.categoryPaletteHexStrings, Color.categoryPalette) {
            #expect(Color(hexString: hex) == color)
        }
    }

    @Test func hexStringRejectsMalformedValues() {
        #expect(Color(hexString: "0E7490") != nil)
        #expect(Color(hexString: "#0E7490") != nil)
        #expect(Color(hexString: "0E749") == nil)      // too short
        #expect(Color(hexString: "ZZZZZZ") == nil)     // not hex
        #expect(Color(hexString: "") == nil)
    }
}
