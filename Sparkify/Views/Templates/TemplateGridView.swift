//
//  TemplateGridView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import SwiftUI

struct TemplateGridView: View {
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
        Group {
            if prompts.isEmpty {
                TemplateEmptyStateView(onImport: onImport)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        filterBar

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(arrangedPrompts) { prompt in
                                TemplateCardView(prompt: prompt) {
                                    onOpenDetail(prompt)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
    }

    private var filterBar: some View {
        HStack {
            Spacer()
            TagFilterMenu(
                availableTags: availableTags,
                activeFilter: activeFilter,
                onSelectFilter: onSelectFilter
            )
            .opacity(availableTags.isEmpty ? 0.45 : 1)
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
