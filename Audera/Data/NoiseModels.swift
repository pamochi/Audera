//
//  NoiseModels.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Foundation
import SwiftData

/// A single noise sample captured from the device microphone.
/// Only timestamp and decibel level are persisted to respect user privacy.
@Model
final class NoiseSample {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var decibel: Double

    init(id: UUID = UUID(), timestamp: Date = .now, decibel: Double) {
        self.id = id
        self.timestamp = timestamp
        self.decibel = decibel
    }
}

extension NoiseSample {
    /// Start-of-day (midnight) date for the sample.
    var dayIdentifier: Date {
        Calendar.current.startOfDay(for: timestamp)
    }

    /// Hour component (0...23) for convenience when grouping samples.
    var hourComponent: Int {
        Calendar.current.component(.hour, from: timestamp)
    }
}

/// Persisted snapshot for a daily quiet score calculation.
/// These summaries allow quick lookups for history views and widgets while
/// remaining derived from the underlying samples.
@Model
final class DailyQuietSummary {
    @Attribute(.unique) var day: Date
    var quietScore: Double
    var averageDecibels: Double
    var sampleCount: Int
    var quietestHour: Int?
    var noisiestHour: Int?
    var updatedAt: Date

    init(day: Date,
         quietScore: Double,
         averageDecibels: Double,
         sampleCount: Int,
         quietestHour: Int?,
         noisiestHour: Int?,
         updatedAt: Date = .now) {
        self.day = Calendar.current.startOfDay(for: day)
        self.quietScore = quietScore
        self.averageDecibels = averageDecibels
        self.sampleCount = sampleCount
        self.quietestHour = quietestHour
        self.noisiestHour = noisiestHour
        self.updatedAt = updatedAt
    }

    func apply(from summary: QuietDaySummary) {
        quietScore = summary.quietScore
        averageDecibels = summary.averageDecibels
        sampleCount = summary.sampleCount
        quietestHour = summary.quietestHour
        noisiestHour = summary.noisiestHour
        updatedAt = .now
    }
}

/// Convenience type used when presenting daily analytics.
struct QuietDaySummary: Identifiable {
    struct HourlyPoint: Identifiable {
        let hour: Int
        let averageDecibel: Double
        let date: Date

        var id: Int { hour }
    }

    let id = UUID()
    let day: Date
    let quietScore: Double
    let averageDecibels: Double
    let quietestHour: Int?
    let noisiestHour: Int?
    let sampleCount: Int
    let hourlyPoints: [HourlyPoint]
    let distribution: NoiseDistribution

    var quietScoreDisplay: String {
        quietScore.formatted(.number.precision(.fractionLength(0)))
    }

    var averageDecibelsDisplay: String {
        averageDecibels.formatted(.number.precision(.fractionLength(1)))
    }
}

struct NoiseDistribution {
    let quiet: TimeInterval
    let moderate: TimeInterval
    let loud: TimeInterval
    let intense: TimeInterval

    var total: TimeInterval {
        quiet + moderate + loud + intense
    }

    var quietRatio: Double {
        guard total > 0 else { return 0 }
        return quiet / total
    }
}
