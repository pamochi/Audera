//
//  DashboardViewModel.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var summary: QuietDaySummary?
    @Published private(set) var weeklyAverage: Double?
    @Published private(set) var quietestHourText: String = "--"
    @Published private(set) var noisiestHourText: String = "--"

    var quietScoreText: String {
        summary?.quietScoreDisplay ?? "--"
    }

    var averageDecibelText: String {
        summary?.averageDecibelsDisplay ?? "--"
    }

    var quietRatioText: String {
        guard let ratio = summary?.distribution.quietRatio else { return "--" }
        return ratio.formatted(.percent.precision(.fractionLength(0)))
    }

    var quietRatio: Double {
        summary?.distribution.quietRatio ?? 0
    }

    var timelinePoints: [QuietDaySummary.HourlyPoint] {
        summary?.hourlyPoints ?? []
    }

    var weeklyAverageText: String {
        guard let weeklyAverage else { return "--" }
        return weeklyAverage.formatted(.number.precision(.fractionLength(0)))
    }

    var hasSamples: Bool {
        (summary?.sampleCount ?? 0) > 0
    }

    private let dataController: NoiseDataController
    private var cancellables = Set<AnyCancellable>()

    init(dataController: NoiseDataController, monitor: NoiseMonitor) {
        self.dataController = dataController

        monitor.$latestSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        refresh()
    }

    func refresh() {
        do {
            let today = Date()
            summary = try dataController.computeSummary(for: today)
            weeklyAverage = try dataController.weeklyAverage(endingOn: today)
            quietestHourText = Self.format(hour: summary?.quietestHour)
            noisiestHourText = Self.format(hour: summary?.noisiestHour)
        } catch {
            #if DEBUG
            print("Failed to refresh dashboard: \(error)")
            #endif
        }
    }

    private static func format(hour: Int?) -> String {
        guard let hour else { return "--" }
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale.autoupdatingCurrent
            formatter.dateFormat = "h a"
            return formatter.string(from: date)
        }
        return "--"
    }
}
