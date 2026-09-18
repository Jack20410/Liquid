//
//  VoiceAddView.swift
//  Liquid
//
//  The "Say it" capture surface: tap-free capture that starts listening on appear,
//  shows the live transcript, then asks the on-device model to turn it into a draft.
//  The draft is handed back to the caller, which opens the normal transaction editor
//  pre-filled — nothing is saved from here. All on-device: microphone →
//  SFSpeechRecognizer → FoundationModels, no network.
//
//  Presented over the app rather than as a card — it grows out of the microphone
//  button (see TransactionsView's zoom transition) and frosts what is behind, with
//  a rainbow glow around the edge of the device while the microphone is live, so
//  listening feels like a state the phone is in. The middle is four plain parts —
//  wave, status, transcript, slide to add — with nothing else competing for
//  attention while someone is mid-sentence.
//

import SwiftUI
import UIKit

struct VoiceAddView: View {
    let catalog: ParseCatalog
    /// Called with the parsed draft; the caller opens the editor pre-filled with it.
    var onDraft: (TransactionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var capture = VoiceCapture()
    @State private var isParsing = false
    @State private var parseError: String?

    private let parser = OnDeviceTransactionParser()

    private var isListening: Bool {
        capture.state == .recording && !isParsing && parseError == nil
    }

    var body: some View {
        ZStack {
            // Full frosting. Lighter blur keeps the app recognizable but leaves its
            // white row text fighting this screen's white text — "Listening…" landing
            // straight on a transaction row. Frosting the backdrop properly is what
            // makes the four parts readable without giving them a panel of their own.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Tapping the app behind the panel backs out.
            Color.clear
                .contentShape(.rect)
                .onTapGesture { cancel() }

            ScreenEdgeGlow(isAnimating: isListening)

            content
                .padding(.horizontal, 28)
        }
        .presentationBackground(.clear)
        .task {
            // Everything visual arrives with the zoom — the glow included — so the
            // screen lands as one motion rather than a second animation popping in
            // after it. Only the audio start waits, and only briefly: configuring
            // AVAudioSession and starting the engine is synchronous main-actor work
            // that would otherwise stutter the transition. It is invisible either
            // way; the wave simply sits at rest a moment longer.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 220))
            if capture.state == .idle { await capture.start() }
        }
        .onChange(of: capture.state) { _, state in
            if state == .finished { parse() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch capture.state {
        case .denied:
            messageView("Microphone or speech access is off. Turn both on in Settings to add by voice.",
                        icon: "mic.slash", action: ("Open Settings", "gear", openSettings))
        case .failed:
            messageView("Couldn't start listening. Please try again.",
                        icon: "exclamationmark.bubble", action: ("Try again", "arrow.clockwise", restart))
        default:
            if let parseError {
                messageView(parseError, icon: "exclamationmark.bubble",
                            action: ("Try again", "arrow.clockwise", restart))
            } else {
                captureView
            }
        }
    }

    // MARK: The four parts

    private var captureView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 1 — the wave: proof the phone is hearing you. Kept narrow and
            // centered; edge to edge it reads as a divider, not a voice.
            VoiceWave(levels: capture.levels, isIdle: !isListening)
                .frame(maxWidth: 210, maxHeight: 64)
                .accessibilityHidden(true)

            // 2 — what's happening right now.
            Text(statusText)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .padding(.top, 32)

            // 3 — the words, in a fixed area so arriving text doesn't shift the layout.
            transcriptView
                .frame(height: 150)
                .padding(.top, 24)

            Spacer(minLength: 0)

            // 4 — a deliberate gesture to finish, not a button you brush by accident.
            VStack(spacing: 14) {
                SlideToConfirm(title: "Slide to add",
                               isEnabled: isListening && !capture.transcript.isEmpty) {
                    capture.stop()   // → .finished → parse()
                }

                Button("Cancel", action: cancel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    private var statusText: String {
        if isParsing || capture.state == .finishing { return "Reading that…" }
        return capture.transcript.isEmpty ? "Listening…" : "Keep going, or slide to add"
    }

    @ViewBuilder
    private var transcriptView: some View {
        if capture.transcript.isEmpty {
            VStack(spacing: 10) {
                Text("Try saying")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Text("“spent 12 on coffee”\n“got paid 2000 today”")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                Text(capture.transcript)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)   // follow the newest words
        }
    }

    // MARK: Errors / permission

    private func messageView(_ text: String, icon: String,
                             action: (title: String, icon: String, run: () -> Void)) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: action.run) {
                Label(action.title, systemImage: action.icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Cancel", action: cancel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 24)
    }

    // MARK: Actions

    private func cancel() {
        capture.cancel()
        dismiss()
    }

    private func restart() {
        parseError = nil
        Task { await capture.start() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func parse() {
        let text = capture.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            parseError = "I didn't catch that. Please try again."
            return
        }
        isParsing = true
        parseError = nil
        Task {
            do {
                let draft = try await parser.parse(text, catalog: catalog)
                onDraft(draft)
                dismiss()
            } catch {
                isParsing = false
                parseError = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't turn that into a transaction. Please try again."
            }
        }
    }
}
