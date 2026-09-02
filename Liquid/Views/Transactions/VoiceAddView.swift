//
//  VoiceAddView.swift
//  Liquid
//
//  The "Say it" sheet: tap-free capture that starts listening on appear, shows the
//  live transcript, then asks the on-device model to turn it into a draft. The draft
//  is handed back to the caller, which opens the normal transaction editor pre-filled
//  — nothing is saved from here. All on-device: microphone → SFSpeechRecognizer →
//  FoundationModels, no network.
//

import SwiftUI
import UIKit

struct VoiceAddView: View {
    let catalog: ParseCatalog
    /// Called with the parsed draft; the caller opens the editor pre-filled with it.
    var onDraft: (TransactionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var capture = VoiceCapture()
    @State private var isParsing = false
    @State private var parseError: String?

    private let parser = OnDeviceTransactionParser()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Say it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { capture.stop(); dismiss() }
                }
            }
            .task { if capture.state == .idle { await capture.start() } }
            .onChange(of: capture.state) { _, state in
                if state == .finished { parse() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isParsing {
            parsingView
        } else if let parseError {
            messageView(parseError)
        } else {
            switch capture.state {
            case .denied: deniedView
            case .failed: messageView("Couldn't start listening. Please try again.")
            default: listeningView
            }
        }
    }

    // MARK: Listening

    private var listeningView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 110, height: 110)
                .background(Color.accentColor, in: .circle)
                .symbolEffect(.pulse, isActive: capture.state == .recording)

            if capture.transcript.isEmpty {
                Text("Listening…")
                    .font(.title3.weight(.medium)).foregroundStyle(.secondary)
                Text("Try: “spent 12 on coffee” · “got paid 2000 today”")
                    .font(.footnote).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text(capture.transcript)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }

            Spacer()

            Button {
                capture.stop()   // → .finished → parse()
            } label: {
                Label("Add", systemImage: "checkmark")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(capture.transcript.isEmpty)
        }
    }

    // MARK: Parsing

    private var parsingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Reading that…").font(.headline).foregroundStyle(.secondary)
            if !capture.transcript.isEmpty {
                Text("“\(capture.transcript)”")
                    .font(.subheadline).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    // MARK: Errors / permission

    private func messageView(_ text: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text(text)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                parseError = nil
                Task { await capture.start() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.slash")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Microphone or speech access is off. Turn both on in Settings to add by voice.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: Parse

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
