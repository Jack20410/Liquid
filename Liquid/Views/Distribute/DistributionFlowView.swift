//
//  DistributionFlowView.swift
//  Liquid
//
//  A compact, mobile-friendly Sankey-style flow: one source bar (the paycheck)
//  fans out through curved ribbons into a bar per envelope, thickness proportional
//  to the amount. It answers "where does the money go?" at a glance, with the exact
//  amount and share labelled beside each destination.
//
//  Bars and ribbons are drawn in a single Canvas so they share one coordinate
//  space; labels are laid over the same geometry as SwiftUI text so they respect
//  Dynamic Type and the current color scheme.
//

import SwiftUI

/// Stable, theme-independent colors for envelope flows, shared across the aggregate
/// flow and per-distribution detail so an envelope keeps the same color everywhere.
enum FlowPalette {
    static let colors: [Color] = [.blue, .orange, .teal, .green, .pink, .purple, .indigo, .mint]

    /// A deterministic color for an envelope id (same across launches).
    static func color(for id: UUID) -> Color {
        let sum = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { $0 &+ Int($1) }
        }
        return colors[sum % colors.count]
    }

    /// Neutral color for the grouped "Other" slice.
    static let other: Color = .gray
}

struct DistributionFlowView: View {
    struct Slice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let amount: Decimal
        let color: Color
    }

    let slices: [Slice]

    private var total: Decimal { slices.reduce(0) { $0 + $1.amount } }

    // Geometry constants (points).
    private let sourceWidth: CGFloat = 16
    private let targetWidth: CGFloat = 11
    private let segmentGap: CGFloat = 8
    private let labelGap: CGFloat = 10
    private let flowFraction: CGFloat = 0.40   // ribbons occupy the left 40%

    var body: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in draw(context, layout) }

                ForEach(layout.segments) { seg in
                    label(for: seg)
                        .frame(width: layout.labelWidth, height: seg.height, alignment: .leading)
                        .offset(x: layout.labelX, y: seg.minY)
                }
            }
        }
        .frame(height: max(160, CGFloat(slices.count) * 52))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Label

    @ViewBuilder
    private func label(for seg: Segment) -> some View {
        let pct = total > 0 ? (seg.amount / total * 100).asDouble : 0
        VStack(alignment: .leading, spacing: 1) {
            Text(seg.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(seg.amount.asCurrency) · \(pct, format: .number.precision(.fractionLength(0...1)))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
        }
    }

    // MARK: Drawing

    private func draw(_ context: GraphicsContext, _ layout: Layout) {
        guard total > 0, !layout.segments.isEmpty else { return }

        // Source bar (the paycheck) — a calm green "money in" column.
        let sourceRadius = min(sourceWidth / 2, layout.sourceRect.height / 2)
        context.fill(
            Path(roundedRect: layout.sourceRect, cornerRadius: sourceRadius),
            with: .linearGradient(
                Gradient(colors: [Color.green.opacity(0.85), Color.green.opacity(0.5)]),
                startPoint: CGPoint(x: 0, y: layout.sourceRect.minY),
                endPoint: CGPoint(x: 0, y: layout.sourceRect.maxY)
            )
        )

        let midX = (layout.flowStartX + layout.flowEndX) / 2

        for seg in layout.segments {
            // Ribbon: source partition (contiguous) → target segment (gapped).
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: layout.flowStartX, y: seg.srcMinY))
            ribbon.addCurve(
                to: CGPoint(x: layout.flowEndX, y: seg.minY),
                control1: CGPoint(x: midX, y: seg.srcMinY),
                control2: CGPoint(x: midX, y: seg.minY))
            ribbon.addLine(to: CGPoint(x: layout.flowEndX, y: seg.minY + seg.height))
            ribbon.addCurve(
                to: CGPoint(x: layout.flowStartX, y: seg.srcMinY + seg.srcHeight),
                control1: CGPoint(x: midX, y: seg.minY + seg.height),
                control2: CGPoint(x: midX, y: seg.srcMinY + seg.srcHeight))
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(seg.color.opacity(0.30)))

            // Target bar.
            let targetRect = CGRect(x: layout.flowEndX, y: seg.minY,
                                    width: targetWidth, height: seg.height)
            let targetRadius = min(targetWidth / 2, seg.height / 2)
            context.fill(Path(roundedRect: targetRect, cornerRadius: targetRadius),
                         with: .color(seg.color))
        }
    }

    // MARK: Layout

    private struct Segment: Identifiable {
        let id: UUID
        let name: String
        let amount: Decimal
        let color: Color
        let minY: CGFloat       // target-side top (with gaps)
        let height: CGFloat
        let srcMinY: CGFloat    // source-side top (contiguous, no gaps)
        let srcHeight: CGFloat
    }

    private struct Layout {
        let sourceRect: CGRect
        let flowStartX: CGFloat
        let flowEndX: CGFloat
        let labelX: CGFloat
        let labelWidth: CGFloat
        let segments: [Segment]
    }

    private func layout(in size: CGSize) -> Layout {
        let H = size.height
        let flowStartX = sourceWidth
        let flowEndX = max(flowStartX + 8, size.width * flowFraction)
        let labelX = flowEndX + targetWidth + labelGap
        let labelWidth = max(0, size.width - labelX)

        let sourceRect = CGRect(x: 0, y: 0, width: sourceWidth, height: H)

        guard total > 0, !slices.isEmpty else {
            return Layout(sourceRect: sourceRect, flowStartX: flowStartX, flowEndX: flowEndX,
                          labelX: labelX, labelWidth: labelWidth, segments: [])
        }

        let n = slices.count
        let totalGap = segmentGap * CGFloat(max(0, n - 1))
        let usableH = max(0, H - totalGap)

        // Target-side heights are proportional, but with a floor so thin slices
        // still fit their two-line label; the floor is paid for by shrinking the
        // taller slices, keeping the total exactly `usableH`. The source side stays
        // fully proportional, so the ribbons fan out from true proportions.
        let targetHeights = distributedHeights(total: usableH,
                                               weights: slices.map(\.amount),
                                               minimum: 36)

        var segments: [Segment] = []
        var ty: CGFloat = 0     // target cursor (with gaps)
        var sy: CGFloat = 0     // source cursor (contiguous)
        for (index, slice) in slices.enumerated() {
            let segH = targetHeights[index]
            let srcH = H * (slice.amount / total).asDouble
            segments.append(Segment(id: slice.id, name: slice.name, amount: slice.amount,
                                    color: slice.color, minY: ty, height: segH,
                                    srcMinY: sy, srcHeight: srcH))
            ty += segH + segmentGap
            sy += srcH
        }

        return Layout(sourceRect: sourceRect, flowStartX: flowStartX, flowEndX: flowEndX,
                      labelX: labelX, labelWidth: labelWidth, segments: segments)
    }

    /// Split `total` across `weights`, giving each at least `minimum` (when there's
    /// room) and sharing the remainder proportionally. Slices whose proportional
    /// share falls under the floor are pinned to it and the rest re-share what's
    /// left, until stable.
    private func distributedHeights(total: CGFloat, weights: [Decimal],
                                    minimum: CGFloat) -> [CGFloat] {
        let n = weights.count
        guard n > 0 else { return [] }
        let values = weights.map(\.asDouble)
        let sum = values.reduce(0, +)
        // Degenerate cases: no weight, or not enough room to floor everyone.
        guard sum > 0, total >= minimum * CGFloat(n) else {
            return Array(repeating: total / CGFloat(n), count: n)
        }

        var heights = [CGFloat](repeating: 0, count: n)
        var pinned = [Bool](repeating: false, count: n)
        while true {
            let freeH = total - CGFloat(pinned.filter { $0 }.count) * minimum
            let freeWeight = values.indices.reduce(0.0) { $0 + (pinned[$1] ? 0 : values[$1]) }
            guard freeWeight > 0 else { break }

            var pinnedThisPass = false
            for i in 0..<n where !pinned[i] {
                if freeH * CGFloat(values[i] / freeWeight) < minimum {
                    pinned[i] = true
                    pinnedThisPass = true
                }
            }
            if !pinnedThisPass {
                for i in 0..<n where !pinned[i] {
                    heights[i] = freeH * CGFloat(values[i] / freeWeight)
                }
                break
            }
        }
        for i in 0..<n where pinned[i] { heights[i] = minimum }
        return heights
    }

    private var accessibilitySummary: String {
        guard total > 0 else { return "No distribution to show." }
        let parts = slices.map { slice in
            let pct = (slice.amount / total * 100).asDouble
            return "\(slice.name), \(slice.amount.asCurrency), \(Int(pct.rounded())) percent"
        }
        return "Where the money goes. " + parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview {
    DistributionFlowView(slices: [
        .init(id: UUID(), name: "Rent", amount: 800, color: .blue),
        .init(id: UUID(), name: "Groceries", amount: 400, color: .orange),
        .init(id: UUID(), name: "Savings", amount: 500, color: .teal),
        .init(id: UUID(), name: "Fun", amount: 200, color: .pink),
        .init(id: UUID(), name: "Utilities", amount: 100, color: .green),
    ])
    .padding()
}
#endif
