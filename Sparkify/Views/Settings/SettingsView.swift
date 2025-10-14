//
//  SettingsView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import AppKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var prompts: [PromptItem]
    
    @State private var preferences = PreferencesService.shared
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var iconRefreshID = UUID()
    
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
        let orderedApps = orderedToolboxApps

        return NavigationStack {
            Form {
                // MARK: - User Preferences
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("签名", text: $preferences.userSignature)
                                .textFieldStyle(.plain)
                            
                            Button {
                                preferences.resetSignatureToDefault()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(preferences.userSignature == NSUserName())
                            .help("重置为系统用户名")
                        }
                        
                        Text("签名将作为版本历史的作者名称。默认使用系统用户名。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("个人设置")
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
                        Text("Toolbox 快捷入口")
                        Spacer()
                        Button {
                            clearIconCache()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清理图标缓存")
                    }
                } footer: {
                    Text("启用后，模板列表右下角会出现 toolbox 按钮，可快速打开所选的 AI 助手或网页。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // MARK: - About Section
                Section("关于 Sparkify") {
                    HStack {
                        Text("版本")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                    }
                    
                    HStack {
                        Text("当前模板数量")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(prompts.count)")
                    }
                }
                
                // MARK: - Developer Options (Debug Only)
                if isDebugMode {
                    Section {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            Label("重置为默认模板", systemImage: "arrow.counterclockwise")
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
                            Text("开发者选项")
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
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .alert("重置为默认模板？", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    resetToSeedData()
                }
            } message: {
                Text("此操作将删除所有现有模板，并重新加载默认的种子数据。此操作不可撤销。")
            }
            .alert("重置成功", isPresented: $showResetSuccess) {
                Button("好") { }
            } message: {
                Text("已重置为默认模板")
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
}

extension SettingsView {
    private var orderedToolboxApps: [ToolboxApp] {
        preferences.toolboxOrder.compactMap { ToolboxApp.app(withID: $0) }
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
            }
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
            .foregroundStyle(app.optionKind == .nativeApp ? Color.black : Color.secondary)
    }

    private var webLinkButton: some View {
        Button {
            openWebLink()
        } label: {
            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor.opacity(0.8))
        }
        .buttonStyle(.plain)
        .help("在浏览器中打开")
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
        .help(systemImage == "chevron.up" ? "上移" : "下移")
    }

    private func openWebLink() {
        guard case let .web(url) = app.launchTarget else {
            return
        }
        NSWorkspace.shared.open(url)
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
