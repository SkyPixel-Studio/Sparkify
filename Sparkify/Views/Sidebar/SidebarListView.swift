//
//  SidebarListView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation
import SwiftUI

struct SidebarListView: View {
    let prompts: [PromptItem]
    @Binding var presentedPrompt: PromptItem?
    let addPrompt: () -> Void
    let deletePrompt: ([PromptItem]) -> Void
    @Binding var searchText: String
    @Binding var activeFilter: PromptListFilter
    let searchFieldFocus: FocusState<Bool>.Binding
    let onImport: () -> Void
    let onExport: () -> Void

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
                    .padding(.vertical, 1)
                    .frame(maxWidth: .infinity)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(Color.clear)

            Section {
                HStack(spacing: 8) {
                    FilterChip(title: "全部", isActive: activeFilter == .all) {
                        activeFilter = .all
                    }
                    FilterChip(title: "置顶", isActive: activeFilter == .pinned) {
                        activeFilter = .pinned
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 0, trailing: 12))
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
                                Text(formattedRelativeDate(for: prompt.updatedAt))
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
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                SidebarActionButton(title: "导入", action: onImport)
                SidebarActionButton(title: "导出", action: onExport)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground.opacity(0.95))
        }
    }

    private func formattedRelativeDate(for date: Date) -> String {
        let now = Date()
        let delta = now.timeIntervalSince(date)
        if abs(delta) < 60 {
            return "刚刚"
        }
        let formatted = SidebarListView.componentsFormatter.string(from: abs(delta)) ?? ""
        if formatted.isEmpty {
            return SidebarListView.relativeFormatter.localizedString(for: date, relativeTo: now)
        }
        return delta >= 0 ? "\(formatted)前" : "\(formatted)后"
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
