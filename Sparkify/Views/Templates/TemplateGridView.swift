//
//  TemplateGridView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

enum PromptSortMode: String, CaseIterable {
    case alphabetical = "摘要排序"
    case timeCreated = "创建时间"
    case timeUpdated = "更新时间"
    
    var iconName: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .timeCreated: return "clock"
        case .timeUpdated: return "clock.arrow.circlepath"
        }
    }
}

struct TemplateGridView: View {
    let prompts: [PromptItem]
    let totalPromptCount: Int
    let availableTags: [String]
    let activeFilter: PromptListFilter
    let onSelectFilter: (PromptListFilter) -> Void
    let onOpenDetail: (PromptItem) -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    @Binding var searchText: String
    @Binding var searchPresented: Bool
    let onAddPrompt: () -> Void
    let onAddAgentContextPrompt: () -> Void
    let onDeletePrompt: (PromptItem) -> Void
    let onClonePrompt: (PromptItem) -> Void
    let onShowToast: (String, String) -> Void
    let onPresentError: (String, String) -> Void
    @Binding var highlightedPromptID: String?
    
    @State private var sortMode: PromptSortMode = .alphabetical
    @State private var preferences = PreferencesService.shared
    @State private var isToolboxExpanded = false
    @State private var autoCollapseTask: Task<Void, Never>?

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 24, alignment: .top)
    ]

    private var arrangedPrompts: [PromptItem] {
        prompts.sorted { lhs, rhs in
            // 1. 置顶优先
            if lhs.pinned != rhs.pinned {
                return lhs.pinned
            }
            
            // 2. 根据排序模式排序
            switch sortMode {
            case .alphabetical:
                // 按第一个 tag 分组（无 tag 的排在最后）
                let lhsTag = lhs.tags.first ?? ""
                let rhsTag = rhs.tags.first ?? ""
                
                if lhsTag != rhsTag {
                    // 空 tag 排在最后
                    if lhsTag.isEmpty { return false }
                    if rhsTag.isEmpty { return true }
                    return lhsTag.localizedCompare(rhsTag) == .orderedAscending
                }
                
                // 同 tag 内按 title 的字典序排序
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                
            case .timeCreated:
                return lhs.createdAt > rhs.createdAt
                
            case .timeUpdated:
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var enabledToolboxApps: [ToolboxApp] {
        ToolboxApp.all.filter { preferences.enabledToolboxAppIDs.contains($0.id) }
    }

    private var shouldShowToolbox: Bool {
        enabledToolboxApps.isEmpty == false
    }

    private let toolboxAutoCollapseDelay: UInt64 = 3_000_000_000

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView

            if shouldShowToolbox {
                ToolboxButtonView(
                    apps: enabledToolboxApps,
                    isExpanded: isToolboxExpanded,
                    onToggle: toggleToolboxExpansion,
                    onLaunch: openToolboxApp
                )
                .padding(.trailing, 28)
                .padding(.bottom, 36)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .background(Color.appBackground)
        .searchable(text: $searchText, isPresented: $searchPresented, placement: .toolbar, prompt: "搜索模板")
        .background(DoubleShiftToSearch { searchPresented = true })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("新建普通模板", action: onAddPrompt)
                        .keyboardShortcut("n", modifiers: .command)
                    Button("新建代理上下文模板…", action: onAddAgentContextPrompt)
                        .keyboardShortcut("n", modifiers: [
                            .command,
                            .shift
                        ])
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(width: 40, height: 40)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
            }
        }
        .onDisappear {
            autoCollapseTask?.cancel()
            autoCollapseTask = nil
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Spacer()
            
            SortModeMenu(
                currentMode: sortMode,
                onSelectMode: { mode in
                    sortMode = mode
                }
            )
            
            TagFilterMenu(
                availableTags: availableTags,
                activeFilter: activeFilter,
                onSelectFilter: onSelectFilter
            )
            .opacity(availableTags.isEmpty ? 0.45 : 1)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if prompts.isEmpty {
            TemplateEmptyStateView(
                hasAnyPrompts: totalPromptCount > 0,
                activeFilter: activeFilter,
                searchText: searchText,
                onImport: onImport,
                onAddPrompt: onAddPrompt,
                onClearFilters: clearAllFilters
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        filterBar

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(arrangedPrompts, id: \.uuid) { prompt in
                                TemplateCardView(
                                    prompt: prompt,
                                    toolboxApps: enabledToolboxApps,
                                    onCopy: handleCopyAction,
                                    onDelete: onDeletePrompt,
                                    onClone: onClonePrompt,
                                    onFilterByTag: { tag in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            onSelectFilter(.tag(tag))
                                        }
                                    },
                                    onLaunchToolboxApp: openToolboxApp,
                                    onShowToast: onShowToast,
                                    onPresentError: onPresentError,
                                    onOpenDetail: {
                                        onOpenDetail(prompt)
                                    },
                                    isHighlighted: highlightedPromptID == prompt.uuid
                                )
                                .id(prompt.uuid)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .onAppear {
                    print("🏁 [GridView] Grid appeared with \(arrangedPrompts.count) prompts")
                }
                .onChange(of: highlightedPromptID) { newID in
                    guard let id = newID else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func handleCopyAction() {
        guard shouldShowToolbox else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isToolboxExpanded = true
        }
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: toolboxAutoCollapseDelay)
            withAnimation(.easeInOut(duration: 0.3)) {
                isToolboxExpanded = false
            }
        }
    }

    private func toggleToolboxExpansion() {
        guard shouldShowToolbox else { return }
        autoCollapseTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isToolboxExpanded.toggle()
        }
        if isToolboxExpanded == false {
            autoCollapseTask = nil
        }
    }

    private func openToolboxApp(_ app: ToolboxApp) {
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
        let opened = ToolboxLauncher.shared.open(app)
        if opened {
            withAnimation(.easeInOut(duration: 0.2)) {
                isToolboxExpanded = false
            }
        } else {
            print("⚠️ [Toolbox] Failed to open \(app.displayName)")
        }
    }

    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.2)) {
            onSelectFilter(.all)
            searchText = ""
        }
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
            Button("所有标签") { onSelectFilter(.all) }
                .disabled(activeFilter == .all)

            if availableTags.isEmpty == false {
                Section("选择标签") {
                    ForEach(availableTags, id: \.self) { tag in
                        let style = TagPalette.style(for: tag)
                        Button {
                            onSelectFilter(.tag(tag))
                        } label: {
                            menuLabel(text: tag, isSelected: isCurrent(tag))
                        }
                        .tint(style.foreground)
                    }
                }
            }
        } label: {
            Label(selectedTagLabel, systemImage: "tag")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle((currentStyle?.foreground ?? Color.appForeground).opacity(0.9))
                .background(
                    Capsule()
                        .fill(currentStyle?.background ?? Color.cardSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.cardOutline.opacity(currentStyle == nil ? 0.8 : 0.2), lineWidth: 1)
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

private struct SortModeMenu: View {
    let currentMode: PromptSortMode
    let onSelectMode: (PromptSortMode) -> Void
    
    var body: some View {
        Menu {
            ForEach(PromptSortMode.allCases, id: \.self) { mode in
                Button {
                    onSelectMode(mode)
                } label: {
                    Label {
                        Text(mode.rawValue)
                    } icon: {
                        if mode == currentMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(currentMode.rawValue, systemImage: currentMode.iconName)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(Color.appForeground.opacity(0.9))
                .background(
                    Capsule()
                        .fill(Color.cardSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.cardOutline.opacity(0.8), lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }
}

private struct TemplateEmptyStateView: View {
    let hasAnyPrompts: Bool
    let activeFilter: PromptListFilter
    let searchText: String
    let onImport: () -> Void
    let onAddPrompt: () -> Void
    let onClearFilters: () -> Void

    private var isFiltered: Bool {
        hasAnyPrompts && (activeFilter != .all || !searchText.isEmpty)
    }

    private var filterDescription: String {
        var parts: [String] = []
        
        if case let .tag(tag) = activeFilter {
            parts.append("标签「\(tag)」")
        } else if case .pinned = activeFilter {
            parts.append("置顶")
        }
        
        if !searchText.isEmpty {
            parts.append("搜索「\(searchText)」")
        }
        
        return parts.joined(separator: " + ")
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "square.grid.2x2")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))

            if isFiltered {
                // Filtered empty state
                Text("当前条件下没有模板")
                    .font(.title3.weight(.semibold))
                Text("筛选条件：\(filterDescription)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                TemplateActionButton(
                    title: "清空筛选条件",
                    systemImage: "xmark.circle",
                    action: onClearFilters
                )
            } else {
                // Truly empty state
                Text("还没有模板哦")
                    .font(.title3.weight(.semibold))
                Text("先新建一个模板，或者导入 JSON，马上开始复用你的提示词。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                HStack(spacing: 12) {
                    TemplateActionButton(title: "新建模板", systemImage: "plus.circle.fill", action: onAddPrompt)
                    TemplateActionButton(title: "导入 JSON", systemImage: "square.and.arrow.down", action: onImport)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
