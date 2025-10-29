//
//  TagBadge.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct TagBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let tag: String

    var body: some View {
        let displayName = PromptTagPolicy.localizedDisplayName(for: tag)
        let style = TagPalette.style(for: tag)
        
        // Dark mode: use foreground as background with white text
        // Light mode: use original styling
        let backgroundColor = colorScheme == .dark ? style.foreground : style.background
        let foregroundColor = colorScheme == .dark ? Color.white : style.foreground
        let strokeColor = colorScheme == .dark ? style.foreground.opacity(0.3) : style.foreground.opacity(0.12)
        
        Text(displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: 1)
            )
    }
}
