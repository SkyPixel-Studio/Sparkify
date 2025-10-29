//
//  SparkifyApp.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/11.
//

import AppKit
import SwiftUI
import SwiftData

@main
struct SparkifyApp: App {
    let sharedModelContainer: ModelContainer
    @State private var preferences = PreferencesService.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let schema = Schema([
            PromptItem.self,
            ParamKV.self,
            PromptRevision.self,
            PromptFileAttachment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try SeedDataLoader.ensureSeedData(using: container.mainContext)
            sharedModelContainer = container
        } catch {
            fatalError("无法初始化数据存储：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        @Bindable var preferences = preferences
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(preferences.resolvedColorScheme)
                .applyAppPalette(preferences.themePreference)
                .onAppear {
                    updateAppAppearance(for: preferences.themePreference)
                    configureMainWindow()
                }
                .onChange(of: preferences.themePreference) { _, newValue in
                    updateAppAppearance(for: newValue)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            SparkifyCommands()
        }
    }
    
    @MainActor
    private func configureMainWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        WindowPersistenceController.shared.configureIfNeeded(for: window)
    }

    @MainActor
    private func updateAppAppearance(for preference: ThemePreference) {
        guard let scheme = preference.forcedColorScheme else {
            NSApp.appearance = nil
            return
        }

        switch scheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        @unknown default:
            NSApp.appearance = nil
        }
    }
}

private struct SparkifyCommands: Commands {
    @FocusedValue(\.focusSearchAction) private var focusSearchAction
    @FocusedValue(\.saveAction) private var saveAction
    @FocusedValue(\.deleteAction) private var deleteAction

    var body: some Commands {
        CommandMenu(String(localized: "template_menu", defaultValue: "模板")) {
            Button(String(localized: "search_template_menu", defaultValue: "搜索模板")) {
                focusSearchAction?()
            }
            .keyboardShortcut("f", modifiers: .command)
            Button(String(localized: "save_template_changes", defaultValue: "保存模板更改")) {
                saveAction?()
            }
            .keyboardShortcut("s", modifiers: .command)
            Button(String(localized: "delete_current_template", defaultValue: "删除当前模板")) {
                deleteAction?()
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}
