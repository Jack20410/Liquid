//
//  Formatters.swift
//  Liquid
//
//  Shared formatting for the single primary currency and dates (spec §2.3).
//

import Foundation

enum Formatters {
    /// The app's single primary currency, taken from the device locale.
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Format a Decimal as currency, e.g. "$1,234.56".
    static func currency(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode))
    }
}

extension Decimal {
    var asCurrency: String { Formatters.currency(self) }

    /// Bridge for APIs that need Double (e.g. Swift Charts plottable values).
    var asDouble: Double { (self as NSDecimalNumber).doubleValue }
}
