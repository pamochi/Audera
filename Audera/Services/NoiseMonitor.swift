//
//  NoiseMonitor.swift
//  Audera
//
//  Created by OpenAI Assistant on 2024-05-26.
//

import AVFoundation
import BackgroundTasks
import Combine
import SwiftUI

@MainActor
protocol NoiseMonitorScheduling: AnyObject {
    func registerBackgroundTasks()
    func scheduleNextRefresh()
}

/// Coordinates microphone metering, persistence, and background refresh scheduling.
final class NoiseMonitor: NSObject, ObservableObject {
    enum MonitorError: Error {
        case recorderUnavailable
    }

    private static let backgroundTaskIdentifier = "com.audera.noise.refresh"

    struct Scheduler: NoiseMonitorScheduling {
        func registerBackgroundTasks() {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: NoiseMonitor.backgroundTaskIdentifier, using: nil) { task in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                NoiseMonitor.shared?.handleBackground(task: refreshTask)
            }
        }

        func scheduleNextRefresh() {
            let request = BGAppRefreshTaskRequest(identifier: NoiseMonitor.backgroundTaskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: NoiseMonitor.shared?.configuration.sampleInterval ?? 60)
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                #if DEBUG
                print("Failed to schedule background refresh: \(error)")
                #endif
            }
        }
    }

    private static var shared: NoiseMonitor?

    @Published private(set) var latestSample: NoiseSample?

    private let dataController: NoiseDataController
    let configuration: NoiseAnalytics.Configuration
    private let scheduler: NoiseMonitorScheduling
    private let processingQueue = DispatchQueue(label: "com.audera.noise.monitor")

    private var recorder: AVAudioRecorder?
    private var timer: DispatchSourceTimer?
    private var isSessionConfigured = false
    private var isMonitoring = false

    init(dataController: NoiseDataController,
         configuration: NoiseAnalytics.Configuration = .default,
         scheduler: NoiseMonitorScheduling = Scheduler()) {
        self.dataController = dataController
        self.configuration = configuration
        self.scheduler = scheduler
        super.init()
        NoiseMonitor.shared = self
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        Task {
            let permissionGranted = await requestRecordingPermission()
            guard permissionGranted else {
                #if DEBUG
                print("Microphone permission not granted. Monitoring disabled.")
                #endif
                isMonitoring = false
                return
            }
            do {
                try await configureSessionIfNeeded()
                try await prepareRecorderIfNeeded()
                startTimerIfNeeded()
                scheduler.scheduleNextRefresh()
            } catch {
                #if DEBUG
                print("Failed to start monitoring: \(error)")
                #endif
                isMonitoring = false
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        stopTimer()
        processingQueue.async { [weak self] in
            self?.recorder?.stop()
            self?.recorder = nil
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            startMonitoring()
        case .background:
            stopTimer()
            processingQueue.async { [weak self] in
                self?.recorder?.stop()
                self?.recorder = nil
            }
            scheduler.scheduleNextRefresh()
        default:
            break
        }
    }

    func registerBackgroundTasks() {
        scheduler.registerBackgroundTasks()
    }

    // MARK: - Background Refresh

    private func handleBackground(task: BGAppRefreshTask) {
        scheduler.scheduleNextRefresh()

        let captureTask = Task {
            do {
                try await configureSessionIfNeeded()
                try await captureSample()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            captureTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Sampling

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + configuration.sampleInterval,
                       repeating: configuration.sampleInterval)
        timer.setEventHandler { [weak self] in
            Task {
                do {
                    try await self?.captureSample()
                } catch {
                    #if DEBUG
                    print("Failed to capture sample: \(error)")
                    #endif
                }
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func captureSample() async throws {
        try await prepareRecorderIfNeeded()
        let decibel = try await measureDecibel()
        try await MainActor.run {
            do {
                let sample = try dataController.addSample(decibel: decibel)
                latestSample = sample
            } catch {
                #if DEBUG
                print("Failed to persist sample: \(error)")
                #endif
            }
        }
    }

    // MARK: - Audio Configuration

    @MainActor
    private func configureSessionIfNeeded() throws {
        guard !isSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        isSessionConfigured = true
    }

    private func prepareRecorderIfNeeded() async throws {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: MonitorError.recorderUnavailable)
                    return
                }

                do {
                    if self.recorder == nil {
                        let url = URL(fileURLWithPath: "/dev/null", isDirectory: false)
                        let settings: [String: Any] = [
                            AVFormatIDKey: Int(kAudioFormatAppleLossless),
                            AVSampleRateKey: 44100.0,
                            AVNumberOfChannelsKey: 1,
                            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
                        ]
                        self.recorder = try AVAudioRecorder(url: url, settings: settings)
                        self.recorder?.isMeteringEnabled = true
                        self.recorder?.record()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func measureDecibel() async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self, let recorder = self.recorder else {
                    continuation.resume(throwing: MonitorError.recorderUnavailable)
                    return
                }

                recorder.updateMeters()
                let average = recorder.averagePower(forChannel: 0)
                let decibel = self.normalizedDecibel(from: average)
                continuation.resume(returning: decibel)
            }
        }
    }

    private func normalizedDecibel(from averagePower: Float) -> Double {
        let minDb: Float = -80
        if averagePower <= minDb { return 0 }
        let clamped = max(averagePower, minDb)
        let level = pow(10.0, clamped / 20.0)
        // Scale into a 0...120 dB range.
        return Double(min(level * 120.0, 120.0))
    }

    @MainActor
    private func requestRecordingPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
