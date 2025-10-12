//
//  ContentView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/11.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromptItem.updatedAt, order: .reverse)
    private var prompts: [PromptItem]

    @State private var searchText: String = ""
    @State private var presentedPrompt: PromptItem?
    @State private var activeFilter: PromptListFilter = .all
    @State private var isExporting: Bool = false
    @State private var exportDocument: PromptArchiveDocument = .empty()
    @State private var isImporting: Bool = false
    @State private var alertItem: AlertItem?
    @State private var operationToast: OperationToast?
    @FocusState private var searchFieldFocused: Bool

    private var filteredPrompts: [PromptItem] {
        var candidates = prompts

        switch activeFilter {
        case .all:
            break
        case .pinned:
            candidates = candidates.filter { $0.pinned }
        case let .tag(tag):
            candidates = candidates.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }

        guard searchText.isEmpty == false else { return candidates }
        let query = searchText.lowercased()
        return candidates.filter { prompt in
            let searchable = (prompt.title + " " + prompt.body + " " + prompt.tags.joined(separator: " ")).lowercased()
            return searchable.contains(query)
        }
    }

    private var availableTags: [String] {
        let tagSet = Set(prompts.flatMap { $0.tags })
        return tagSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            SidebarListView(
                prompts: prompts,
                presentedPrompt: $presentedPrompt,
                addPrompt: addPrompt,
                deletePrompt: deletePrompts,
                searchText: $searchText,
                activeFilter: $activeFilter,
                searchFieldFocus: $searchFieldFocused,
                onImport: { isImporting = true },
                onExport: { prepareExport() }
            )
        } detail: {
            TemplateGridView(
                prompts: filteredPrompts,
                availableTags: availableTags,
                activeFilter: activeFilter,
                onSelectFilter: { activeFilter = $0 },
                onOpenDetail: { presentedPrompt = $0 },
                onImport: { isImporting = true },
                onExport: { prepareExport() }
            )
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.focusSearchAction) {
            searchFieldFocused = true
        }
        .focusedSceneValue(\.saveAction) {
            performManualSave()
        }
        .focusedSceneValue(\.deleteAction) {
            performDeleteShortcut()
        }
        .sheet(item: $presentedPrompt) { prompt in
            PromptDetailView(prompt: prompt)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "SparkifyPrompts"
        ) { result in
            if case let .failure(error) = result {
                alertItem = AlertItem(
                    title: "导出失败",
                    message: "无法写入文件，请检查权限或磁盘空间。\n\(error.localizedDescription)"
                )
            } else {
                showToast(message: "导出成功", icon: "arrow.up.doc")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                handleImport(from: url)
            case let .failure(error):
                alertItem = AlertItem(
                    title: "导入失败",
                    message: "无法读取文件：\(error.localizedDescription)"
                )
            }
        }
        .alert(item: $alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
        }
        .overlay(alignment: .top) {
            if let toast = operationToast {
                OperationToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 20)
            }
        }
    }

    private func addPrompt() {
        withAnimation {
            let newPrompt = PromptItem(
                title: "新模板",
                body: "Hello {name}, welcome to {product}."
            )
            synchronizeParams(for: newPrompt)
            modelContext.insert(newPrompt)
            presentedPrompt = newPrompt
            do {
                try modelContext.save()
            } catch {
                print("保存新模板失败: \(error)")
            }
        }
    }

    private func deletePrompts(_ items: [PromptItem]) {
        guard items.isEmpty == false else { return }
        withAnimation {
            items.forEach(modelContext.delete)
            do {
                try modelContext.save()
            } catch {
                print("删除模板失败: \(error)")
            }
        }
    }

    private func prepareExport() {
        guard prompts.isEmpty == false else {
            alertItem = AlertItem(
                title: "没有可导出的模板",
                message: "先创建或导入一些模板，再尝试导出吧。"
            )
            return
        }

        do {
            let data = try PromptTransferService.exportData(from: prompts)
            exportDocument = PromptArchiveDocument(data: data)
            isExporting = true
        } catch {
            alertItem = AlertItem(
                title: "导出失败",
                message: "无法生成导出文件：\(error.localizedDescription)"
            )
        }
    }

    private func handleImport(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let summary = try PromptTransferService.importData(data, into: modelContext)
            let message: String
            if summary.inserted == 0 && summary.updated == 0 {
                message = "导入完成，但没有发生变更"
            } else {
                message = "导入成功：新增 \(summary.inserted) · 更新 \(summary.updated)"
            }
            showToast(message: message, icon: "square.and.arrow.down")
        } catch let error as PromptTransferError {
            alertItem = AlertItem(
                title: "导入失败",
                message: error.detailedMessage
            )
        } catch {
            alertItem = AlertItem(
                title: "导入失败",
                message: error.localizedDescription
            )
        }
    }

    private func performManualSave() {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
                showToast(message: "已保存所有更改", icon: "tray.and.arrow.down.fill")
            } else {
                showToast(message: "当前没有待保存的更改", icon: "checkmark.circle")
            }
        } catch {
            alertItem = AlertItem(
                title: "保存失败",
                message: error.localizedDescription
            )
        }
    }

    private func performDeleteShortcut() {
        guard let prompt = presentedPrompt else {
            alertItem = AlertItem(
                title: "无法删除模板",
                message: "请先在列表中选择或打开一个模板，然后再按 ⌘⌫。"
            )
            return
        }
        let deletedTitle = prompt.title
        deletePrompts([prompt])
        presentedPrompt = nil
        let displayName = deletedTitle.isEmpty ? "未命名模板" : deletedTitle
        showToast(
            message: "已删除 \(displayName)",
            icon: "trash.fill"
        )
    }

    private func showToast(message: String, icon: String) {
        let toast = OperationToast(message: message, iconSystemName: icon)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            operationToast = toast
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if operationToast?.id == toast.id {
                withAnimation(.easeInOut(duration: 0.25)) {
                    operationToast = nil
                }
            }
        }
    }

    private func synchronizeParams(for prompt: PromptItem) {
        let keys = TemplateEngine.placeholders(in: prompt.body)
        var existing = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0) })
        var ordered: [ParamKV] = []
        for key in keys {
            if let current = existing.removeValue(forKey: key) {
                ordered.append(current)
            } else {
                let created = ParamKV(key: key, value: "")
                created.owner = prompt
                ordered.append(created)
            }
        }
        prompt.params = ordered
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

    return ContentView()
        .modelContainer(container)
}
