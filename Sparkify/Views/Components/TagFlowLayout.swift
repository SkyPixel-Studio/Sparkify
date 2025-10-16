//
//  TagFlowLayout.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//
//
//  TagFlowLayout.swift
//  Sparkify
//
//  改进点：
//  - 两级缓存：尺寸缓存(与宽度无关) + 排版缓存(与宽度有关)
//  - 仅在“有限宽度”时做换行排版；∞/未定宽返回廉价估算
//  - 宽度抖动去抖：宽度变化 < 0.5pt 不重排
//

import SwiftUI

public struct TagFlowLayout: Layout {
    public var spacing: CGFloat
    public var widthEpsilon: CGFloat = 0.5   // 去抖阈值

    public init(spacing: CGFloat = 8, widthEpsilon: CGFloat = 0.5) {
        self.spacing = spacing
        self.widthEpsilon = widthEpsilon
    }

    // MARK: - Cache

    public struct Cache {
        // 与宽度无关：只要子视图集合没变，就不要重复测量
        var sizes: [CGSize] = []

        // 与宽度相关：frames/total 只在 lastWidth 变化时重算
        var lastWidth: CGFloat = .nan
        var frames: [CGRect] = []
        var total: CGSize = .zero
    }

    public func makeCache(subviews: Subviews) -> Cache { Cache() }

    // 仅负责测量（与 width 无关）
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
            // 尺寸变化会使排版无效
            cache.lastWidth = .nan
        }
    }

    // 仅负责排版（与 width 有关）
    @inline(__always)
    private func layoutIfNeeded(_ cache: inout Cache, width: CGFloat) {
        guard width.isFinite else { return } // 只在有限宽度下排版
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
        // 只测一次尺寸
        ensureSizes(&cache, subviews: subviews)

        // ∞/未定宽：不做换行排版，返回廉价估算（单行宽 + 最大高）
        guard let w = proposal.width, w.isFinite else {
            let sizes = cache.sizes
            let totalW = sizes.reduce(0) { $0 + $1.width }
                       + CGFloat(max(sizes.count - 1, 0)) * spacing
            let maxH   = sizes.map(\.height).max() ?? 0
            return CGSize(width: totalW, height: maxH)
        }

        // 有限宽：真正排版一次
        layoutIfNeeded(&cache, width: w)
        return cache.total
    }

    public func placeSubviews(in bounds: CGRect,
                              proposal: ProposedViewSize,
                              subviews: Subviews,
                              cache: inout Cache)
    {
        // 再确保尺寸缓存命中（不会重复测量）
        ensureSizes(&cache, subviews: subviews)

        // 用“实际宽度”只排一次版
        layoutIfNeeded(&cache, width: bounds.width)

        // 放置阶段不再做任何测量/算法，只消费缓存
        for (i, f) in cache.frames.enumerated() {
            let p = ProposedViewSize(width: cache.sizes[i].width, height: cache.sizes[i].height)
            subviews[i].place(
                at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                proposal: p
            )
        }
    }
}
