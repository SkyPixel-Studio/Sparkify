//
//  SparkifyApp.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/11.
//

import SwiftUI
import SwiftData

@main
struct SparkifyApp: App {
    let sharedModelContainer: ModelContainer

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
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            SparkifyCommands()
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
