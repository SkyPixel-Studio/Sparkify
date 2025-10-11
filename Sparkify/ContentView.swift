//
//  ContentView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/11.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

private enum PromptListFilter: Equatable {
    case all
    case pinned
    case tag(String)

    var analyticsName: String {
        switch self {
        case .all: return "all"
        case .pinned: return "pinned"
        case .tag(let tag): return "tag_\(tag)"
        }
    }
}

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
        case .tag(let tag):
            candidates = candidates.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }

        guard !searchText.isEmpty else { return candidates }
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
                searchFieldFocus: $searchFieldFocused
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
            case .success(let urls):
                guard let url = urls.first else { return }
                handleImport(from: url)
            case .failure(let error):
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

    fileprivate func deletePrompts(_ items: [PromptItem]) {
        guard items.isEmpty == false else { return }
        withAnimation {
            for prompt in items {
                modelContext.delete(prompt)
            }
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
        showToast(
            message: "已删除 \(deletedTitle.isEmpty ? "未命名模板" : deletedTitle)",
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

private struct PinGlyph: View {
    let isPinned: Bool
    var circleDiameter: CGFloat = 24

    private var iconName: String { isPinned ? "pin.fill" : "pin" }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: circleDiameter * 0.45, weight: .bold))
            .foregroundStyle(isPinned ? Color.black : Color.appForeground.opacity(0.6))
            .frame(width: circleDiameter, height: circleDiameter)
            .background(
                Circle()
                    .fill(isPinned ? Color.neonYellow : Color.cardSurface)
            )
            .overlay(
                Circle()
                    .stroke(Color.cardOutline.opacity(isPinned ? 0 : 0.8), lineWidth: 1)
            )
    }
}

private struct ParamFocusTarget: Hashable {
    let id: PersistentIdentifier
}

private struct SidebarListView: View {
    let prompts: [PromptItem]
    @Binding var presentedPrompt: PromptItem?
    let addPrompt: () -> Void
    let deletePrompt: ([PromptItem]) -> Void
    @Binding var searchText: String
    @Binding var activeFilter: PromptListFilter
    let searchFieldFocus: FocusState<Bool>.Binding

    private var displayedPrompts: [PromptItem] {
        var items = prompts
        switch activeFilter {
        case .all:
            break
        case .pinned:
            items = items.filter { $0.pinned }
        case .tag(let tag):
            items = items.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }

        guard !searchText.isEmpty else { return sort(items) }
        let query = searchText.lowercased()
        let filtered = items.filter { prompt in
            let searchable = (prompt.title + " " + prompt.body + " " + prompt.tags.joined(separator: " ")).lowercased()
            return searchable.contains(query)
        }
        return sort(filtered)
    }

