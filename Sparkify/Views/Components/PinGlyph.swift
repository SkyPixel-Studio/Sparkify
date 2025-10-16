//
//  PinGlyph.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct PinGlyph: View {
    let isPinned: Bool
    var circleDiameter: CGFloat = 24
    var isHighlighted: Bool = false

    private var iconName: String { isPinned ? "pin.fill" : "pin" }
    private var iconColor: Color {
        if isPinned {
            return Color.black
        }
        if isHighlighted {
            return Color.appForeground.opacity(0.9)
        }
        return Color.appForeground.opacity(0.6)
    }

    private var circleFill: Color {
        if isPinned {
            return Color.neonYellow
        }
        if isHighlighted {
            return Color.cardSurface.opacity(0.9)
        }
        return Color.cardSurface
    }

    private var circleStroke: Color {
        if isPinned {
            return Color.clear
        }
        if isHighlighted {
            return Color.cardOutline.opacity(0.9)
        }
        return Color.cardOutline.opacity(0.8)
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: circleDiameter * 0.45, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: circleDiameter, height: circleDiameter)
            .background(
                Circle()
                    .fill(circleFill)
            )
            .overlay(
                Circle()
                    .stroke(circleStroke, lineWidth: 1)
            )
            .shadow(color: isPinned ? Color.neonYellow.opacity(0.28) : Color.black.opacity(isHighlighted ? 0.12 : 0), radius: isPinned || isHighlighted ? 6 : 0, y: isPinned || isHighlighted ? 2 : 0)
    }
}
