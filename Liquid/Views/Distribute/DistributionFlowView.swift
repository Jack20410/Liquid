//
//  DistributionFlowView.swift
//  Liquid
//
//  A compact, mobile-friendly Sankey-style flow: one source bar (the paycheck)
//  fans out through soft gradient ribbons into a bar per envelope, thickness
//  proportional to the amount. It answers "where does the money go?" at a glance,
//  with the exact amount and share beside each destination.
//
//  Built natively in SwiftUI (no web view): ribbons are gradient-filled `Shape`s in
//  a ZStack, so each can animate and be highlighted independently. Tapping a slice
//  emphasises its ribbon and dims the rest; the whole flow grows in on appear.
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

    /// The "money in" source color (the paycheck bar and the ribbons' origin).
    static let source: Color = .green
}

struct DistributionFlowView: View {
    struct Slice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let amount: Decimal
        let color: Color
    }

    let slices: [Slice]
    /// Called when the highlighted slice changes (nil when cleared). Optional.
    var onSelect: ((UUID?) -> Void)? = nil

    @State private var selected: UUID?
    @State private var revealed = false

    private var total: Decimal { slices.reduce(0) { $0 + $1.amount } }

    // Geometry constants (points).
    private let sourceWidth: CGFloat = 18
    private let targetWidth: CGFloat = 12
    private let segmentGap: CGFloat = 10
    private let labelGap: CGFloat = 12
    private let flowFraction: CGFloat = 0.38   // ribbons occupy the left ~38%

    var body: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size)
            ZStack(alignment: .topLeading) {
                sourceBar(layout)

                ForEach(Array(layout.segments.enumerated()), id: \.element.id) { index, seg in
                    ribbon(seg, layout: layout, width: geo.size.width, index: index)
                }
                ForEach(Array(layout.segments.enumerated()), id: \.element.id) { index, seg in
                    targetBar(seg, layout: layout, index: index)
                }
                ForEach(Array(layout.segments.enumerated()), id: \.element.id) { index, seg in
                    labelView(seg, layout: layout, index: index)
                }
                ForEach(layout.segments) { seg in
                    tapBand(seg, width: geo.size.width)
                }
            }
        }
        .frame(height: max(170, CGFloat(slices.count) * 56))
        .onAppear { revealed = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Where the money goes")
    }

    // MARK: Pieces

    private func sourceBar(_ layout: Layout) -> some View {
        RoundedRectangle(cornerRadius: sourceWidth / 2, style: .continuous)
            .fill(LinearGradient(
                colors: [FlowPalette.source.opacity(0.9), FlowPalette.source.opacity(0.55)],
                startPoint: .top, endPoint: .bottom))
            .frame(width: sourceWidth, height: layout.sourceRect.height)
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.45), value: revealed)
    }

    private func ribbon(_ seg: Segment, layout: Layout, width: CGFloat, index: Int) -> some View {
        RibbonShape(srcMinY: seg.srcMinY, srcHeight: seg.srcHeight,
                    dstMinY: seg.minY, dstHeight: seg.height,
                    startX: layout.flowStartX, endX: layout.flowEndX)
            .fill(LinearGradient(
                colors: [FlowPalette.source.opacity(0.40), seg.color.opacity(0.55)],
                startPoint: UnitPoint(x: layout.flowStartX / max(width, 1), y: 0.5),
                endPoint: UnitPoint(x: layout.flowEndX / max(width, 1), y: 0.5)))
            .scaleEffect(x: revealed ? 1 : 0.55, anchor: .leading)
            .opacity(opacity(for: seg))
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05), value: revealed)
            .animation(.easeInOut(duration: 0.22), value: selected)
    }

    private func targetBar(_ seg: Segment, layout: Layout, index: Int) -> some View {
        RoundedRectangle(cornerRadius: targetWidth / 2, style: .continuous)
            .fill(seg.color)
            .frame(width: targetWidth, height: max(targetWidth, seg.height))
            .offset(x: layout.flowEndX, y: seg.minY)
            .opacity(opacity(for: seg))
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05 + 0.08), value: revealed)
            .animation(.easeInOut(duration: 0.22), value: selected)
    }

    private func labelView(_ seg: Segment, layout: Layout, index: Int) -> some View {
        let pct = total > 0 ? (seg.amount / total * 100).asDouble : 0
        let isSelected = selected == seg.id
        return VStack(alignment: .leading, spacing: 2) {
            Text(seg.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(seg.amount.asCurrency)  ·  \(pct, format: .number.precision(.fractionLength(0...1)))%")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(seg.color.opacity(isSelected ? 0.14 : 0)))
        .frame(width: layout.labelWidth, height: seg.height, alignment: .leading)
        .offset(x: layout.labelX - 8, y: seg.minY)
        .opacity(opacity(for: seg))
        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05 + 0.1), value: revealed)
        .animation(.easeInOut(duration: 0.22), value: selected)
    }

    /// Full-width transparent hit target for a slice (covers its gap too, so there
    /// are no dead zones between slices).
    private func tapBand(_ seg: Segment, width: CGFloat) -> some View {
        let pct = total > 0 ? Int((seg.amount / total * 100).asDouble.rounded()) : 0
        return Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: width, height: seg.height + segmentGap)
            .offset(x: 0, y: seg.minY - segmentGap / 2)
            .onTapGesture { toggle(seg.id) }
            .accessibilityElement()
            .accessibilityLabel("\(seg.name), \(seg.amount.asCurrency), \(pct) percent")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Selection / emphasis

    private func toggle(_ id: UUID) {
        let next: UUID? = (selected == id) ? nil : id
        withAnimation(.easeInOut(duration: 0.22)) { selected = next }
        onSelect?(next)
    }

    private func opacity(for seg: Segment) -> Double {
        guard revealed else { return 0 }
        guard let selected else { return 1 }
        return selected == seg.id ? 1 : 0.2
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

        // Target heights are proportional but floored so thin slices still fit a
        // two-line label; the floor is paid for by the taller slices. The source
        // side stays fully proportional, so ribbons fan from true proportions.
        let targetHeights = distributedHeights(total: usableH,
                                               weights: slices.map(\.amount),
                                               minimum: 40)

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
}

/// A single flow ribbon: a smooth band from a source slice (left) to a target
/// slice (right), drawn in absolute coordinates so it can be gradient-filled.
private struct RibbonShape: Shape {
    let srcMinY: CGFloat
    let srcHeight: CGFloat
    let dstMinY: CGFloat
    let dstHeight: CGFloat
    let startX: CGFloat
    let endX: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = (startX + endX) / 2
        p.move(to: CGPoint(x: startX, y: srcMinY))
        p.addCurve(to: CGPoint(x: endX, y: dstMinY),
                   control1: CGPoint(x: midX, y: srcMinY),
                   control2: CGPoint(x: midX, y: dstMinY))
        p.addLine(to: CGPoint(x: endX, y: dstMinY + dstHeight))
        p.addCurve(to: CGPoint(x: startX, y: srcMinY + srcHeight),
                   control1: CGPoint(x: midX, y: dstMinY + dstHeight),
                   control2: CGPoint(x: midX, y: srcMinY + srcHeight))
        p.closeSubpath()
        return p
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
