//
//  AppDelegate.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import UIKit

@MainActor
final class AuderaAppDelegate: NSObject, UIApplicationDelegate {
    weak var environment: AppEnvironment?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        environment?.noiseMonitor.registerBackgroundTasks()
        return true
    }
}
