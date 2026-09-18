//
//  Theme.swift
//  Liquid
//
//  The app's single source of truth for color — a "Liquid" palette drawn from
//  water and nature: deep ocean teal, lagoon aqua, seafoam, with a warm coral for
//  loss. Two groups:
//
//  • Brand primaries — Deep Teal, Aqua, Seafoam — decorative chart/category fills;
//    the app-wide tint (AccentColor asset) is the same deep-teal → cyan family.
//  • Semantic pair — `increase` (money in / assets / positive → sea green) and
//    `decrease` (money out / liabilities / negative → coral) — replacing ad-hoc
//    `.green` / `.red`.
//
//  Everything adapts to light/dark. Bright, saturated tones read beautifully on a
//  dark background but lose contrast on white, so the two *semantic* colors are
//  asset color sets (see Increase/Decrease in Assets.xcassets): a vivid tone in
//  dark mode and a legible deepening of the same hue in light mode:
//    increase — dark #34D399 (bright sea green) / light #0E9F6E (≈ 3.4:1 large-text)
//    decrease — dark #FF7A66 (bright coral)     / light #D24A3A (≈ 4.4:1 on white)
//  The adaptive accent is deep teal #0E7490 (light) / bright cyan #22D3EE (dark).
//
//  Glass note (iOS 26): none of this is applied to Liquid Glass chrome — nav bar,
//  tab bar, toolbars, and sheets keep their material. The AccentColor asset only
//  supplies the tint those controls are designed to display.
//

import SwiftUI

extension Color {

    // MARK: Building block

    /// A color from a stored `"RRGGBB"` string (how envelopes persist their color).
    /// Returns nil for anything that isn't six hex digits.
    init?(hexString: String) {
        let trimmed = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard trimmed.count == 6, let value = UInt(trimmed, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// A color from a 24-bit `0xRRGGBB` hex literal.
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }

    // MARK: Brand primaries (water & nature)

    static let deepTeal = Color(hex: 0x0E7490)   // deep ocean
    static let aqua = Color(hex: 0x22C3D6)       // lagoon / shallow water
    static let seafoam = Color(hex: 0x2F9E7E)    // sea green

    // MARK: Semantic pair (asset-backed, adaptive light/dark)
    //
    // `Color.increase` and `Color.decrease` are NOT declared here — Xcode
    // generates them automatically from the "Increase" / "Decrease" color sets in
    // Assets.xcassets (asset-symbol generation). Each is a vivid tone in dark mode
    // and a legible same-hue deepening in light mode:
    //   increase — dark #34D399 (sea green) / light #0E9F6E (≈ 3.4:1 large-text)
    //   decrease — dark #FF7A66 (coral)     / light #D24A3A (≈ 4.4:1 on white)

    // MARK: Categorical palette

    /// Distinct fills for charts (donut slices, the Sankey ribbons, category
    /// bars) — a natural, aquatic spectrum. Deliberately excludes the semantic
    /// sea-green/coral so a category fill never reads as income or expense.
    ///
    /// Order matters: consumers walk this array by index, so neighbours must
    /// differ in *hue family and lightness*. A donut of five slices was reading as
    /// "three blues" when deep teal, aqua, and deep-sea blue landed within four
    /// steps of each other, so the sequence alternates cool → warm → green → navy
    /// rather than grouping the blues together.
    /// The palette's raw values, so a picker can persist the exact color it shows
    /// (envelopes store `"RRGGBB"`, never an index into this array).
    static let categoryPaletteHex: [UInt] = [
        0x0E7490,   // deep teal (ocean)
        0xE0A94F,   // sand / shore
        0x2F9E7E,   // sea green
        0x1D4E89,   // deep sea blue
        0x8FB55A,   // reed green
        0x22C3D6,   // lagoon aqua
        0x155E63,   // kelp (deep)
        0x7FCFE0,   // shallow aqua
    ]

    static let categoryPalette: [Color] = categoryPaletteHex.map { Color(hex: $0) }

    /// The palette in the form envelopes store, for the color picker.
    static let categoryPaletteHexStrings: [String] = categoryPaletteHex.map {
        String(format: "%06X", $0)
    }
}
