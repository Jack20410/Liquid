//
//  VoiceLevelMeter.swift
//  Liquid
//
//  Turns raw microphone samples into a 0…1 loudness level for the "Say it" wave.
//  Pure and synchronous so the dB math can be tested without an audio engine —
//  VoiceCapture just feeds it the buffers its tap already receives.
//
//  Loudness is measured in decibels rather than raw amplitude because hearing is
//  logarithmic: a raw RMS of 0.1 is already clearly audible speech, but as a bar
//  height it would look like nothing. Everything quieter than `noiseFloor` reads
//  as silence.
//

import Foundation

struct VoiceLevelMeter {

    /// Quietest level that still registers, in dBFS. Room tone sits below this.
    var noiseFloor: Double = -50

    /// How much of the previous level to keep when smoothing, 0…1. Higher is
    /// calmer; the bars should breathe, not flicker.
    var smoothing: Double = 0.6

    /// The normalized level for one buffer of samples: RMS → dBFS → 0…1.
    /// Returns 0 for an empty buffer or pure silence.
    func level(for samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = (sumOfSquares / Double(samples.count)).squareRoot()
        guard rms > 0 else { return 0 }

        let decibels = 20 * log10(rms)
        guard decibels > noiseFloor else { return 0 }
        return min(1, decibels / -noiseFloor + 1)   // noiseFloor → 0, 0 dBFS → 1
    }

    /// Blend a new level into the previous one so the wave eases between values.
    func smoothed(_ new: Double, previous: Double) -> Double {
        previous * smoothing + new * (1 - smoothing)
    }
}
