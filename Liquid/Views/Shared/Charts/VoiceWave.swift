//
//  VoiceWave.swift
//  Liquid
//
//  The live microphone waveform for "Say it" — mirrored bars, newest on the right,
//  each one a recent loudness reading from VoiceCapture. It is the screen's proof
//  that the phone is actually hearing you, so it answers to real audio rather than
//  animating on a timer; with no sound it settles to a flat resting line.
//
//  Decorative: callers hide it from VoiceOver, which reads the transcript instead.
//

import SwiftUI

struct VoiceWave: View {
    /// Recent levels, 0…1, oldest first.
    var levels: [Double]
    var tint: Color = .accentColor
    /// Drawn dim and still — used while the transcript is being read.
    var isIdle: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 4
    /// Silence still draws a short bar rather than a dot, so the resting wave reads
    /// as a quiet line instead of scattered debris.
    private let minBar: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(gradient(at: index))
                        .frame(width: barWidth(in: geo.size.width),
                               height: height(for: level, in: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: levels)
        }
        .opacity(isIdle ? 0.35 : 1)
    }

    private func barWidth(in width: CGFloat) -> CGFloat {
        let count = max(levels.count, 1)
        let available = width - spacing * CGFloat(count - 1)
        return max(2, available / CGFloat(count))
    }

    private func height(for level: Double, in height: CGFloat) -> CGFloat {
        max(minBar, height * CGFloat(min(max(level, 0), 1)))
    }

    /// Older readings fade out to the left, so the wave reads as moving even when
    /// the levels themselves are steady.
    private func gradient(at index: Int) -> LinearGradient {
        let age = Double(index + 1) / Double(max(levels.count, 1))
        return LinearGradient(colors: [tint.opacity(0.35 + 0.65 * age), tint.opacity(0.2 + 0.5 * age)],
                              startPoint: .top, endPoint: .bottom)
    }
}

#Preview {
    VStack(spacing: 40) {
        VoiceWave(levels: (0..<40).map { _ in Double.random(in: 0.05...1) })
            .frame(height: 90)
        VoiceWave(levels: Array(repeating: 0, count: 40))
            .frame(height: 90)
    }
    .padding()
}
