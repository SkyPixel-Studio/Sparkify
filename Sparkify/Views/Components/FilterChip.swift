//
//  FilterChip.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isActive: Bool
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? (tint ?? Color.black) : Color.cardSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isActive {
            return tint == nil ? Color.white : Color.black
        }
        return tint ?? Color.appForeground
    }

    private var borderColor: Color {
        if isActive {
            if let tint {
                return tint.opacity(0.6)
            }
            return Color.clear
        }
        return Color.cardOutline.opacity(0.8)
    }

    private var borderWidth: CGFloat { isActive && tint == nil ? 0 : 1 }
}

struct SidebarActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black)
                )
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }
}
