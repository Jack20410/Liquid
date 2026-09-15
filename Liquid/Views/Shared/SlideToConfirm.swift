//
//  SlideToConfirm.swift
//  Liquid
//
//  A slide-to-act capsule: drag the knob to the end to confirm. Used to finish a
//  voice capture, where a plain button is too easy to hit by accident mid-sentence
//  — a deliberate drag is a clear "I'm done talking".
//
//  A drag is invisible to VoiceOver, so the control also exposes itself as a plain
//  button: switch users confirm with one activation instead of a gesture.
//

import SwiftUI
import UIKit

struct SlideToConfirm: View {
    var title: String
    var systemImage: String = "checkmark"
    var tint: Color = .accentColor
    var isEnabled: Bool = true
    var onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var isConfirmed = false

    private let height: CGFloat = 60
    private let inset: CGFloat = 5
    /// How far along the track counts as a confirm.
    private let threshold: CGFloat = 0.8

    var body: some View {
        GeometryReader { geo in
            let knob = height - inset * 2
            let travel = max(geo.size.width - knob - inset * 2, 1)
            let progress = min(max(offset / travel, 0), 1)

            ZStack(alignment: .leading) {
                Capsule().fill(.thinMaterial)
                Capsule()
                    .fill(tint.opacity(0.18 + 0.3 * progress))
                    .padding(inset)
                    .mask(alignment: .leading) {
                        Capsule().frame(width: offset + knob + inset)
                    }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(progress) * 1.4)

                Image(systemName: isConfirmed ? "checkmark" : systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: knob, height: knob)
                    .background(tint, in: .circle)
                    .offset(x: offset + inset)
                    .gesture(drag(travel: travel))
            }
            .frame(height: height)
            .opacity(isEnabled ? 1 : 0.45)
            .allowsHitTesting(isEnabled)
        }
        .frame(height: height)
        // VoiceOver and Switch Control can't drag: offer the same action as a button.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to confirm")
        .accessibilityAction { confirm() }
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isConfirmed else { return }
                offset = min(max(value.translation.width, 0), travel)
            }
            .onEnded { _ in
                guard !isConfirmed else { return }
                if offset >= travel * threshold {
                    withAnimation(.spring(duration: 0.25)) { offset = travel }
                    confirm()
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35)) {
                        offset = 0
                    }
                }
            }
    }

    private func confirm() {
        guard isEnabled, !isConfirmed else { return }
        isConfirmed = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm()
    }
}

#Preview {
    VStack(spacing: 24) {
        SlideToConfirm(title: "Slide to add") {}
        SlideToConfirm(title: "Slide to add", isEnabled: false) {}
    }
    .padding()
}
