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
        case finished      // stopped, `transcript` holds the result
        case failed
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Whether speech recognition can run at all on this device/locale.
    var isSupported: Bool { recognizer?.isAvailable == true }

    /// Ask for microphone + speech permission and begin listening.
    func start() async {
        transcript = ""
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

    /// Stop listening; the recognizer finalises and `state` becomes `.finished`.
    func stop() {
        guard state == .recording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .finished
    }

    // MARK: Internals

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
        task?.cancel()
        task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stop() }
                } else if error != nil {
                    self.stop()
                }
            }
        }
    }
}
