//
//  SidebarListView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import Foundation
import SwiftUI

struct SidebarListView: View {
    let prompts: [PromptItem]
    @Binding var presentedPrompt: PromptItem?
    let deletePrompt: ([PromptItem]) -> Void
    let togglePinPrompt: (PromptItem) -> Void
    let copyFilledPrompt: (PromptItem) -> Void
    let copyTemplateOnly: (PromptItem) -> Void
    let clonePrompt: (PromptItem) -> Void
    let resetAllParams: (PromptItem) -> Void
    @Binding var activeFilter: PromptListFilter
    let onImport: () -> Void
    let onExport: () -> Void
    let onSettings: () -> Void
    let onHighlightPrompt: (PromptItem) -> Void

    private var displayedPrompts: [PromptItem] {
        var items = prompts
        switch activeFilter {
        case .all:
            break
        case .pinned:
            items = items.filter { $0.pinned }
        case let .tag(tag):
            items = items.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        return sort(items)
    }
    
    private var sectionTitle: String {
        switch activeFilter {
        case .all:
            return String(localized: "templates", defaultValue: "模板")
        case .pinned:
            return String(localized: "pinned_templates", defaultValue: "置顶的模板")
        case let .tag(tagName):
            return String(format: String(localized: "templates_with_tag", defaultValue: "标签「%@」的模板"), tagName)
        }
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
                HStack(spacing: 8) {
                    FilterChip(title: String(localized: "all", defaultValue: "全部"), isActive: activeFilter == .all) {
                        activeFilter = .all
                    }
                    FilterChip(title: String(localized: "pin", defaultValue: "置顶"), isActive: activeFilter == .pinned) {
                        activeFilter = .pinned
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12))
            .listRowBackground(Color.clear)

            Section {
                if displayedPrompts.isEmpty {
                    Text(String(localized: "no_templates_yet_create_one", defaultValue: "还没有模板，先新建一个吧"))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(displayedPrompts, id: \.uuid) { prompt in
                        SidebarPromptRow(
                            prompt: prompt,
                            isSelected: presentedPrompt?.uuid == prompt.uuid,
                            onSingleClick: {
                                onHighlightPrompt(prompt)
                            },
                            onDoubleClick: {
                                presentedPrompt = prompt
                            },
                            onTogglePin: {
                                togglePinPrompt(prompt)
                            },
                            onCopyFilled: {
                                copyFilledPrompt(prompt)
                            },
                            onCopyTemplate: {
                                copyTemplateOnly(prompt)
                            },
                            onClone: {
                                clonePrompt(prompt)
                            },
                            onResetParams: {
                                resetAllParams(prompt)
                            },
                            onDelete: {
                                deletePrompt([prompt])
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        let items = offsets.compactMap { index -> PromptItem? in
                            guard index < displayedPrompts.count else { return nil }
                            return displayedPrompts[index]
                        }
                        deletePrompt(items)
                    }
                }
            } header: {
                Text(sectionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Sparkify")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .padding(.bottom, 8)
                
                HStack(spacing: 12) {
                    SidebarActionButton(title: String(localized: "import", defaultValue: "导入"), action: onImport)
                    SidebarActionButton(title: String(localized: "export", defaultValue: "导出"), action: onExport)
                }
                .padding(.horizontal, 16)
                
                Button(action: onSettings) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text(String(localized: "settings", defaultValue: "设置"))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .background(Color.appBackground.opacity(0.95))
        }
    }

    fileprivate static func formattedRelativeDate(for date: Date) -> String {
        let now = Date()
        let delta = now.timeIntervalSince(date)
        if abs(delta) < 60 {
            return String(localized: "just_now", defaultValue: "刚刚")
        }
        let formatted = SidebarListView.componentsFormatter.string(from: abs(delta)) ?? ""
        if formatted.isEmpty {
            return SidebarListView.relativeFormatter.localizedString(for: date, relativeTo: now)
        }
        return delta >= 0 ? String(format: String(localized: "time_ago_format", defaultValue: "%@前"), formatted) : String(format: String(localized: "time_later_format", defaultValue: "%@后"), formatted)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let componentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.minute, .hour, .day, .weekOfMonth, .month, .year]
        return formatter
    }()
}

private struct SidebarPromptRow: View {
    let prompt: PromptItem
    let isSelected: Bool
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onTogglePin: () -> Void
    let onCopyFilled: () -> Void
    let onCopyTemplate: () -> Void
    let onClone: () -> Void
    let onResetParams: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var interactionActive: Bool { isHovered || isFocused || isSelected }
    
    private var contextMenuConfiguration: TemplateCardContextMenuBridge.Configuration {
        let title = prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title
        let actions: [TemplateCardContextMenuBridge.Configuration.Action] = [
            .init(
                title: String(localized: "edit_template", defaultValue: "编辑模板"),
                systemImageName: "rectangle.and.pencil.and.ellipsis"
            ) {
                onDoubleClick()
            },
            .init(
                title: String(localized: "copy", defaultValue: "复制"),
                systemImageName: "square.and.pencil"
            ) {
                onCopyFilled()
            },
            .init(
                title: String(localized: "copy_template_only", defaultValue: "仅复制模板"),
                systemImageName: "doc.on.doc"
            ) {
                onCopyTemplate()
            },
            .init(
                title: prompt.pinned ? String(localized: "unpin_template", defaultValue: "取消置顶") : String(localized: "pin_template", defaultValue: "置顶此模板"),
                systemImageName: "pin"
            ) {
                onTogglePin()
            },
            .init(
                title: String(localized: "clone_template", defaultValue: "克隆模板"),
                systemImageName: "doc.on.doc"
            ) {
                onClone()
            },
            .init(
                title: String(localized: "reset_all_params", defaultValue: "重置所有参数"),
                systemImageName: "arrow.counterclockwise.circle"
            ) {
                onResetParams()
            },
            .init(
                title: String(localized: "delete_prompt", defaultValue: "删除模板"),
                systemImageName: "trash",
                role: .destructive
            ) {
                onDelete()
            }
        ]
        
        return TemplateCardContextMenuBridge.Configuration(
            headerTitle: title,
            actions: actions
        )
    }

    var body: some View {
        Button(action: onSingleClick) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title)
                        .font(.headline)
                        .foregroundStyle(Color.appForeground.opacity(isSelected ? 0.9 : 0.8))
                    if prompt.pinned {
                        PinGlyph(isPinned: true, circleDiameter: 18)
                    }
                }
                Text(SidebarListView.formattedRelativeDate(for: prompt.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(backgroundShape)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.82)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .overlay(
            TemplateCardContextMenuBridge(configuration: contextMenuConfiguration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.82), value: interactionActive)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
            .shadow(color: interactionActive ? Color.black.opacity(0.2) : Color.clear, radius: 5, x: 0, y: 1)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.cardSurface.opacity(0.6)
        }
        if interactionActive {
            return Color.cardSurface.opacity(0.45)
        }
        return Color.clear
    }
}
