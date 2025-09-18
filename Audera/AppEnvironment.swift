//
//  AppEnvironment.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Foundation
import SwiftData

@MainActor
final class AppEnvironment: ObservableObject {
    let analytics: NoiseAnalytics
    let dataController: NoiseDataController
    let noiseMonitor: NoiseMonitor

    init(container: ModelContainer) {
        analytics = NoiseAnalytics()
        dataController = NoiseDataController(container: container, analytics: analytics)
        noiseMonitor = NoiseMonitor(dataController: dataController, configuration: analytics.configuration)
        do {
            try dataController.updateSummary(for: Date())
        } catch {
            #if DEBUG
            print("Failed to seed summary: \(error)")
            #endif
        }
    }
}
