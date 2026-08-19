//
//  LiquidApp.swift
//  Liquid
//
//  Created by Bao Le on 8/5/26.
//

import SwiftUI
import SwiftData

@main
struct LiquidApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Institution.self,
            Account.self,
            Envelope.self,
            Transaction.self,
            AllocationRule.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .onAppear {
                    // Seed demo data only in the Simulator, so a real device you
                    // run in Debug starts empty for real-life use.
                    #if DEBUG && targetEnvironment(simulator)
                    SampleData.seedIfNeeded(sharedModelContainer.mainContext)
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
