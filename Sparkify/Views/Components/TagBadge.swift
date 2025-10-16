//
//  TagBadge.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct TagBadge: View {
    let tag: String

    var body: some View {
        let displayName = PromptTagPolicy.localizedDisplayName(for: tag)
        let style = TagPalette.style(for: tag)
        Text(displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(style.foreground)
            .background(
                Capsule()
                    .fill(style.background)
            )
            .overlay(
                Capsule()
                    .stroke(style.foreground.opacity(0.12), lineWidth: 1)
            )
    }
}
