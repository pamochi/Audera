//
//  HistoryViewModel.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var summaries: [DailyQuietSummary] = []
    @Published private(set) var weeklyAverage: Double?

    private let dataController: NoiseDataController

    init(dataController: NoiseDataController) {
        self.dataController = dataController
        refresh()
    }

    func refresh() {
        do {
            summaries = try dataController.summaries(forLast: 30)
            weeklyAverage = try dataController.weeklyAverage()
        } catch {
            #if DEBUG
            print("Failed to load history: \(error)")
            #endif
        }
    }

    var weeklyAverageText: String {
        guard let weeklyAverage else { return "--" }
        return weeklyAverage.formatted(.number.precision(.fractionLength(0)))
    }

    func summary(for day: Date) -> QuietDaySummary? {
        try? dataController.computeSummary(for: day)
    }

    var sortedSummaries: [DailyQuietSummary] {
        summaries.sorted { $0.day > $1.day }
    }
}
