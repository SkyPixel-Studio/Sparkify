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
    @State private var searchPresented: Bool = false
    @State private var presentedPrompt: PromptItem?
    @State private var activeFilter: PromptListFilter = .all
    @State private var isExporting: Bool = false
    @State private var exportDocument: PromptArchiveDocument = .empty()
    @State private var isImporting: Bool = false
    @State private var alertItem: AlertItem?
    @State private var operationToast: OperationToast?
    @State private var isShowingSettings: Bool = false
    @State private var highlightedPromptID: String?
    @State private var showAgentContextExportWarning: Bool = false
    @State private var showAgentContextInfoAlert: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all


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

    /// Provide an intrinsic size large enough for the initial SwiftUI window.
    private let minimumWindowSize = CGSize(width: 1280, height: 720)

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarListView(
                prompts: prompts,
                presentedPrompt: $presentedPrompt,
                deletePrompt: deletePrompts,
                togglePinPrompt: togglePinPrompt,
                copyFilledPrompt: copyFilledPrompt,
                copyTemplateOnly: copyTemplateOnly,
                clonePrompt: clonePrompt,
                resetAllParams: resetAllParams,
                activeFilter: $activeFilter,
                onImport: { isImporting = true },
                onExport: { prepareExport() },
                onSettings: { isShowingSettings = true },
                onHighlightPrompt: { prompt in
                    highlightedPromptID = prompt.uuid
                    // 清除高亮，2秒后自动消失
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if highlightedPromptID == prompt.uuid {
                            withAnimation(.easeOut(duration: 0.3)) {
                                highlightedPromptID = nil
                            }
                        }
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 400)
        } detail: {
            TemplateGridView(
                prompts: filteredPrompts,
                totalPromptCount: prompts.count,
                availableTags: availableTags,
                activeFilter: activeFilter,
                onSelectFilter: { activeFilter = $0 },
                onOpenDetail: { presentedPrompt = $0 },
                onImport: { isImporting = true },
                onExport: { prepareExport() },
                searchText: $searchText,
                searchPresented: $searchPresented,
                onAddPrompt: addPrompt,
                onAddAgentContextPrompt: addAgentContextPrompt,
                onDeletePrompt: deletePrompt(_:),
                onClonePrompt: clonePrompt(_:),
                onShowToast: { message, icon in
                    showToast(message: message, icon: icon)
                },
                onPresentError: { title, message in
                    presentAlert(title: title, message: message)
                },
                highlightedPromptID: $highlightedPromptID
            )
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.focusSearchAction) {
            searchPresented = true
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "SparkifyPrompts"
        ) { result in
            if case let .failure(error) = result {
                alertItem = AlertItem(
                    title: String(localized: "export_failure", defaultValue: "导出失败"),
                    message: "无法写入文件，请检查权限或磁盘空间。\n\(error.localizedDescription)"
                )
            } else {
                showToast(message: String(localized: "export_success", defaultValue: "导出成功"), icon: "arrow.up.doc")
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
                    title: String(localized: "import_failure", defaultValue: "导入失败"),
                    message: "无法读取文件：\(error.localizedDescription)"
                )
            }
        }
        .alert(item: $alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(String(localized: "ok", defaultValue: "好")))
            )
        }
        .alert(String(localized: "export_hint", defaultValue: "导出提示"), isPresented: $showAgentContextExportWarning) {
            Button(String(localized: "continue_export", defaultValue: "继续导出")) {
                performExport()
            }.tint(Color.neonYellow)
            Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) { }
        } message: {
            Text(String(localized: "agent_context_export_warning", defaultValue: "检测到代理上下文模板。这类模板的文件关联信息不会被导出，重新导入后需要重新关联本地文件。"))
        }
        .alert(String(localized: "agent_context_info_alert_title", defaultValue: "关于代理上下文模板"), isPresented: $showAgentContextInfoAlert) {
            Button(String(localized: "continue_dont_remind", defaultValue: "继续，下次不再提醒")) {
                PreferencesService.shared.showAgentContextInfoAlert = false
                proceedWithAgentContextSelection()
            }.tint(Color.neonYellow)
            Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) { }
        } message: {
            Text(String(localized: "agent_context_info_alert_message", defaultValue: "代理上下文模板是适用于 Codex、Claude Code 等命令行代理的系统指令文档，储存于文件中。\n\n选取对应文件后，您可以在 Sparkify 内统一管理这些模板。"))
        }
        .overlay(alignment: .top) {
            if let toast = operationToast {
                OperationToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 20)
            }
        }
        .frame(minWidth: minimumWindowSize.width, minHeight: minimumWindowSize.height)
    }

    private func addPrompt() {
        withAnimation {
            var initialTags: [String] = []
            if case let .tag(tagName) = activeFilter {
                initialTags = [tagName]
            }
            
            let newPrompt = PromptItem(
                title: String(localized: "new_template", defaultValue: "新模板"),
                body: "",
                tags: initialTags
            )
            modelContext.insert(newPrompt)
            presentedPrompt = newPrompt
            do {
                try modelContext.save()
            } catch {
                print("保存新模板失败: \(error)")
            }
        }
    }

    private func addAgentContextPrompt() {
        // Check if we should show the info alert
        if PreferencesService.shared.showAgentContextInfoAlert {
            showAgentContextInfoAlert = true
        } else {
            proceedWithAgentContextSelection()
        }
    }

    private func proceedWithAgentContextSelection() {
        Task { @MainActor in
            do {
                let urls = try AgentContextFileService.shared.chooseMarkdownFiles()
                let attachments = try AgentContextFileService.shared.makeAttachments(from: urls)
                guard let primaryAttachment = attachments.first else {
                    presentAlert(
                        title: String(localized: "create_template_failure", defaultValue: "无法创建模板"),
                        message: "未检测到有效的 Markdown 文件，请重新选择。"
                    )
                    return
                }

                let pullResult = AgentContextFileService.shared.pullContent(from: primaryAttachment)
                if let error = pullResult.error {
                    presentAlert(
                        title: String(localized: "import_failure", defaultValue: "导入失败"),
                        message: error.localizedDescription
                    )
                    return
                }

                let initialBody = pullResult.content ?? ""
                var initialTags: [String] = []
                if case let .tag(tagName) = activeFilter {
                    initialTags = [tagName]
                }

                let suggestedTitle = urls.first?.deletingPathExtension().lastPathComponent ?? primaryAttachment.displayName
                let newPrompt = PromptItem(
                    title: suggestedTitle.isEmpty ? String(localized: "new_agent_context_template", defaultValue: "代理上下文模板") : suggestedTitle,
                    body: initialBody,
                    tags: initialTags,
                    attachments: attachments,
                    kind: .agentContext
                )
                modelContext.insert(newPrompt)
                presentedPrompt = newPrompt
                do {
                    try modelContext.save()
                    showToast(message: String(localized: "created_agent_context", defaultValue: "已创建代理上下文模板"), icon: "doc.badge.plus")
                } catch {
                    presentAlert(
                        title: String(localized: "save_failure", defaultValue: "保存失败"),
                        message: error.localizedDescription
                    )
                }
            } catch AgentContextFileService.SelectionError.userCancelled {
                // 用户取消选择，忽略
            } catch {
                presentAlert(
                    title: String(localized: "create_template_failure", defaultValue: "无法创建模板"),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func deletePrompt(_ prompt: PromptItem) {
        let displayName = prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title
        if presentedPrompt?.persistentModelID == prompt.persistentModelID {
            presentedPrompt = nil
        }

        deletePrompts([prompt])
        guard modelContext.hasChanges == false else { return }
        showToast(
            message: String(format: String(localized: "delete_prompt_success", defaultValue: "已删除 %@"), displayName),
            icon: "trash.fill"
        )
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
    
    private func togglePinPrompt(_ prompt: PromptItem) {
        withAnimation {
            prompt.pinned.toggle()
            do {
                try modelContext.save()
            } catch {
                print("切换置顶失败: \(error)")
            }
        }
    }
    
    private func copyFilledPrompt(_ prompt: PromptItem) {
        let values = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0.resolvedValue) })
        let result = TemplateEngine.render(template: prompt.body, values: values)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(result.rendered, forType: .string) {
            showToast(
                message: String(localized: "copy_success", defaultValue: "已复制"),
                icon: "doc.on.doc.fill"
            )
        } else {
            alertItem = AlertItem(
                title: String(localized: "copy_failed", defaultValue: "复制失败"),
                message: String(localized: "cannot_write_to_clipboard", defaultValue: "无法写入剪贴板")
            )
        }
    }
    
    private func copyTemplateOnly(_ prompt: PromptItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(prompt.body, forType: .string) {
            showToast(
                message: String(localized: "template_copied", defaultValue: "已复制模板"),
                icon: "doc.on.doc.fill"
            )
        } else {
            alertItem = AlertItem(
                title: String(localized: "copy_failed", defaultValue: "复制失败"),
                message: String(localized: "cannot_write_to_clipboard", defaultValue: "无法写入剪贴板")
            )
        }
    }
    
    private func resetAllParams(_ prompt: PromptItem) {
        withAnimation {
            for param in prompt.params {
                param.value = param.defaultValue ?? ""
            }
            do {
                try modelContext.save()
                showToast(
                    message: String(localized: "params_reset_success", defaultValue: "已重置所有参数"),
                    icon: "arrow.counterclockwise.circle.fill"
                )
            } catch {
                alertItem = AlertItem(
                    title: String(localized: "reset_failed", defaultValue: "重置失败"),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func clonePrompt(_ prompt: PromptItem) {
        let baseTitle = prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title
        let paramsCopy = prompt.params.map { param in
            ParamKV(
                key: param.key,
                value: param.value,
                defaultValue: param.defaultValue
            )
        }

        let clonedTitle = makeClonedTitle(from: baseTitle)
        let clonedPrompt = PromptItem(
            title: clonedTitle,
            body: prompt.body,
            tags: prompt.tags,
            params: paramsCopy,
            attachments: [],
            kind: prompt.kind
        )

        modelContext.insert(clonedPrompt)

        do {
            try modelContext.save()
            showToast(
                message: String(format: String(localized: "clone_prompt_success", defaultValue: "已克隆 %@"), baseTitle),
                icon: "doc.on.doc.fill"
            )
        } catch {
            alertItem = AlertItem(
                title: "克隆失败",
                message: error.localizedDescription
            )
        }
    }

    private func makeClonedTitle(from base: String) -> String {
        // Try simple cloned format first
        let simpleClone = String(
            localized: "cloned_title_format",
            defaultValue: "%@ 副本"
        )
        var attempt = String(format: simpleClone, base)
        
        // If that title doesn't exist, we're done
        guard prompts.contains(where: { $0.title == attempt }) else {
            return attempt
        }
        
        // Otherwise, try numbered formats
        let numberedClone = String(
            localized: "cloned_title_numbered_format",
            defaultValue: "%@ 副本 %lld"
        )
        var index = 2
        repeat {
            attempt = String(format: numberedClone, base, index)
            index += 1
        } while prompts.contains(where: { $0.title == attempt })
        
        return attempt
    }

    private func prepareExport() {
        guard prompts.isEmpty == false else {
            alertItem = AlertItem(
                title: String(localized: "no_exportable_templates", defaultValue: "没有可导出的模板"),
                message: String(localized: "no_exportable_templates_message", defaultValue: "先创建或导入一些模板，再尝试导出吧。")
            )
            return
        }
        
        // 检查是否有代理上下文类型的模板
        let hasAgentContext = prompts.contains { $0.kind == .agentContext }
        
        if hasAgentContext {
            showAgentContextExportWarning = true
        } else {
            performExport()
        }
    }
    
    private func performExport() {
        do {
            let data = try PromptTransferService.exportData(from: prompts)
            exportDocument = PromptArchiveDocument(data: data)
            isExporting = true
        } catch {
            alertItem = AlertItem(
                title: String(localized: "export_failure", defaultValue: "导出失败"),
                message: "无法生成导出文件：\(error.localizedDescription)"
            )
        }
    }

    private func handleImport(from url: URL) {
        // 获取安全范围资源访问权限
        guard url.startAccessingSecurityScopedResource() else {
            alertItem = AlertItem(
                title: String(localized: "import_failure", defaultValue: "导入失败"),
                message: "无法访问选定的文件，请检查文件权限。"
            )
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let summary = try PromptTransferService.importData(data, into: modelContext)
            let message: String
            if summary.inserted == 0 && summary.updated == 0 {
                message = "导入完成，但没有发生变更"
            } else {
                message = String(format: String(localized: "import_success", defaultValue: "导入成功：新增 %lld · 更新 %lld"), summary.inserted, summary.updated)
            }
            showToast(message: message, icon: "square.and.arrow.down")
        } catch let error as PromptTransferError {
            alertItem = AlertItem(
                title: String(localized: "import_failure", defaultValue: "导入失败"),
                message: error.detailedMessage
            )
        } catch {
            alertItem = AlertItem(
                title: String(localized: "import_failure", defaultValue: "导入失败"),
                message: error.localizedDescription
            )
        }
    }

    private func performManualSave() {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
                showToast(message: String(localized: "saved_all_changes", defaultValue: "已保存所有更改"), icon: "tray.and.arrow.down.fill")
            } else {
                showToast(message: "当前没有待保存的更改", icon: "checkmark.circle")
            }
        } catch {
            alertItem = AlertItem(
                title: String(localized: "save_failure", defaultValue: "保存失败"),
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
        let displayName = deletedTitle.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : deletedTitle
        showToast(
            message: String(format: String(localized: "delete_prompt_success", defaultValue: "已删除 %@"), displayName),
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

    private func presentAlert(title: String, message: String) {
        alertItem = AlertItem(title: title, message: message)
    }

    private func synchronizeParams(for prompt: PromptItem) {
        let descriptors = TemplateEngine.placeholderDescriptors(in: prompt.body)
        var existing = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0) })
        var ordered: [ParamKV] = []

        for descriptor in descriptors {
            if let current = existing.removeValue(forKey: descriptor.key) {
                apply(descriptor: descriptor, to: current)
                ordered.append(current)
                continue
            }

            let type: PromptParamType
            switch descriptor.kind {
            case .text:
                type = .text
            case .enumeration:
                type = .enumeration
            case .toggle:
                type = .toggle
            }

            let defaultValue: String?
            switch descriptor.kind {
            case .toggle(_, let offText):
                defaultValue = offText
            default:
                defaultValue = nil
            }

            let created = ParamKV(
                key: descriptor.key,
                value: "",
                defaultValue: defaultValue,
                type: type,
                options: descriptor.options,
                owner: prompt
            )
            ordered.append(created)
        }
        prompt.params = ordered
    }

    private func apply(descriptor: TemplateEngine.PlaceholderDescriptor, to param: ParamKV) {
        switch descriptor.kind {
        case .text:
            param.type = .text
            param.options = []
        case .enumeration(let options):
            param.type = .enumeration
            param.options = options
            if let defaultValue = param.defaultValue, options.contains(defaultValue) == false {
                param.defaultValue = nil
            }

            let current = param.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if current.isEmpty == false, options.contains(current) == false {
                param.value = ""
            }
        case .toggle(let on, let off):
            param.type = .toggle
            param.options = [on, off]
            if let defaultValue = param.defaultValue,
               defaultValue != on,
               defaultValue != off {
                param.defaultValue = off
            }

            if param.defaultValue == nil {
                param.defaultValue = off
            }

            let current = param.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if current != on && current != off {
                param.value = off
            }
        }
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

    return ContentView()
        .modelContainer(container)
}
