//
//  SettingsView.swift
//  Liquid
//
//  App settings, opened from the gear on the Dashboard. Holds basic app info and
//  the dashboard customization screen (card order + chart types).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var confirmingReset = false
    #endif

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        DashboardCustomizeView()
                    } label: {
                        Label("Customize dashboard", systemImage: "rectangle.grid.1x2")
                    }
                } footer: {
                    Text("Reorder the dashboard cards and choose how each chart is drawn.")
                }

                Section("General") {
                    LabeledContent("Currency", value: Formatters.currencyCode)
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                }

                #if DEBUG
                Section {
                    Button("Reset sample data", role: .destructive) {
                        confirmingReset = true
                    }
                } footer: {
                    Text("Debug builds only. Deletes everything and reseeds the demo data.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if DEBUG
            .confirmationDialog("Reset all data?", isPresented: $confirmingReset) {
                Button("Delete everything and reseed", role: .destructive, action: resetSampleData)
            } message: {
                Text("This removes every account, envelope, and transaction, then loads the demo data again.")
            }
            #endif
        }
    }

    #if DEBUG
    private func resetSampleData() {
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: AllocationRule.self)
        try? modelContext.delete(model: Envelope.self)
        try? modelContext.delete(model: Account.self)
        try? modelContext.delete(model: Institution.self)
        try? modelContext.save()
        SampleData.seedIfNeeded(modelContext)
    }
    #endif
}

// MARK: - Dashboard customization

/// Drag to reorder the dashboard's cards; pick the chart form for the cards that
/// offer one. Writes the same @AppStorage keys the cards read, so changes apply
/// immediately.
struct DashboardCustomizeView: View {
    @AppStorage(ChartStyleKey.cardOrder) private var orderRaw = DashboardCardID.rawValue(for: DashboardCardID.defaultOrder)
    @AppStorage(ChartStyleKey.cashFlow) private var cashFlowStyle: CashFlowChartStyle = .bars
    @AppStorage(ChartStyleKey.category) private var categoryStyle: CategoryChartStyle = .bars

    private var order: [DashboardCardID] {
        DashboardCardID.order(from: orderRaw)
    }

    var body: some View {
        List {
            Section {
                ForEach(order) { card in
                    HStack {
                        Label(card.displayName, systemImage: card.icon)
                        Spacer()
                        stylePicker(for: card)
                    }
                }
                .onMove { source, destination in
                    var cards = order
                    cards.move(fromOffsets: source, toOffset: destination)
                    orderRaw = DashboardCardID.rawValue(for: cards)
                }
            } header: {
                Text("Card order")
            } footer: {
                Text("Drag to reorder. Cards with a chart menu can switch between chart types here or on the card itself.")
            }

            Section {
                Button("Reset to default order") {
                    orderRaw = DashboardCardID.rawValue(for: DashboardCardID.defaultOrder)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Customize Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The chart-type choice for cards that have one; empty otherwise.
    @ViewBuilder
    private func stylePicker(for card: DashboardCardID) -> some View {
        switch card {
        case .cashFlow: styleMenu($cashFlowStyle)
        case .spending: styleMenu($categoryStyle)
        default: EmptyView()
        }
    }

    private func styleMenu<Style: ChartStyleOption>(_ selection: Binding<Style>) -> some View
    where Style.AllCases: RandomAccessCollection {
        Menu {
            Picker("Chart type", selection: selection) {
                ForEach(Array(Style.allCases)) { s in
                    Label(s.displayName, systemImage: s.icon).tag(s)
                }
            }
        } label: {
            Text(selection.wrappedValue.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