    private func sort(_ items: [PromptItem]) -> [PromptItem] {
        items.sorted { lhs, rhs in
            if lhs.pinned == rhs.pinned {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.pinned && rhs.pinned == false
        }
    }

    var body: some View {
        List {
            Section {
                TextField("搜索模板", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused(searchFieldFocus)
                    .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                HStack(spacing: 10) {
                    FilterChip(title: "全部", isActive: activeFilter == .all) {
                        activeFilter = .all
                    }
                    FilterChip(title: "置顶", isActive: activeFilter == .pinned) {
                        activeFilter = .pinned
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)

            Section("模板") {
                if displayedPrompts.isEmpty {
                    Text("还没有模板，先新建一个吧")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(displayedPrompts) { prompt in
                        Button {
                            presentedPrompt = prompt
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(prompt.title.isEmpty ? "未命名模板" : prompt.title)
                                        .font(.headline)
                                    if prompt.pinned {
                                        PinGlyph(isPinned: true, circleDiameter: 18)
                                    }
                                }
                                Text(prompt.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let items = offsets.compactMap { index -> PromptItem? in
                            guard index < displayedPrompts.count else { return nil }
                            return displayedPrompts[index]
                        }
                        deletePrompt(items)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Sparkify")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addPrompt) {
                    Label("新建模板", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

private struct TemplateGridView: View {
    let prompts: [PromptItem]
    let availableTags: [String]
    let activeFilter: PromptListFilter
    let onSelectFilter: (PromptListFilter) -> Void
    let onOpenDetail: (PromptItem) -> Void
    let onImport: () -> Void
    let onExport: () -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 24, alignment: .top)
    ]

    private var arrangedPrompts: [PromptItem] {
        prompts.sorted { lhs, rhs in
            if lhs.pinned == rhs.pinned {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.pinned && rhs.pinned == false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 12) {
                    TemplateActionButton(
                        title: "导入 JSON",
                        systemImage: "square.and.arrow.down",
                        action: onImport
                    )
                    TemplateActionButton(
                        title: "导出 JSON",
                        systemImage: "arrow.up.doc",
                        action: onExport
                    )
                }
                Spacer()
                TagFilterMenu(
                    availableTags: availableTags,
                    activeFilter: activeFilter,
                    onSelectFilter: onSelectFilter
                )
                .opacity(availableTags.isEmpty ? 0.45 : 1)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)

            if prompts.isEmpty {
                TemplateEmptyStateView(onImport: onImport)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(arrangedPrompts) { prompt in
                            TemplateCardView(prompt: prompt) {
                                onOpenDetail(prompt)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
    }
}

private struct TagFilterMenu: View {
    let availableTags: [String]
    let activeFilter: PromptListFilter
    let onSelectFilter: (PromptListFilter) -> Void

    private var selectedTagLabel: String {
        if case let .tag(tag) = activeFilter {
            return tag
        }
        return "标签筛选"
    }

    private var currentStyle: TagStyle? {
        if case let .tag(tag) = activeFilter {
            return TagPalette.style(for: tag)
        }
        return nil
    }

    var body: some View {
        Menu {
            Button(action: { onSelectFilter(.all) }) {
                menuLabel(text: "全部标签", isSelected: activeFilter == .all)
            }
            ForEach(availableTags, id: \.self) { tag in
                Button {
                    onSelectFilter(.tag(tag))
                } label: {
                    menuLabel(text: tag, isSelected: isCurrent(tag))
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconStyle.background)
                        .frame(width: 26, height: 26)
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }

                Text(selectedTagLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconStyle.foreground)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(iconStyle.foreground.opacity(0.8))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(iconStyle.background.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .stroke(iconStyle.foreground.opacity(0.2), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private func isCurrent(_ tag: String) -> Bool {
        if case let .tag(selected) = activeFilter {
            return selected.caseInsensitiveCompare(tag) == .orderedSame
        }
        return false
    }

    private var iconStyle: TagStyle {
        currentStyle ?? TagStyle(background: Color.neonYellow.opacity(0.7), foreground: Color.black)
    }

    private func menuLabel(text: String, isSelected: Bool) -> some View {
        HStack {
            Text(text)
            if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }
}

private struct TemplateActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(Color.black)
            )
            .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let title: String
    let isActive: Bool
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? (tint ?? Color.black) : Color.cardSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isActive {
            return tint == nil ? Color.white : Color.black
        }
        return tint ?? Color.appForeground
    }

    private var borderColor: Color {
        if isActive {
            if let tint {
                return tint.opacity(0.6)
            }
            return Color.clear
        }
        return Color.cardOutline.opacity(0.8)
    }

    private var borderWidth: CGFloat { isActive && tint == nil ? 0 : 1 }
}

private struct TemplateCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem

    let onOpenDetail: () -> Void

    @State private var showCopiedHUD = false
    @FocusState private var focusedParam: ParamFocusTarget?

    private var renderResult: TemplateEngine.RenderResult {
        let values = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0.value) })
        return TemplateEngine.render(template: prompt.body, values: values)
    }

    private var neonYellow: Color { Color.neonYellow }

    private func isParamMissing(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                    .overlay(Color.cardOutline.opacity(0.4))
                parameterFields
                previewSection
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
            )

            if showCopiedHUD {
                CopiedHUDView()
                    .padding(.top, -10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(prompt.title.isEmpty ? "未命名模板" : prompt.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button {
                    togglePinned()
                } label: {
                    PinGlyph(isPinned: prompt.pinned, circleDiameter: 28)
                }
                .buttonStyle(.plain)
                .help(prompt.pinned ? "取消置顶" : "置顶")
                Button {
                    onOpenDetail()
                } label: {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                        .imageScale(.medium)
                        .padding(8)
                        .background(Capsule().strokeBorder(Color.cardOutline.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("查看更多设置")
            }

            if !prompt.tags.isEmpty {
                TagFlowLayout(spacing: 8) {
                    ForEach(prompt.tags, id: \.self) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }

            Text(prompt.body)
                .font(.footnote)
                .foregroundStyle(Color.secondary.opacity(0.8))
                .lineLimit(3)
        }
    }

    private var parameterFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            if prompt.params.isEmpty {
                Text("此模板暂无参数，直接复制即可")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($prompt.params, id: \.persistentModelID) { $param in
                    let isMissing = isParamMissing(param.value)
                    HStack(spacing: 10) {
                        Text("\(param.key)=")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.neonYellow.opacity(0.4)))
                            .foregroundStyle(Color.black)

                        TextField("{\(param.key)}", text: $param.value)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isMissing ? Color.neonYellow : Color.cardOutline, lineWidth: isMissing ? 1.6 : 1)
                        )
                        .shadow(color: isMissing ? Color.neonYellow.opacity(0.22) : Color.black.opacity(0.04), radius: isMissing ? 6 : 1.2, y: isMissing ? 3 : 1)
                        .focused($focusedParam, equals: ParamFocusTarget(id: param.persistentModelID))
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .onChange(of: param.value) { _ in
                            persistChange()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(attributedPreviewText())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cardOutline.opacity(0.5), lineWidth: 1)
                    )
                    .textSelection(.enabled)
            }
            .frame(minHeight: 120, maxHeight: 180)

            HStack(spacing: 10) {
                Button {
                    copyFilledPrompt()
                } label: {
                    Label("复制已填内容", systemImage: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.black))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: .command)

                if !renderResult.missingKeys.isEmpty {
                    Text("待填写：\(renderResult.missingKeys.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    private func attributedPreviewText() -> AttributedString {
        var attributed = AttributedString(renderResult.rendered)
        for key in renderResult.missingKeys {
            let placeholder = "{\(key)}"
            while let range = attributed.range(of: placeholder) {
                attributed[range].foregroundColor = .secondary
                attributed[range].backgroundColor = Color.neonYellow.opacity(0.15)
            }
        }
        return attributed
    }

    private func persistChange() {
        prompt.updateTimestamp()
        do {
            try modelContext.save()
        } catch {
            print("保存模板失败: \(error)")
        }
    }

    private func copyFilledPrompt() {
        let rendered = renderResult.rendered
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(rendered, forType: .string) {
            showCopiedHUDFeedback()
        } else {
            print("复制失败：无法写入剪贴板")
        }
    }

    private func showCopiedHUDFeedback() {
        withAnimation(.easeOut(duration: 0.2)) {
            showCopiedHUD = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                showCopiedHUD = false
            }
        }
    }

    private func togglePinned() {
        withAnimation(.easeInOut(duration: 0.2)) {
            prompt.pinned.toggle()
        }
        persistChange()
    }
}

private struct TemplateEmptyStateView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))
            Text("还没有模板哦")
                .font(.title3.weight(.semibold))
            Text("先在左侧新建一个模板，或者导入 JSON，马上开始复用你的提示词。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            HStack(spacing: 12) {
                TemplateActionButton(title: "导入 JSON", systemImage: "square.and.arrow.down", action: onImport)
                Text("或按 ⌘N 立即新建")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

private struct TagBadge: View {
    let tag: String

    var body: some View {
        let style = TagPalette.style(for: tag)
        Text(tag)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(style.foreground)
            .background(
                Capsule()
                    .fill(style.background)
            )
            .overlay(
                Capsule()
                    .stroke(style.foreground.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct TagStyle {
    let background: Color
    let foreground: Color
}

private enum TagPalette {
    private static let styles: [TagStyle] = [
        TagStyle(background: Color(red: 0.96, green: 0.99, blue: 0.76), foreground: Color(red: 0.24, green: 0.28, blue: 0.04)),
        TagStyle(background: Color(red: 0.93, green: 0.97, blue: 1.0), foreground: Color(red: 0.18, green: 0.32, blue: 0.46)),
        TagStyle(background: Color(red: 1.0, green: 0.92, blue: 0.94), foreground: Color(red: 0.54, green: 0.18, blue: 0.26)),
        TagStyle(background: Color(red: 0.95, green: 0.92, blue: 1.0), foreground: Color(red: 0.33, green: 0.26, blue: 0.64)),
        TagStyle(background: Color(red: 0.92, green: 1.0, blue: 0.95), foreground: Color(red: 0.1, green: 0.36, blue: 0.23)),
        TagStyle(background: Color(red: 1.0, green: 0.95, blue: 0.88), foreground: Color(red: 0.47, green: 0.3, blue: 0.12))
    ]

    static func style(for tag: String) -> TagStyle {
        guard styles.isEmpty == false else {
            return TagStyle(background: Color.neonYellow.opacity(0.3), foreground: .black)
        }
        let index = abs(tag.hashValue) % styles.count
        return styles[index]
    }
}

private struct PromptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem
    @FocusState private var focusedField: DetailField?

    private enum DetailField: Hashable {
        case title, body
    }

    private var neonYellow: Color { .neonYellow }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    divider
                    bodyEditor
                    divider
                    tagsEditor
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        togglePinned()
                    } label: {
                        Label(prompt.pinned ? "取消置顶" : "置顶", systemImage: prompt.pinned ? "pin.slash" : "pin.fill")
                    }
                    .keyboardShortcut("b", modifiers: .command)
                }
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模板标题")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("模板标题", text: $prompt.title, axis: .vertical)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .title)
                .onChange(of: prompt.title) { _ in persistChange() }

            HStack(spacing: 16) {
                Text(prompt.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label {
                    Text("最近更新 \(prompt.updatedAt, style: .relative)")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                FilterChip(title: prompt.pinned ? "已置顶" : "未置顶", isActive: prompt.pinned, tint: prompt.pinned ? Color.neonYellow : nil) {
                    togglePinned()
                }
            }
        }
    }

    private var divider: some View {
        Divider()
            .overlay(Color.cardOutline.opacity(0.4))
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("正文模板")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $prompt.body)
                .frame(minHeight: 240)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardOutline.opacity(0.5), lineWidth: 1)
                )
                .focused($focusedField, equals: .body)
                .onChange(of: prompt.body) { _ in
                    syncParams()
                    persistChange()
                }
        }
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签（逗号分隔）")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("summary, outreach", text: Binding(
                get: { prompt.tags.joined(separator: ", ") },
                set: { newValue in
                    prompt.tags = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    persistChange()
                }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func persistChange() {
        prompt.updateTimestamp()
        do {
            try modelContext.save()
        } catch {
            print("保存模板失败: \(error)")
        }
    }

    private func togglePinned() {
        withAnimation(.easeInOut(duration: 0.2)) {
            prompt.pinned.toggle()
        }
        persistChange()
    }

    private func syncParams() {
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

        for removed in existing.values {
            modelContext.delete(removed)
        }

        prompt.params = ordered
    }
}

private struct CopiedHUDView: View {
    var body: some View {
        Label("已复制", systemImage: "checkmark.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }
}

// MARK: - Flow layout helper

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxLineWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var usedHeight: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxLineWidth, lineWidth > 0 {
                usedHeight += lineHeight + spacing
                maxWidth = max(maxWidth, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
            lineHeight = max(lineHeight, size.height)
        }

        usedHeight += lineHeight
        maxWidth = max(maxWidth, lineWidth)

        return CGSize(width: proposal.width ?? maxWidth, height: usedHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: origin, proposal: ProposedViewSize(width: size.width, height: size.height))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Design tokens

struct FocusSearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct DeleteActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearchAction: (() -> Void)? {
        get { self[FocusSearchActionKey.self] }
        set { self[FocusSearchActionKey.self] = newValue }
    }

    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }

    var deleteAction: (() -> Void)? {
        get { self[DeleteActionKey.self] }
        set { self[DeleteActionKey.self] = newValue }
    }
}

private struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct OperationToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let iconSystemName: String
}

private struct OperationToastView: View {
    let toast: OperationToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.iconSystemName)
                .font(.system(size: 14, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.92))
        )
        .foregroundStyle(Color.white)
        .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
    }
}

private struct PromptArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func empty() -> PromptArchiveDocument {
        PromptArchiveDocument(data: Data())
    }
}

private extension PromptTransferError {
    var detailedMessage: String {
        if let reason = failureReason, reason.isEmpty == false {
            return "\(localizedDescription)\n\(reason)"
        }
        return localizedDescription
    }
}

private extension Color {
    static let neonYellow = Color(red: 0.92, green: 1.0, blue: 0.0)
    static let appBackground = Color(white: 0.97)
    static let appForeground = Color(white: 0.15)
    static let cardBackground = Color.white
    static let cardSurface = Color(white: 0.94)
    static let cardOutline = Color.black.opacity(0.08)
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
