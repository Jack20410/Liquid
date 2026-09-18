//
//  VoiceCapture.swift
//  Liquid
//
//  On-device speech-to-text for "Say it" capture. Wraps SFSpeechRecognizer +
//  AVAudioEngine and forces on-device recognition, so a spoken transaction never
//  leaves the phone — the same privacy stance as the rest of the app. Exposes a
//  small observable state machine the sheet drives; it does no parsing itself, it
//  only produces the transcript that the language model then reads.
//

import Foundation
import AVFoundation
import Speech

@MainActor
@Observable
final class VoiceCapture {

    enum State: Equatable {
        case idle
        case denied        // microphone or speech permission refused
        case recording
        case finishing     // stopped capturing; awaiting the recognizer's final result
        case finished      // done — `transcript` holds the final result
        case failed
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""

    /// A rolling window of recent microphone levels (0…1, oldest first) for the
    /// waveform. Kept short — it is a picture of the last second or so, not data.
    private(set) var levels: [Double] = Array(repeating: 0, count: VoiceCapture.levelWindow)

    static let levelWindow = 26

    private let meter = VoiceLevelMeter()
    /// The tap fires ~86×/s; the wave only needs ~20. Buffers in between still
    /// reach the recognizer, they just don't each push a UI update.
    private var lastLevelUpdate = Date.distantPast
    private static let levelInterval: TimeInterval = 1.0 / 20

    /// Text from segments the recognizer has already finalized (across pauses). The
    /// live `transcript` is this plus the current in-progress segment.
    private var finalizedText = ""

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Whether speech recognition can run at all on this device/locale.
    var isSupported: Bool { recognizer?.isAvailable == true }

    /// Ask for microphone + speech permission and begin listening.
    func start() async {
        transcript = ""
        clearLevels()
        guard await requestPermissions() else {
            state = .denied
            return
        }
        do {
            try beginRecording()
            state = .recording
        } catch {
            state = .failed
        }
    }

    /// Stop capturing and ask the recognizer for its final result. `state` becomes
    /// `.finishing`, then `.finished` once the final transcript arrives via the
    /// recognition callback (or a short timeout elapses) — so callers parse the
    /// complete transcript, not whatever partial happened to be showing.
    func stop() {
        guard state == .recording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()          // no more audio; the recognizer will emit a final result
        clearLevels()
        state = .finishing
        // Don't wait forever for the final callback.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.state == .finishing else { return }
            self.finalize()
        }
    }

    /// Abandon capture immediately (e.g. the sheet was cancelled) and release the mic.
    func cancel() {
        task?.cancel()
        teardown()
        state = .idle
    }

    // MARK: Levels

    /// The first channel's samples, copied out of the buffer so nothing crosses
    /// threads but plain values.
    private nonisolated static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    /// Append one smoothed level to the rolling window, at the wave's frame rate.
    private func record(_ samples: [Float]) {
        guard state == .recording else { return }
        let now = Date.now
        guard now.timeIntervalSince(lastLevelUpdate) >= Self.levelInterval else { return }
        lastLevelUpdate = now

        let level = meter.smoothed(meter.level(for: samples), previous: levels.last ?? 0)
        levels.removeFirst()
        levels.append(level)
    }

    /// Fade the wave back to rest — used when capture stops, so the bars settle
    /// instead of freezing mid-sentence.
    private func clearLevels() {
        levels = Array(repeating: 0, count: Self.levelWindow)
    }

    // MARK: Internals

    /// Publish the transcript we have and release resources. Idempotent — once
    /// `.finished`, later calls (a late final result, or the timeout) are no-ops.
    private func finalize() {
        guard state == .recording || state == .finishing else { return }
        teardown()
        state = .finished
    }

    /// Stop the engine/session and release the recognition task and request.
    private func teardown() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    private func beginRecording() throws {
        finalizedText = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // The tap feeds the *current* request, so restarting the task mid-session
        // (below) keeps capturing without re-tapping the engine.
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            // The tap runs on an audio thread: read the samples here, but hand the
            // level to the main actor for the wave to draw.
            guard let samples = Self.monoSamples(from: buffer) else { return }
            Task { @MainActor [weak self] in self?.record(samples) }
        }
        audioEngine.prepare()
        try audioEngine.start()

        installTask()
    }

    /// Start (or restart) a recognition task on the already-running audio engine.
    /// SFSpeechRecognizer finalizes a segment after a ~few-second pause; rather than
    /// ending there, we bank the finalized text and start a fresh task — so a pause
    /// never wipes what was already said. Capture ends when the user taps Add
    /// (`stop()`), not when the recognizer decides the utterance is over.
    private func installTask() {
        task?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = self.combined(result.bestTranscription.formattedString)
                    if result.isFinal {
                        self.finalizedText = self.transcript
                        switch self.state {
                        case .recording: self.installTask()   // pause — keep listening
                        case .finishing: self.finalize()       // user stopped — we're done
                        default: break
                        }
                    }
                } else if error != nil {
                    // Only wrap up on a user-initiated stop; ignore transient errors
                    // while still recording (the next task recovers).
                    if self.state == .finishing { self.finalize() }
                }
            }
        }
    }

    /// Finalized text so far plus the current in-progress segment.
    private func combined(_ segment: String) -> String {
        if finalizedText.isEmpty { return segment }
        if segment.isEmpty { return finalizedText }
        return finalizedText + " " + segment
    }
}
