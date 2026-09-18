//
//  EnvelopeEditView.swift
//  Liquid
//
//  Create or edit an envelope: name, appearance (icon + color), optional savings
//  target, and its allocation rule (spec FR-7–FR-9, FR-14).
//
//  The icon follows what you type until you touch the grid yourself — name a
//  category "Coffee" and it picks the cup — so the common case needs no work, and
//  a deliberate choice is never overwritten afterwards.
//

import SwiftUI

struct EnvelopeEditView: View {
    let target: EnvelopeEditTarget
    let repository: SwiftDataBudgetRepository
    let existingEnvelopes: [Envelope]

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var kind: EnvelopeKind = .spending
    @State private var symbol: String = CategoryIcon.all.first?.symbol ?? "cart"
    @State private var colorHex: String = Color.categoryPaletteHexStrings.first ?? "0E7490"
    /// Set once the user picks an icon by hand; stops the name from changing it.
    @State private var iconChosenByHand = false
    @State private var savingsTarget: Decimal?
    @State private var strategyKind: AllocationStrategy.Kind = .fixed
    @State private var strategyValue: Decimal?
    @State private var priority: Int = 0
    @FocusState private var nameFocused: Bool

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private var editingEnvelopeID: UUID? {
        if case let .existing(env) = target { return env.id }
        return nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True if another envelope (not the one being edited) already claims the
    /// remainder role — at most one is allowed (spec UC-2 precondition).
    private var remainderTakenElsewhere: Bool {
        existingEnvelopes.contains { env in
            env.id != editingEnvelopeID && env.rule?.strategy.kind == .remainder
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    HStack(spacing: 12) {
                        CategoryBadge(systemImage: symbol, color: selectedColor, size: 40)
                        TextField("e.g. Groceries", text: $name)
                            .focused($nameFocused)
                    }
                }

                Section("Icon") {
                    iconGrid
                }

                Section("Color") {
                    colorRow
                }

                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(EnvelopeKind.allCases) { k in
                            Label(k.displayName, systemImage: k.icon).tag(k)
                        }
                    }
                } header: {
                    Text("Kind")
                } footer: {
                    Text("Only Spending envelopes count toward Safe to Spend. Bills and Goals are money set aside.")
                }

                Section("Savings Target (optional)") {
                    CurrencyField(title: "No target", amount: $savingsTarget)
                }

                Section {
                    Picker("Strategy", selection: $strategyKind) {
                        ForEach(AllocationStrategy.Kind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    ruleValueField
                    Stepper("Priority: \(priority)", value: $priority, in: 0...99)
                } header: {
                    Text("Allocation Rule")
                } footer: {
                    ruleFooter
                }
            }
            .navigationTitle(isNew ? "New Envelope" : "Edit Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: name) { _, newValue in
                guard !iconChosenByHand, let suggested = CategoryIcon.suggestion(for: newValue) else { return }
                symbol = suggested
            }
        }
    }

    // MARK: Appearance

    private var selectedColor: Color {
        Color(hexString: colorHex) ?? .accentColor
    }

    private var iconGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
            ForEach(CategoryIcon.all) { option in
                let isSelected = option.symbol == symbol
                Button {
                    symbol = option.symbol
                    iconChosenByHand = true
                } label: {
                    Image(systemName: option.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? selectedColor : .secondary)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? selectedColor.opacity(0.16) : Color(.tertiarySystemFill),
                                    in: .circle)
                        .overlay {
                            Circle().strokeBorder(isSelected ? selectedColor : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var colorRow: some View {
        HStack(spacing: 10) {
            ForEach(Color.categoryPaletteHexStrings, id: \.self) { hex in
                let isSelected = hex == colorHex
                Button {
                    colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hexString: hex) ?? .accentColor)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle().strokeBorder(.primary.opacity(isSelected ? 0.5 : 0), lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var ruleValueField: some View {
        switch strategyKind {
        case .fixed:
            CurrencyField(title: "Amount", amount: $strategyValue)
        case .percentage:
            HStack {
                TextField("Percent", value: $strategyValue, format: .number)
                    .keyboardType(.decimalPad)
                Text("%").foregroundStyle(.secondary)
            }
        case .fillToTarget:
            CurrencyField(title: "Fill up to", amount: $strategyValue)
        case .remainder:
            EmptyView()
        }
    }

    @ViewBuilder
    private var ruleFooter: some View {
        switch strategyKind {
        case .fixed:
            Text("Assigns a fixed amount each payday.")
        case .percentage:
            Text("Assigns this percent of the gross paycheck.")
        case .fillToTarget:
            Text("Tops the envelope up to this balance each payday.")
        case .remainder:
            if remainderTakenElsewhere {
                Text("Another envelope is already the remainder. Only one is allowed.")
                    .foregroundStyle(.orange)
            } else {
                Text("Absorbs whatever is left after all other rules run.")
            }
        }
    }

    private func load() {
        switch target {
        case .new:
            colorHex = nextUnusedColorHex()
        case let .existing(env):
            name = env.name
            kind = env.kind
            savingsTarget = env.target
            symbol = CategoryStyle.icon(for: env)
            // A saved color wins; otherwise start from the one the list already
            // shows this envelope, so opening the sheet doesn't recolor it.
            colorHex = env.colorHex ?? hex(matching: env) ?? nextUnusedColorHex()
            iconChosenByHand = env.symbol != nil
            priority = env.rule?.priority ?? 0
            if let strategy = env.rule?.strategy {
                strategyKind = strategy.kind
                strategyValue = strategy.kind == .remainder ? nil : strategy.value
            }
        }
        nameFocused = isNew
    }

    /// The palette entry least used by existing envelopes, so two new categories
    /// in a row don't land on the same hue.
    private func nextUnusedColorHex() -> String {
        let palette = Color.categoryPaletteHexStrings
        let taken = Set(existingEnvelopes.compactMap(\.colorHex))
        return palette.first { !taken.contains($0) }
            ?? palette[existingEnvelopes.count % palette.count]
    }

    /// The palette entry matching the color the envelope list assigns this
    /// envelope automatically, when it has no color of its own.
    private func hex(matching envelope: Envelope) -> String? {
        let assigned = CategoryStyle.color(for: envelope,
                                           categoryColors: CategoryStyle.colorMap(for: existingEnvelopes))
        return zip(Color.categoryPaletteHexStrings, Color.categoryPalette)
            .first { $0.1 == assigned }?.0
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let envelope: Envelope
        switch target {
        case .new:
            envelope = repository.createEnvelope(name: trimmed, target: savingsTarget, kind: kind,
                                                 symbol: symbol, colorHex: colorHex)
        case let .existing(existing):
            repository.updateEnvelope(existing, name: trimmed, target: savingsTarget, kind: kind,
                                      symbol: symbol, colorHex: colorHex)
            envelope = existing
        }

        let strategy = AllocationStrategy(kind: strategyKind, value: strategyForKindValue())
        repository.setRule(strategy, priority: priority, on: envelope)
        dismiss()
    }

    /// Percentage is entered as a whole number (10 == 10%) and stored as a
    /// fraction (0.10) to match the engine (spec §7.1).
    private func strategyForKindValue() -> Decimal {
        let raw = strategyValue ?? 0
        return strategyKind == .percentage ? raw / 100 : raw
    }
}
