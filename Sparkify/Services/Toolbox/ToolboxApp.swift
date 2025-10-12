//
//  ToolboxApp.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation

struct ToolboxApp: Identifiable, Hashable {
    enum IconSource: Hashable {
        case appBundle(bundleID: String)
        case remoteFavicon(URL)
        case systemImage(name: String)
    }

    enum LaunchTarget: Hashable {
        case native(bundleID: String, fallbackURL: URL?)
        case web(url: URL)
    }

    enum OptionKind: String {
        case nativeApp
        case web

        var badgeText: String {
            switch self {
            case .nativeApp: return "App"
            case .web: return "Web"
            }
        }
    }

    let id: String
    let displayName: String
    let summary: String
    let launchTarget: LaunchTarget
    let iconSources: [IconSource]
    let optionKind: OptionKind
    let isEnabledByDefault: Bool

    static let all: [ToolboxApp] = [
        ToolboxApp(
            id: "chatgpt-app",
            displayName: "ChatGPT",
            summary: "OpenAI 官方 macOS 应用，需提前安装",
            launchTarget: .native(
                bundleID: "com.openai.chat",
                fallbackURL: nil
            ),
            iconSources: [
                .appBundle(bundleID: "com.openai.chat"),
                .remoteFavicon(URL(string: "https://chat.openai.com/favicon.ico")!),
                .systemImage(name: "message.fill")
            ],
            optionKind: .nativeApp,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "chatgpt-web",
            displayName: "ChatGPT",
            summary: "ChatGPT 网页客户端",
            launchTarget: .web(url: URL(string: "https://chat.openai.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://chat.openai.com/favicon.ico")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: true
        ),
        ToolboxApp(
            id: "claude-app",
            displayName: "Claude",
            summary: "Anthropic Claude macOS 应用，需提前安装",
            launchTarget: .native(
                bundleID: "com.anthropic.claude",
                fallbackURL: nil
            ),
            iconSources: [
                .appBundle(bundleID: "com.anthropic.claude"),
                .remoteFavicon(URL(string: "https://claude.ai/favicon.ico")!),
                .systemImage(name: "message.fill")
            ],
            optionKind: .nativeApp,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "claude-web",
            displayName: "Claude",
            summary: "Claude 网页客户端",
            launchTarget: .web(url: URL(string: "https://claude.ai")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://claude.ai/favicon.ico")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: true
        ),
        ToolboxApp(
            id: "gemini",
            displayName: "Gemini",
            summary: "Google Gemini 网页客户端",
            launchTarget: .web(url: URL(string: "https://gemini.google.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://www.gstatic.com/lamda/images/gemini_sparkle_4g_512_lt_f94943af3be039176192d.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault:  true
        ),
        ToolboxApp(
            id: "grok",
            displayName: "Grok",
            summary: "xAI Grok 网页客户端",
            launchTarget: .web(url: URL(string: "https://grok.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://grok.com/images/favicon-light.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        )
    ]

    static let defaultOrder: [String] = all.map(\.id)

    static func app(withID id: String) -> ToolboxApp? {
        all.first { $0.id == id }
    }
}
