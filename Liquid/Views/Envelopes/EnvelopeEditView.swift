//
//  EnvelopeEditView.swift
//  Liquid
//
//  Create or edit an envelope: name, optional savings target, and its allocation
//  rule (spec FR-7–FR-9, FR-14).
//

import SwiftUI

struct EnvelopeEditView: View {
    let target: EnvelopeEditTarget
    let repository: SwiftDataBudgetRepository
    let existingEnvelopes: [Envelope]

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
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
                    TextField("e.g. Groceries", text: $name)
                        .focused($nameFocused)
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
        }
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
        if case let .existing(env) = target {
            name = env.name
            savingsTarget = env.target
            priority = env.rule?.priority ?? 0
            if let strategy = env.rule?.strategy {
                strategyKind = strategy.kind
                strategyValue = strategy.kind == .remainder ? nil : strategy.value
            }
        }
        nameFocused = isNew
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let envelope: Envelope
        switch target {
        case .new:
            envelope = repository.createEnvelope(name: trimmed, target: savingsTarget)
        case let .existing(existing):
            repository.updateEnvelope(existing, name: trimmed, target: savingsTarget)
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
