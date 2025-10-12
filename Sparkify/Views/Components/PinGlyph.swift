//
//  PinGlyph.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import SwiftUI

struct PinGlyph: View {
    let isPinned: Bool
    var circleDiameter: CGFloat = 24

    private var iconName: String { isPinned ? "pin.fill" : "pin" }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: circleDiameter * 0.45, weight: .bold))
            .foregroundStyle(isPinned ? Color.black : Color.appForeground.opacity(0.6))
            .frame(width: circleDiameter, height: circleDiameter)
            .background(
                Circle()
                    .fill(isPinned ? Color.neonYellow : Color.cardSurface)
            )
            .overlay(
                Circle()
                    .stroke(Color.cardOutline.opacity(isPinned ? 0 : 0.8), lineWidth: 1)
            )
    }
}
