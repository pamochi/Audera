//
//  DashboardView.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import Charts
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    card {
                        quietScoreCard
                    }

                    card {
                        noiseTimelineCard
                    }

                    card {
                        insightsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Audera")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh data")
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }

    // MARK: - Components

    private var quietScoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Quiet Score")
                .font(.headline)
            HStack(alignment: .lastTextBaseline) {
                Text(viewModel.quietScoreText)
                    .font(.system(size: 56, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    ProgressView(value: viewModel.quietRatio)
                        .progressViewStyle(.linear)
                    Text("Quiet time: \(viewModel.quietRatioText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 140)
            }
            Text("Audera periodically samples sound levels and never stores raw audio.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var noiseTimelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Noise timeline")
                    .font(.headline)
                Spacer()
                Text("dB")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.hasSamples {
                Chart(viewModel.timelinePoints) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("dB", point.averageDecibel)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("dB", point.averageDecibel)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("dB")
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                        }
                    }
                }
                .chartBackground { _ in
                    RuleMark(y: .value("Quiet", 40))
                        .foregroundStyle(Color.green.opacity(0.25))
                    RuleMark(y: .value("Moderate", 70))
                        .foregroundStyle(Color.orange.opacity(0.25))
                    RuleMark(y: .value("Loud", 85))
                        .foregroundStyle(Color.red.opacity(0.25))
                }
                .frame(height: 240)
            } else {
                Text("No samples yet. Keep your device nearby and Audera will start collecting data shortly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
            VStack(spacing: 16) {
                InsightRow(title: "Noisiest hour", value: viewModel.noisiestHourText, systemImage: "speaker.wave.3.fill", tint: .orange)
                InsightRow(title: "Quietest hour", value: viewModel.quietestHourText, systemImage: "moon.stars.fill", tint: .mint)
                InsightRow(title: "Average today", value: "\(viewModel.averageDecibelText) dB", systemImage: "gauge", tint: .purple)
                InsightRow(title: "Weekly quiet score", value: viewModel.weeklyAverageText, systemImage: "calendar", tint: .indigo)
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

}

private struct InsightRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
    }
}

