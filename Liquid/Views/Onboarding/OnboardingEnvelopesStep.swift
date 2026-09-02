//
//  OnboardingEnvelopesStep.swift
//  Liquid
//
//  The hands-on Envelopes step: the user picks their spending categories from a set
//  of common presets (or types their own), and each tap creates a real .spending
//  envelope. Add-only here — a chip whose envelope already exists shows a checkmark
//  and is disabled; removing an envelope lives in the Envelopes tab, so onboarding
//  can never delete something that already has history.
//

import SwiftUI
import SwiftData

struct OnboardingEnvelopesStep: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Envelope.name) private var envelopes: [Envelope]
    @State private var customName = ""
    @State private var showAddCategory = false

    private var repository: SwiftDataBudgetRepository {
        SwiftDataBudgetRepository(context: modelContext)
    }

    private let presets: [(name: String, icon: String)] = [
        ("Groceries", "cart"), ("Rent", "house"), ("Transport", "car"),
        ("Dining", "fork.knife"), ("Fun", "gamecontroller"), ("Utilities", "bolt"),
        ("Health", "heart"), ("Shopping", "bag"),
    ]

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OnboardingHeader(
                    icon: "tray.full.fill",
                    title: "What do you spend on?",
                    message: "Pick your spending categories — you can change these anytime.")
                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(presets, id: \.name) { preset in
                        chip(name: preset.name, icon: preset.icon)
                    }
                    ForEach(customCategories, id: \.self) { name in
                        chip(name: name, icon: "tag")
                    }
                    addChip
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .alert("New category", isPresented: $showAddCategory) {
            TextField("e.g. Pets", text: $customName)
            Button("Add", action: addCustom)
            Button("Cancel", role: .cancel) { customName = "" }
        } message: {
            Text("Add a spending category of your own.")
        }
    }

    /// A "+" chip that prompts for a custom category name.
    private var addChip: some View {
        Button {
            customName = ""
            showAddCategory = true
        } label: {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.12), in: .capsule)
                .overlay(
                    Capsule().strokeBorder(Color.accentColor.opacity(0.35),
                                           style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a category")
    }

    private func chip(name: String, icon: String) -> some View {
        let added = isAdded(name)
        return Button {
            add(name)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: added ? "checkmark" : icon)
                Text(name).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(added ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                        in: .capsule)
            .foregroundStyle(added ? Color.accentColor : .primary)
            .overlay(
                Capsule().strokeBorder(added ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(added)
        .animation(.easeInOut(duration: 0.15), value: added)
    }

    private func isAdded(_ name: String) -> Bool {
        envelopes.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Spending categories the user added that aren't one of the presets — shown as
    /// their own (already-added) chips so a custom category is visibly confirmed.
    private var customCategories: [String] {
        envelopes
            .filter { $0.kind == .spending && !isPreset($0.name) }
            .map(\.name)
    }

    private func isPreset(_ name: String) -> Bool {
        presets.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAdded(trimmed) else { return }
        repository.createEnvelope(name: trimmed, target: nil, kind: .spending)
    }

    private func addCustom() {
        add(customName)
        customName = ""
    }
}
