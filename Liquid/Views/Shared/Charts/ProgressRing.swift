//
//  ProgressRing.swift
//  Liquid
//
//  A circular progress arc — a thick, rounded stroke that fills clockwise from the
//  top by `progress` (0...1). Powers the dashboard's "left to spend" hero and the
//  smaller saving-rate gauge. It is decorative chrome only: identity always comes
//  from the label placed inside it (in a ZStack by the caller), never the ring
//  alone. Colors come from the caller so the Liquid palette stays the source of
//  truth.
//

import SwiftUI

struct ProgressRing: View {
    /// Fill fraction, clamped to 0...1.
    var progress: Double
    var lineWidth: CGFloat = 16
    /// Gradient painted along the filled arc.
    var colors: [Color] = [.aqua, .deepTeal]

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))   // start the fill at 12 o'clock
                .animation(.easeInOut(duration: 0.5), value: clamped)
        }
    }
}

#Preview {
    ProgressRing(progress: 0.62)
        .frame(width: 180, height: 180)
        .padding()
}
