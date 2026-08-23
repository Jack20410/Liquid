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
    static let categoryPalette: [Color] = [
        .deepTeal,             // 0E7490  deep teal (ocean)
        Color(hex: 0xE0A94F),  //         sand / shore
        .aqua,                 // 22C3D6  lagoon aqua
        Color(hex: 0x1D4E89),  //         deep sea blue
        .seafoam,              // 2F9E7E  sea green
        Color(hex: 0x8FB55A),  //         reed green
        Color(hex: 0x7FCFE0),  //         shallow aqua
        Color(hex: 0x155E63),  //         kelp (deep)
    ]
}
