//
//  SettingsView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import AppKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var prompts: [PromptItem]
    
    @State private var preferences = PreferencesService.shared
    @State private var localization = LocalizationService.shared
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var iconRefreshID = UUID()
    @State private var showLanguageRestartAlert = false
    @State private var isShowingLicenseSheet = false
    @State private var licenseText: String = ""
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        @Bindable var preferences = preferences
        @Bindable var localization = localization
        let orderedApps = orderedToolboxApps

        return NavigationStack {
            Form {
                // MARK: - User Preferences
                Section {
                    Picker(String(localized: "theme_appearance", defaultValue: "界面主题"), selection: $preferences.themePreference) {
                        ForEach(ThemePreference.allCases) { preference in
                            Text(preference.localizedName).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.neonYellow)

                    // Language Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(String(localized: "current_language", defaultValue: "语言"), selection: $localization.currentLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: localization.currentLanguage) { _, _ in
                            if localization.requiresRestart {
                                showLanguageRestartAlert = true
                            }
                        }
                        
                        Text(String(localized: "language_requires_restart", defaultValue: "语言更改将在重启应用后生效。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField(String(localized: "signature", defaultValue: "签名"), text: $preferences.userSignature)
                                .textFieldStyle(.plain)
                            
                            Button {
                                preferences.resetSignatureToDefault()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(preferences.userSignature == NSUserName())
                            .help(String(localized: "reset_to_system_username", defaultValue: "重置为系统用户名"))
                        }
                        
                        Text(String(localized: "signature_description", defaultValue: "签名将作为版本历史的作者名称。默认使用系统用户名。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                
                } header: {
                    Text(String(localized: "general_settings", defaultValue: "通用设置"))
                }

                Section {
                    ForEach(Array(orderedApps.enumerated()), id: \.element.id) { index, app in
                        ToolboxSettingsRow(
                            app: app,
                            isEnabled: Binding(
                                get: { preferences.isToolEnabled(app) },
                                set: { preferences.setTool(app, enabled: $0) }
                            ),
                            canMoveUp: index > 0,
                            canMoveDown: index < orderedApps.count - 1,
                            onMoveUp: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    preferences.moveToolboxAppUp(at: index)
                                }
                            },
                            onMoveDown: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    preferences.moveToolboxAppDown(at: index)
                                }
                            }
                        )
                        .id("\(app.id)-\(iconRefreshID)")
                    }
                } header: {
                    HStack {
                        Text(String(localized: "toolbox_quick_access", defaultValue: "Toolbox 快捷入口"))
                        Spacer()
                        Button {
                            clearIconCache()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "clear_icon_cache", defaultValue: "清理图标缓存"))
                    }
                } footer: {
                    Text(String(localized: "toolbox_description", defaultValue: "启用后，模板列表右下角会出现 toolbox 按钮，可快速打开所选的 AI 助手或网页。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // MARK: - About Section
                Section(String(localized: "about_sparkify", defaultValue: "关于 Sparkify")) {
                    HStack {
                        Text(String(localized: "version", defaultValue: "版本"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                    }
                    
                    HStack {
                        Text(String(localized: "current_template_count", defaultValue: "当前模板数量"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(prompts.count)")
                    }
                    
                    Button {
                        openPrivacyPolicy()
                    } label: {
                        HStack {
                            Text(String(localized: "privacy_policy", defaultValue: "隐私政策"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        openTechnicalSupport()
                    } label: {
                        HStack {
                            Text(String(localized: "technical_support", defaultValue: "技术支持"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(String(localized: "open_source_licenses", defaultValue: "开源许可")) {
                    Button {
                        presentLicenseViewer()
                    } label: {
                        HStack {
                            Text(String(localized: "view_third_party_licenses", defaultValue: "查看第三方协议"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // MARK: - Developer Options (Debug Only)
                if isDebugMode {
                    Section {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            Label(String(localized: "reset_to_default_templates", defaultValue: "重置为默认模板"), systemImage: "arrow.counterclockwise")
                                .foregroundStyle(.orange)
                        }
                        
                        Button {
                            printAllPrompts()
                        } label: {
                            Label("打印所有模板到控制台", systemImage: "terminal")
                        }
                        
                        Button {
                            printSwiftDataStatus()
                        } label: {
                            Label("打印 SwiftData 状态", systemImage: "info.circle")
                        }
                    } header: {
                        HStack {
                            Image(systemName: "ladybug")
                            Text(String(localized: "developer_options", defaultValue: "开发者选项"))
                        }
                        .foregroundStyle(.pink)
                    } footer: {
                        Text("这些选项仅在 Debug 构建中可见")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "settings", defaultValue: "设置"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done", defaultValue: "完成")) {
                        dismiss()
                    }
                    .tint(Color.neonYellow)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .alert(String(localized: "reset_to_default_templates", defaultValue: "重置为默认模板？"), isPresented: $showResetConfirmation) {
                Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) { }
                Button(String(localized: "reset", defaultValue: "重置"), role: .destructive) {
                    resetToSeedData()
                }
            } message: {
                Text(String(localized: "reset_to_default_templates_confirm", defaultValue: "此操作将删除所有现有模板，并重新加载默认的种子数据。此操作不可撤销。"))
            }
            .alert(String(localized: "reset_success", defaultValue: "重置成功"), isPresented: $showResetSuccess) {
                Button(String(localized: "ok", defaultValue: "好")) { }
            } message: {
                Text(String(localized: "reset_success_message", defaultValue: "已重置为默认模板"))
            }
            .alert(String(localized: "settings", defaultValue: "设置"), isPresented: $showLanguageRestartAlert) {
                Button(String(localized: "ok", defaultValue: "好")) { }
            } message: {
                Text(String(localized: "language_requires_restart", defaultValue: "语言更改将在重启应用后生效。"))
            }
            .sheet(isPresented: $isShowingLicenseSheet) {
                LicenseViewer(text: licenseText)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    // MARK: - Developer Actions
    
    private func resetToSeedData() {
        do {
            // Delete all existing prompts
            for prompt in prompts {
                modelContext.delete(prompt)
            }
            
            try modelContext.save()
            
            // Reset the seed data initialization flag so it can be reloaded
            preferences.resetSeedDataFlag()
            
            // Reload seed data
            try SeedDataLoader.ensureSeedData(using: modelContext)
            
            showResetSuccess = true
            
            print("✅ [Settings] Reset to seed data completed")
        } catch {
            print("❌ [Settings] Failed to reset: \(error)")
        }
    }
    
    private func printAllPrompts() {
        print("\n" + String(repeating: "=", count: 60))
        print("📋 All Prompts in Database (\(prompts.count) total)")
        print(String(repeating: "=", count: 60))
        
        for (index, prompt) in prompts.enumerated() {
            print("\n[\(index + 1)] \(prompt.title)")
            print("   UUID: \(prompt.uuid)")
            print("   Pinned: \(prompt.pinned)")
            print("   Tags: \(prompt.tags.joined(separator: ", "))")
            print("   Params: \(prompt.params.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
            print("   Created: \(prompt.createdAt)")
            print("   Updated: \(prompt.updatedAt)")
            print("   Body: \(prompt.body.prefix(100))...")
        }
        
        print("\n" + String(repeating: "=", count: 60) + "\n")
    }
    
    private func printSwiftDataStatus() {
        print("\n" + String(repeating: "=", count: 60))
        print("💾 SwiftData Status")
        print(String(repeating: "=", count: 60))
        print("Model Context: \(modelContext)")
        print("Has Changes: \(modelContext.hasChanges)")
        print("Total Prompts: \(prompts.count)")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    private func clearIconCache() {
        ToolboxLauncher.shared.evictCache()
        iconRefreshID = UUID()
        print("🗑️ [Settings] Icon cache cleared")
    }
    
    private func openPrivacyPolicy() {
        let urlString: String
        
        urlString = "https://troubled-floss-968.notion.site/Sparkify-Privacy-Policy-292fec5a12c080d3818ff84667b4e7a1?source=copy_link"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openTechnicalSupport() {
        let urlString: String
        
        urlString = "https://troubled-floss-968.notion.site/Sparkify-Support-292fec5a12c080b6b4f2e6f68392f39f?source=copy_link"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func presentLicenseViewer() {
        licenseText = loadLicenseText() ?? String(localized: "license_load_failed", defaultValue: "无法加载第三方协议。")
        isShowingLicenseSheet = true
    }
    
    private func loadLicenseText() -> String? {
        guard let asset = NSDataAsset(name: "ThirdPartyLicenses") else {
            return nil
        }
        if let string = String(data: asset.data, encoding: .utf8) {
            return string
        }
        return String(decoding: asset.data, as: UTF8.self)
    }
}

extension SettingsView {
    private var orderedToolboxApps: [ToolboxApp] {
        preferences.toolboxOrder
            .compactMap { ToolboxApp.app(withID: $0) }
            .filter { $0.isInstalled }
    }
}

private struct ToolboxSettingsRow: View {
    let app: ToolboxApp
    @Binding var isEnabled: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    @State private var icon: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.cardOutline.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if app.optionKind == .web {
                        webLinkButton
                    }
                    
                    toolboxBadge
                }
                Text(app.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            moveControls
                .padding(.trailing, 2)

            Toggle(isOn: $isEnabled) {
                EmptyView()
            }.tint(Color.neonYellow)
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .task {
            if icon == nil {
                icon = await ToolboxLauncher.shared.icon(for: app, targetSize: CGSize(width: 32, height: 32))
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.cardSurface)
                Image(systemName: appFallbackSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.neonYellow)
            }
        }
    }

    private var appFallbackSymbol: String {
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
            return "app.dashed"
        }
    }

    private var toolboxBadge: some View {
        Text(app.optionKind.badgeText)
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(app.optionKind == .nativeApp ? Color.neonYellow.opacity(0.25) : Color.cardSurface)
            )
            .foregroundStyle(app.optionKind == .nativeApp ? Color.accentForeground : Color.secondary)
    }

    private var webLinkButton: some View {
        Button {
            openWebLink()
        } label: {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.neonYellow.opacity(0.8))
        }
        .buttonStyle(.plain)
        .help(String(localized: "open_in_browser", defaultValue: "在浏览器中打开"))
    }

    private var moveControls: some View {
        VStack(spacing: 4) {
            moveButton(
                systemImage: "chevron.up",
                action: onMoveUp,
                disabled: canMoveUp == false
            )
            moveButton(
                systemImage: "chevron.down",
                action: onMoveDown,
                disabled: canMoveDown == false
            )
        }
    }

    private func moveButton(systemImage: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 22)
                .foregroundStyle(disabled ? Color.secondary.opacity(0.45) : Color.appForeground.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.cardSurface.opacity(disabled ? 0.35 : 0.85))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(systemImage == "chevron.up" ? String(localized: "move_up", defaultValue: "上移") : String(localized: "move_down", defaultValue: "下移"))
    }

    private func openWebLink() {
        guard case let .web(url) = app.launchTarget else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct LicenseViewer: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "third_party_licenses_title", defaultValue: "第三方协议"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(String(localized: "close", defaultValue: "关闭")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

#Preview {
    let container: ModelContainer = {
        let schema = Schema([
            PromptItem.self,
            ParamKV.self,
            PromptRevision.self,
            PromptFileAttachment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        try? SeedDataLoader.ensureSeedData(using: container.mainContext)
        return container
    }()
    
    return SettingsView()
        .modelContainer(container)
}
