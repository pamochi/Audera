//
//  NoiseAnalytics.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Foundation

/// Helper responsible for transforming raw samples into human friendly insights.
struct NoiseAnalytics {
    struct Configuration {
        var sampleInterval: TimeInterval = 60.0
        var quietThreshold: Double = 40.0
        var moderateThreshold: Double = 70.0
        var loudThreshold: Double = 85.0

        static let `default` = Configuration()
    }

    enum Band {
        case quiet
        case moderate
        case loud
        case intense
    }

    let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func summary(for samples: [NoiseSample], day: Date) -> QuietDaySummary {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)

        guard !samples.isEmpty else {
            return QuietDaySummary(
                day: normalizedDay,
                quietScore: 100,
                averageDecibels: 0,
                quietestHour: nil,
                noisiestHour: nil,
                sampleCount: 0,
                hourlyPoints: [],
                distribution: NoiseDistribution(quiet: 0, moderate: 0, loud: 0, intense: 0)
            )
        }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        let average = sorted.reduce(0.0) { $0 + $1.decibel } / Double(sorted.count)
        let distribution = exposureDistribution(for: sorted)
        let quietScore = computeQuietScore(from: distribution)
        let hourlyPoints = buildHourlyPoints(for: sorted, day: normalizedDay)
        let quietest = hourlyPoints.min(by: { $0.averageDecibel < $1.averageDecibel })?.hour
        let noisiest = hourlyPoints.max(by: { $0.averageDecibel < $1.averageDecibel })?.hour

        return QuietDaySummary(
            day: normalizedDay,
            quietScore: quietScore,
            averageDecibels: average,
            quietestHour: quietest,
            noisiestHour: noisiest,
            sampleCount: sorted.count,
            hourlyPoints: hourlyPoints,
            distribution: distribution
        )
    }

    // MARK: - Exposure Distribution

    private func exposureDistribution(for samples: [NoiseSample]) -> NoiseDistribution {
        var quiet: TimeInterval = 0
        var moderate: TimeInterval = 0
        var loud: TimeInterval = 0
        var intense: TimeInterval = 0

        for sample in samples {
            switch band(for: sample.decibel) {
            case .quiet:
                quiet += configuration.sampleInterval
            case .moderate:
                moderate += configuration.sampleInterval
            case .loud:
                loud += configuration.sampleInterval
            case .intense:
                intense += configuration.sampleInterval
            }
        }

        return NoiseDistribution(quiet: quiet, moderate: moderate, loud: loud, intense: intense)
    }

    private func band(for decibel: Double) -> Band {
        switch decibel {
        case ..<configuration.quietThreshold:
            return .quiet
        case configuration.quietThreshold..<configuration.moderateThreshold:
            return .moderate
        case configuration.moderateThreshold..<configuration.loudThreshold:
            return .loud
        default:
            return .intense
        }
    }

    // MARK: - Quiet Score

    private func computeQuietScore(from distribution: NoiseDistribution) -> Double {
        guard distribution.total > 0 else { return 100 }

        let quietMinutes = distribution.quiet / 60
        let moderateMinutes = distribution.moderate / 60
        let loudMinutes = distribution.loud / 60
        let intenseMinutes = distribution.intense / 60

        var score = 30.0
        // Encourage quiet exposure up to 120 minutes (2 hours).
        score += min(quietMinutes, 120) * 0.5
        score -= moderateMinutes * 0.6
        score -= loudMinutes * 1.2
        score -= intenseMinutes * 2.5

        return max(0, min(100, score))
    }

    // MARK: - Hourly Breakdown

    private func buildHourlyPoints(for samples: [NoiseSample], day: Date) -> [QuietDaySummary.HourlyPoint] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: samples) { sample in
            calendar.component(.hour, from: sample.timestamp)
        }

        let sortedHours = groups.keys.sorted()
        return sortedHours.compactMap { hour in
            guard let values = groups[hour], !values.isEmpty else { return nil }
            let average = values.reduce(0.0) { $0 + $1.decibel } / Double(values.count)
            guard let date = calendar.date(byAdding: .hour, value: hour, to: day) else { return nil }
            return QuietDaySummary.HourlyPoint(hour: hour, averageDecibel: average, date: date)
        }
    }
}
