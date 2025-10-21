//
//  TagFlowLayout.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

public struct TagFlowLayout: Layout {
    public var spacing: CGFloat
    public var widthEpsilon: CGFloat = 0.5   

    public init(spacing: CGFloat = 8, widthEpsilon: CGFloat = 0.5) {
        self.spacing = spacing
        self.widthEpsilon = widthEpsilon
    }

    // MARK: - Cache

    public struct Cache {
        var sizes: [CGSize] = []

        var lastWidth: CGFloat = .nan
        var frames: [CGRect] = []
        var total: CGSize = .zero
    }

    public func makeCache(subviews: Subviews) -> Cache { Cache() }

    @inline(__always)
    private func ensureSizes(_ cache: inout Cache, subviews: Subviews) {
        var newSizes: [CGSize] = []
        newSizes.reserveCapacity(subviews.count)

        for subview in subviews {
            let dims = subview.dimensions(in: .unspecified)
            newSizes.append(CGSize(width: dims.width, height: dims.height))
        }

        if cache.sizes != newSizes {
            cache.sizes = newSizes
            cache.lastWidth = .nan
        }
    }

    @inline(__always)
    private func layoutIfNeeded(_ cache: inout Cache, width: CGFloat) {
        guard width.isFinite else { return }
        if cache.lastWidth.isFinite, abs(cache.lastWidth - width) < widthEpsilon { return }
        cache.lastWidth = width

        var frames: [CGRect] = []
        frames.reserveCapacity(cache.sizes.count)

        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        var maxLineW: CGFloat = 0

        for s in cache.sizes {
            if x > 0 && x + s.width > width {
                maxLineW = max(maxLineW, x - spacing)
                x = 0
                y += lineH + spacing
                lineH = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }

        if !cache.sizes.isEmpty {
            maxLineW = max(maxLineW, x > 0 ? x - spacing : 0)
        }

        cache.frames = frames
        cache.total  = CGSize(
            width: width.isFinite ? width : maxLineW,
            height: cache.sizes.isEmpty ? 0 : y + lineH
        )
    }

    // MARK: - Layout conformance

    public func sizeThatFits(proposal: ProposedViewSize,
                             subviews: Subviews,
                             cache: inout Cache) -> CGSize
    {
        ensureSizes(&cache, subviews: subviews)

        guard let w = proposal.width, w.isFinite else {
            let sizes = cache.sizes
            let totalW = sizes.reduce(0) { $0 + $1.width }
                       + CGFloat(max(sizes.count - 1, 0)) * spacing
            let maxH   = sizes.map(\.height).max() ?? 0
            return CGSize(width: totalW, height: maxH)
        }

        layoutIfNeeded(&cache, width: w)
        return cache.total
    }

    public func placeSubviews(in bounds: CGRect,
                              proposal: ProposedViewSize,
                              subviews: Subviews,
                              cache: inout Cache)
    {
        ensureSizes(&cache, subviews: subviews)

        layoutIfNeeded(&cache, width: bounds.width)

        for (i, f) in cache.frames.enumerated() {
            let p = ProposedViewSize(width: cache.sizes[i].width, height: cache.sizes[i].height)
            subviews[i].place(
                at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                proposal: p
            )
        }
    }
}
