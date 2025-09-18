//
//  ContentView.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(
                    dataController: environment.dataController,
                    monitor: environment.noiseMonitor
                )
            )
            .tabItem {
                Label("Today", systemImage: "waveform")
            }

            HistoryView(
                viewModel: HistoryViewModel(dataController: environment.dataController)
            )
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
