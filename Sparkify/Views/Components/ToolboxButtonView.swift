//
//  ToolboxButtonView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import AppKit
import SwiftUI

struct ToolboxButtonView: View {
    let apps: [ToolboxApp]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onLaunch: (ToolboxApp) -> Void

    private var hasApps: Bool {
        apps.isEmpty == false
    }

    var body: some View {
        HStack(spacing: 12) {
            if isExpanded {
                ForEach(apps) { app in
                    ToolboxAppButton(app: app) {
                        onLaunch(app)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    onToggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark.circle.fill" : "square.grid.3x3.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isExpanded ? Color.black : Color.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(isExpanded ? Color.neonYellow : Color.black.opacity(0.85))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isExpanded ? 0.2 : 0), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 8)
            }
            .buttonStyle(.plain)
            .opacity(hasApps ? 1 : 0)
            .disabled(hasApps == false)
            .help(isExpanded ? "收起 Toolbox" : "展开 Toolbox")
        }
        .padding(.horizontal, 4)
    }
}

private struct ToolboxAppButton: View {
    let app: ToolboxApp
    let onLaunch: () -> Void

    @State private var icon: NSImage?
    @State private var isHovering = false

    private let size = CGSize(width: 44, height: 44)

    var body: some View {
        Button {
            onLaunch()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovering ? Color.cardSurface.opacity(0.95) : Color.cardSurface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.cardOutline.opacity(isHovering ? 0.35 : 0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isHovering ? 0.18 : 0.1), radius: isHovering ? 12 : 8, y: isHovering ? 6 : 4)

                iconView
                    .frame(width: size.width - 12, height: size.height - 12)
            }
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottomTrailing) {
                optionBadge
                    .offset(x: -6, y: -6)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .help("打开 \(app.displayName)")
        .task(id: app.id) {
            if icon == nil {
                icon = await ToolboxLauncher.shared.icon(for: app, targetSize: CGSize(width: 36, height: 36))
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.neonYellow)
            }
        }
    }

    private var fallbackSymbol: String {
        switch app.id {
        case "chatgpt-app", "chatgpt-web":
            return "bubble.left.and.bubble.right.fill"
        case "claude-app", "claude-web":
            return "sparkle"
        case "gemini":
            return "globe"
        case "grok":
            return "bolt"
        default:
            return "app.fill"
        }
    }

    @ViewBuilder
    private var optionBadge: some View {
        Text(app.optionKind.badgeText)
            .font(.system(size: 9, weight: .bold))
            .textCase(.uppercase)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(app.optionKind == .nativeApp ? Color.neonYellow.opacity(0.9) : Color.black.opacity(0.75))
            )
            .foregroundStyle(app.optionKind == .nativeApp ? Color.black : Color.white)
    }
}
