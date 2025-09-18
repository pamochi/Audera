//
//  AuderaApp.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import SwiftUI
import SwiftData

@main
struct AuderaApp: App {
    @UIApplicationDelegateAdaptor(AuderaAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer
    @StateObject private var environment: AppEnvironment

    init() {
        let schema = Schema([
            NoiseSample.self,
            DailyQuietSummary.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            sharedModelContainer = container
            let appEnvironment = AppEnvironment(container: container)
            _environment = StateObject(wrappedValue: appEnvironment)
            appDelegate.environment = appEnvironment
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
                .task {
                    environment.noiseMonitor.startMonitoring()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            environment.noiseMonitor.handleScenePhase(newPhase)
        }
    }
}
