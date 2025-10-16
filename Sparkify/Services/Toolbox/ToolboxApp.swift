//
//  ToolboxApp.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import Foundation
import SwiftUI

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
    let displayNameKey: String
    let summaryKey: String
    let launchTarget: LaunchTarget
    let iconSources: [IconSource]
    let optionKind: OptionKind
    let isEnabledByDefault: Bool
    
    var displayName: String {
        String(localized: String.LocalizationValue(displayNameKey))
    }
    
    var summary: String {
        String(localized: String.LocalizationValue(summaryKey))
    }

    /// Check if this app is installed (for native apps only; web apps always return true)
    var isInstalled: Bool {
        ToolboxLauncher.shared.isAppInstalled(self)
    }
    
    static let all: [ToolboxApp] = [
        ToolboxApp(
            id: "chatgpt-app",
            displayNameKey: "toolbox_chatgpt_name",
            summaryKey: "toolbox_chatgpt_app_summary",
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
            displayNameKey: "toolbox_chatgpt_name",
            summaryKey: "toolbox_chatgpt_web_summary",
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
            displayNameKey: "toolbox_claude_name",
            summaryKey: "toolbox_claude_app_summary",
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
            displayNameKey: "toolbox_claude_name",
            summaryKey: "toolbox_claude_web_summary",
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
            displayNameKey: "toolbox_gemini_name",
            summaryKey: "toolbox_gemini_summary",
            launchTarget: .web(url: URL(string: "https://gemini.google.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://www.gstatic.com/lamda/images/gemini_sparkle_4g_512_lt_f94943af3be039176192d.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault:  true
        ),
        ToolboxApp(
            id: "aistudio",
            displayNameKey: "toolbox_google_ai_studio_name",
            summaryKey: "toolbox_google_ai_studio_summary",
            launchTarget: .web(url: URL(string: "https://aistudio.google.com/")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://www.gstatic.com/aistudio/ai_studio_favicon_2_32x32.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "grok",
            displayNameKey: "toolbox_grok_name",
            summaryKey: "toolbox_grok_summary",
            launchTarget: .web(url: URL(string: "https://grok.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://grok.com/images/favicon-light.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "qwen",
            displayNameKey: "toolbox_qwen_name",
            summaryKey: "toolbox_qwen_summary",
            launchTarget: .web(url: URL(string: "https://chat.qwen.ai/")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://assets.alicdn.com/g/qwenweb/qwen-webui-fe/0.0.223/favicon.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "qwen-cn",
            displayNameKey: "toolbox_tongyi_qwen_name",
            summaryKey: "toolbox_tongyi_qwen_summary",
            launchTarget: .web(url: URL(string: "https://www.tongyi.com/")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://img.alicdn.com/imgextra/i4/O1CN01EfJVFQ1uZPd7W4W6i_!!6000000006051-2-tps-112-112.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "doubao",
            displayNameKey: "toolbox_doubao_name",
            summaryKey: "toolbox_doubao_summary",
            launchTarget: .web(url: URL(string: "https://www.doubao.com")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://ark-auto-2100466578-cn-beijing-default.tos-cn-beijing.volces.com/model_cardPt9S1OY9sV.png")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        ),
        ToolboxApp(
            id: "deepseek",
            displayNameKey: "toolbox_deepseek_name",
            summaryKey: "toolbox_deepseek_summary",
            launchTarget: .web(url: URL(string: "https://chat.deepseek.com/")!),
            iconSources: [
                .remoteFavicon(URL(string: "https://chat.deepseek.com/favicon.svg")!),
                .systemImage(name: "globe")
            ],
            optionKind: .web,
            isEnabledByDefault: false
        )
    ]

    static let defaultOrder: [String] = all.map(\.id)

    /// Returns only apps that are installed on the system (filters out uninstalled native apps)
    static var installed: [ToolboxApp] {
        all.filter { $0.isInstalled }
    }

    static func app(withID id: String) -> ToolboxApp? {
        all.first { $0.id == id }
    }
}
