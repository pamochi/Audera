//
//  HistoryView.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Weekly quiet score", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.weeklyAverageText)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }

                Section("Recent days") {
                    if viewModel.sortedSummaries.isEmpty {
                        VStack(alignment: .center) {
                            Text("History will appear here once Audera collects a full day of data.")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 24)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.sortedSummaries) { summary in
                            HistoryRow(summary: summary)
                                .listRowSeparator(.visible)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh history")
                }
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }
}

private struct HistoryRow: View {
    let summary: DailyQuietSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.day, format: Date.FormatStyle().month(.abbreviated).day().weekday(.abbreviated))
                    .font(.headline)
                Spacer()
                Text(summary.quietScore.formatted(.number.precision(.fractionLength(0))))
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 12) {
                Label("\(summary.averageDecibels.formatted(.number.precision(.fractionLength(1)))) dB", systemImage: "gauge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let quiet = summary.quietestHour {
                    Label("Quiet: \(formatHour(quiet))", systemImage: "wind")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let loud = summary.noisiestHour {
                    Label("Loud: \(formatHour(loud))", systemImage: "speaker.wave.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "h a"
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "--"
    }
}
