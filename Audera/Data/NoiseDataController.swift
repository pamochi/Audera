//
//  NoiseDataController.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Foundation
import SwiftData

@MainActor
final class NoiseDataController: ObservableObject {
    private let container: ModelContainer
    private let context: ModelContext
    private let analytics: NoiseAnalytics

    init(container: ModelContainer, analytics: NoiseAnalytics) {
        self.container = container
        self.context = ModelContext(container)
        self.analytics = analytics
    }

    // MARK: - Sample Persistence

    @discardableResult
    func addSample(decibel: Double, timestamp: Date = .now) throws -> NoiseSample {
        let sample = NoiseSample(timestamp: timestamp, decibel: decibel)
        context.insert(sample)
        try context.save()
        try updateSummary(for: sample.dayIdentifier)
        return sample
    }

    func samples(for day: Date) throws -> [NoiseSample] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<NoiseSample>(
            predicate: #Predicate { sample in
                sample.timestamp >= start && sample.timestamp < end
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }

    func deleteSamples(for day: Date) throws {
        let samples = try samples(for: day)
        for sample in samples {
            context.delete(sample)
        }
        try context.save()
    }

    // MARK: - Daily Summaries

    func computeSummary(for day: Date) throws -> QuietDaySummary {
        let samples = try samples(for: day)
        return analytics.summary(for: samples, day: day)
    }

    @discardableResult
    func updateSummary(for day: Date) throws -> DailyQuietSummary {
        let summary = try computeSummary(for: day)
        if let existing = try fetchSummary(for: summary.day) {
            existing.apply(from: summary)
            try context.save()
            return existing
        } else {
            let new = DailyQuietSummary(
                day: summary.day,
                quietScore: summary.quietScore,
                averageDecibels: summary.averageDecibels,
                sampleCount: summary.sampleCount,
                quietestHour: summary.quietestHour,
                noisiestHour: summary.noisiestHour
            )
            context.insert(new)
            try context.save()
            return new
        }
    }

    func fetchSummary(for day: Date) throws -> DailyQuietSummary? {
        let start = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<DailyQuietSummary>(
            predicate: #Predicate { summary in
                summary.day == start
            }
        )
        return try context.fetch(descriptor).first
    }

    func summaries(forLast days: Int, upTo referenceDate: Date = .now) throws -> [DailyQuietSummary] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: referenceDate)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else { return [] }

        let descriptor = FetchDescriptor<DailyQuietSummary>(
            predicate: #Predicate { summary in
                summary.day >= startDay && summary.day <= endDay
            },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func weeklyAverage(endingOn referenceDate: Date = .now) throws -> Double? {
        let summaries = try summaries(forLast: 7, upTo: referenceDate)
        guard !summaries.isEmpty else { return nil }
        let total = summaries.reduce(0.0) { $0 + $1.quietScore }
        return total / Double(summaries.count)
    }
}
