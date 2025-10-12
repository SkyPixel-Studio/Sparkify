//
//  SettingsView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var prompts: [PromptItem]
    
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    
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
        NavigationStack {
            Form {
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
}

#Preview {
    let container: ModelContainer = {
        let schema = Schema([PromptItem.self, ParamKV.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        try? SeedDataLoader.ensureSeedData(using: container.mainContext)
        return container
    }()
    
    return SettingsView()
        .modelContainer(container)
}

