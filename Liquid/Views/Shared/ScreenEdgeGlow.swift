//
//  ScreenEdgeGlow.swift
//  Liquid
//
//  A rainbow light that glows around the edge of the screen while the app is
//  listening. It is the whole-device signal that something is live — the phone
//  itself lights up, rather than a badge inside a panel.
//
//  Glow only: there is no hard-edged stroke, just colored light bleeding in from
//  the rim. A crisp rainbow outline reads as a border someone drew on; soft light
//  reads as the device responding.
//
//  Built so the animation is cheap: the gradient and its soft-edged mask are both
//  static, and only a rotation transform changes per frame. Animating the gradient's
//  own angle would re-rasterize a full-screen blur on every frame, which is exactly
//  the kind of work that makes a presentation transition stutter.
//

import SwiftUI

struct ScreenEdgeGlow: View {
    /// Rotates while true; holds still otherwise (and always under Reduce Motion).
    var isAnimating: Bool = true
    /// Seconds for one full turn of the hue wheel.
    var period: Double = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Angle = .zero

    /// A full hue wheel, closing on the starting red so there is no seam.
    private var spectrum: [Color] {
        let hues = stride(from: 0.0, to: 1.0, by: 1.0 / 12).map {
            Color(hue: $0, saturation: 0.9, brightness: 1)
        }
        return hues + [hues[0]]
    }

    private var shouldSpin: Bool { isAnimating && !reduceMotion }

    var body: some View {
        // Corner radius approximates the device's own; a slightly generous curve
        // looks intentional on any screen, where too square a corner does not.
        let shape = RoundedRectangle(cornerRadius: 56, style: .continuous)

        GeometryReader { geo in
            // The spinning layer must be a square wider than the screen's diagonal,
            // or its own edges sweep across the corners as hard diagonal seams.
            let side = hypot(geo.size.width, geo.size.height) * 1.15
            Rectangle()
                .fill(AngularGradient(colors: spectrum, center: .center))
                .frame(width: side, height: side)
                .rotationEffect(angle)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .mask {
            // Soft-edged rim: a wide stroke blurred into a glow, no hard line.
            shape
                .strokeBorder(.white, lineWidth: 16)
                .blur(radius: 16)
        }
        .opacity(0.5)
        .compositingGroup()
        .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { spinIfNeeded() }
            .onChange(of: shouldSpin) { _, _ in spinIfNeeded() }
    }

    private func spinIfNeeded() {
        guard shouldSpin else {
            withAnimation(.easeOut(duration: 0.3)) { angle = .zero }
            return
        }
        withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
            angle = .degrees(360)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        Text("Listening…").font(.title2).foregroundStyle(.white)
        ScreenEdgeGlow()
    }
}
