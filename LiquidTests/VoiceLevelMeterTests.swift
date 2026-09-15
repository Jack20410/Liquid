//
//  VoiceLevelMeterTests.swift
//  LiquidTests
//
//  Tests for the microphone loudness math behind the "Say it" wave. The meter is
//  pure, so the dB curve and its edges are checked here rather than by watching
//  bars move on a device.
//

import Testing
import Foundation
@testable import Liquid

struct VoiceLevelMeterTests {

    private let meter = VoiceLevelMeter()

    /// A constant-amplitude buffer: RMS equals that amplitude.
    private func tone(_ amplitude: Float, count: Int = 512) -> [Float] {
        Array(repeating: amplitude, count: count)
    }

    @Test func silenceIsZero() {
        #expect(meter.level(for: tone(0)) == 0)
        #expect(meter.level(for: []) == 0)
    }

    @Test func fullScaleIsOne() {
        #expect(abs(meter.level(for: tone(1)) - 1) < 0.0001)
    }

    @Test func everythingBelowTheNoiseFloorReadsAsSilence() {
        // −60 dBFS is under the −50 dB floor, so it must clamp to 0, not go negative.
        #expect(meter.level(for: tone(0.001)) == 0)
    }

    @Test func levelsAlwaysLandInRange() {
        for amplitude in [Float(0), 0.0001, 0.01, 0.1, 0.5, 0.9, 1.0] {
            let level = meter.level(for: tone(amplitude))
            #expect(level >= 0 && level <= 1, "level \(level) out of range for \(amplitude)")
        }
    }

    @Test func louderSamplesGiveHigherLevels() {
        let quiet = meter.level(for: tone(0.02))
        let talking = meter.level(for: tone(0.2))
        let loud = meter.level(for: tone(0.8))
        #expect(quiet < talking)
        #expect(talking < loud)
    }

    /// Negative samples are just the other half of the waveform — RMS squares them,
    /// so a buffer's loudness must not depend on its sign.
    @Test func signDoesNotChangeLoudness() {
        #expect(meter.level(for: tone(0.5)) == meter.level(for: tone(-0.5)))
    }

    // MARK: Smoothing

    @Test func smoothingMovesTowardTheNewLevelWithoutOvershooting() {
        let next = meter.smoothed(1, previous: 0)
        #expect(next > 0 && next < 1)

        // Repeated updates converge on the target rather than passing it.
        var value = 0.0
        for _ in 0..<50 { value = meter.smoothed(1, previous: value) }
        #expect(value > 0.99 && value <= 1)
    }

    @Test func smoothingHoldsSteadyWhenTheLevelIsUnchanged() {
        #expect(abs(meter.smoothed(0.4, previous: 0.4) - 0.4) < 0.0001)
    }
}
