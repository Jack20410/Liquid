//
//  CurrencyField.swift
//  Liquid
//
//  A reusable amount entry field bound to a Decimal, using the app's single
//  primary currency and a decimal keypad.
//

import SwiftUI

struct CurrencyField: View {
    let title: String
    @Binding var amount: Decimal?
    var focused: FocusState<Bool>.Binding?

    var body: some View {
        HStack {
            Text(Formatters.currencyCode == "USD" ? "$" : Formatters.currencyCode)
                .foregroundStyle(.secondary)
            TextField(title, value: $amount, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .modifier(OptionalFocus(focused: focused))
        }
    }
}

/// Applies `.focused` only when a binding is provided.
private struct OptionalFocus: ViewModifier {
    var focused: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focused {
            content.focused(focused)
        } else {
            content
        }
    }
}
