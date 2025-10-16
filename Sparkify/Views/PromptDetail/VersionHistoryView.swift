import SwiftUI
import SwiftData

let VersionHistoryCurrentSelectionID = "__current_prompt_snapshot__"

struct VersionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: PromptItem
    @Binding var baselineRevisionID: String?
    @Binding var comparisonRevisionID: String?
    var onClose: () -> Void
    @State private var revisionToRestore: PromptRevision?

    private var revisions: [PromptRevision] {
        VersioningService.revisions(for: prompt)
    }

    private var sortedRevisions: [PromptRevision] {
        revisions.sorted { $0.createdAt > $1.createdAt }
    }

    private var baselineRevision: PromptRevision? {
        guard let id = baselineRevisionID else { return nil }
        return sortedRevisions.first(where: { $0.uuid == id })
    }

    private var comparisonRevision: PromptRevision? {
        guard let id = comparisonRevisionID, id != VersionHistoryCurrentSelectionID else { return nil }
        return sortedRevisions.first(where: { $0.uuid == id })
    }

    private var comparisonIsCurrent: Bool {
        comparisonRevisionID == nil || comparisonRevisionID == VersionHistoryCurrentSelectionID
    }

    private var diff: VersioningService.PromptDiff? {
        guard let baseRevision = baselineRevision else { return nil }
        let baseSnapshot = VersioningService.PromptSnapshot(from: baseRevision)
        let compareSnapshot: VersioningService.PromptSnapshot
        if let comparisonRevision {
            compareSnapshot = VersioningService.PromptSnapshot(from: comparisonRevision)
        } else {
            compareSnapshot = VersioningService.PromptSnapshot(from: prompt)
        }
        return VersioningService.diff(from: baseSnapshot, to: compareSnapshot)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    content
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())

            Divider()
                .overlay(Color.cardOutline.opacity(0.2))

            actionBar
        }
        .confirmationDialog(String(localized: "restore_version_title", defaultValue: "恢复此版本？"), isPresented: restoreDialogBinding, titleVisibility: .visible) {
            Button(String(localized: "restore_version", defaultValue: "恢复版本"), role: .destructive) {
                if let revision = revisionToRestore {
                    restoreRevision(revision)
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "restore_version_message", defaultValue: "将使用此历史版本覆盖当前内容，并生成新版本记录。此操作不可撤销。"))
        }
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(
            get: { revisionToRestore != nil },
            set: { if !$0 { revisionToRestore = nil } }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "version_history", defaultValue: "版本历史"))
                .font(.title3.weight(.semibold))
            Text(String(localized: "version_history_instructions", defaultValue: "左侧选择要查看的版本，再挑选对比对象。默认与当前内容对比。右键点击版本可标记为里程碑，里程碑版本永久保留不会被自动清理。"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var content: some View {
        if sortedRevisions.isEmpty {
            return AnyView(emptyState)
        }

        return AnyView(
            HStack(alignment: .top, spacing: 20) {
                revisionList
                    .frame(width: 260, alignment: .leading)

                Divider()
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 16) {
                    comparisonPicker
                    diffDetail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 360)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.cardOutline.opacity(0.45), lineWidth: 1)
            )
            .padding(.trailing, 8)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "no_version_records", defaultValue: "暂无版本记录"))
                .font(.title3.weight(.semibold))
            Text(String(localized: "save_once_to_see_diff", defaultValue: "保存至少一次模板即可在这里查看版本差异。"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardOutline.opacity(0.35), lineWidth: 1)
        )
    }

    private var revisionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(sortedRevisions, id: \.uuid) { revision in
                    revisionRow(revision)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    private func revisionRow(_ revision: PromptRevision) -> some View {
        let isSelected = revision.uuid == baselineRevisionID
        return Button {
            baselineRevisionID = revision.uuid
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(revision.titleSnapshot.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : revision.titleSnapshot)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if revision.isMilestone {
                        milestoneBadge
                    }
                }
                Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: String(localized: "author", defaultValue: "作者：%@"), revision.author))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cardOutline.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                revisionToRestore = revision
            } label: {
                Label(String(localized: "restore_this_version", defaultValue: "恢复此版本"), systemImage: "clock.arrow.circlepath")
            }
            
            Divider()
            
            Button {
                toggleMilestone(for: revision)
            } label: {
                Label(
                    revision.isMilestone ? String(localized: "unmark_milestone", defaultValue: "取消里程碑标记") : String(localized: "mark_as_milestone", defaultValue: "标记为里程碑"),
                    systemImage: revision.isMilestone ? "flag.slash" : "flag.fill"
                )
            }
        }
        .accessibilityIdentifier("revision-row-\(revision.uuid)")
    }

    private var milestoneBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 10, weight: .bold))
            Text(String(localized: "milestone", defaultValue: "里程碑"))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.neonYellow)
        )
    }

    private func toggleMilestone(for revision: PromptRevision) {
        withAnimation(.easeInOut(duration: 0.2)) {
            revision.isMilestone.toggle()
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle milestone status: \(error)")
        }
    }

    private func restoreRevision(_ revision: PromptRevision) {
        // 应用历史版本的快照到当前 prompt
        prompt.title = revision.titleSnapshot
        prompt.body = revision.bodySnapshot
        prompt.tags = revision.tagsSnapshot
        
        // 处理参数：删除现有参数，创建新参数
        let oldParams = prompt.params
        for param in oldParams {
            modelContext.delete(param)
        }
        prompt.params.removeAll()
        
        // 根据快照重建参数
        for paramSnapshot in revision.paramSnapshots {
            let newParam = ParamKV(
                key: paramSnapshot.key,
                value: paramSnapshot.value,
                defaultValue: paramSnapshot.defaultValue,
                owner: prompt
            )
            prompt.params.append(newParam)
        }
        
        // 更新时间戳
        prompt.updateTimestamp()
        
        // 生成新版本记录
        VersioningService.captureRevision(
            for: prompt,
            in: modelContext,
            isMilestone: false
        )
        
        do {
            try modelContext.save()
            revisionToRestore = nil
        } catch {
            print("恢复版本失败: \(error)")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Spacer()
            Button(String(localized: "close", defaultValue: "关闭")) {
                onClose()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Color.cardSurface)
    }

    private var comparisonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "comparison_target", defaultValue: "对比目标"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Menu {
                Button {
                    comparisonRevisionID = VersionHistoryCurrentSelectionID
                } label: {
                    selectionRow(
                        title: String(localized: "current_content", defaultValue: "当前内容"),
                        subtitle: String(localized: "unsaved_changes_included", defaultValue: "未保存修改也会纳入比较"),
                        icon: "sparkles",
                        isSelected: comparisonIsCurrent
                    )
                }

                if sortedRevisions.isNotEmpty {
                    Divider()
                }

                ForEach(sortedRevisions, id: \.uuid) { revision in
                    let isSelected = comparisonRevisionID == revision.uuid
                    Button {
                        comparisonRevisionID = revision.uuid
                    } label: {
                        selectionRow(
                            title: revision.titleSnapshot.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : revision.titleSnapshot,
                            subtitle: revision.createdAt.formatted(date: .abbreviated, time: .shortened),
                            icon: revision.isMilestone ? "flag.fill" : "clock",
                            isSelected: isSelected
                        )
                    }
                }
            } label: {
                HStack {
                    let selectedLabel = currentComparisonLabel
                    Label(selectedLabel.title, systemImage: selectedLabel.icon)
                        .labelStyle(.titleAndIcon)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardSurface.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardOutline.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private var currentComparisonLabel: (title: String, icon: String) {
        if comparisonIsCurrent {
            return (String(localized: "current_content", defaultValue: "当前内容"), "sparkles")
        }
        if let revision = comparisonRevision {
            return (
                revision.titleSnapshot.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : revision.titleSnapshot,
                revision.isMilestone ? "flag.fill" : "clock"
            )
        }
        return (String(localized: "current_content", defaultValue: "当前内容"), "sparkles")
    }

    private func selectionRow(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var diffDetail: some View {
        Group {
            if baselineRevision == nil {
                Text(String(localized: "select_version_to_compare", defaultValue: "请选择左侧某个版本，随后选择你想要比较的目标。默认与当前内容对比。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardSurface.opacity(0.6))
                    )
            } else if let diff {
                ScrollView {
                    DiffDetailView(diff: diff, comparisonIsCurrent: comparisonIsCurrent)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                Text(String(localized: "invalid_comparison_target", defaultValue: "选定的对比目标无效，请重新选择。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DiffDetailView: View {
    let diff: VersioningService.PromptDiff
    let comparisonIsCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            DiffSection(title: String(localized: "summary", defaultValue: "摘要"), segments: diff.titleSegments)
            DiffSection(title: String(localized: "body", defaultValue: "正文"), segments: diff.bodySegments)
            TagDiffSection(diff: diff.tagDiff)
            ParameterDiffSection(diffs: diff.parameterDiffs)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardSurface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardOutline.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct DiffSection: View {
    let title: String
    let segments: [VersioningService.TextDiffSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if segments.isEmpty {
                Text(String(localized: "no_change", defaultValue: "无变化"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                DiffTextView(segments: segments)
            }
        }
    }
}

private struct DiffTextView: View {
    let segments: [VersioningService.TextDiffSegment]

    var body: some View {
        Text(attributedString)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedString: AttributedString {
        var result = AttributedString()
        for segment in segments {
            var substring = AttributedString(segment.text)
            switch segment.kind {
            case .added:
                substring.foregroundColor = .green
                substring.backgroundColor = Color.green.opacity(0.12)
            case .removed:
                substring.foregroundColor = .red
                substring.backgroundColor = Color.red.opacity(0.12)
                substring.strikethroughStyle = .single
            case .unchanged:
                substring.foregroundColor = .primary
            }
            result.append(substring)
        }
        return result
    }
}

private struct TagDiffSection: View {
    let diff: VersioningService.TagDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "tags", defaultValue: "标签"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if diff.added.isEmpty, diff.removed.isEmpty, diff.unchanged.isEmpty {
                Text(String(localized: "no_change", defaultValue: "无变化"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if diff.added.isNotEmpty {
                        TagListView(title: String(localized: "added", defaultValue: "新增"), tags: diff.added, color: .green)
                    }
                    if diff.removed.isNotEmpty {
                        TagListView(title: String(localized: "removed", defaultValue: "移除"), tags: diff.removed, color: .red)
                    }
                    if diff.unchanged.isNotEmpty {
                        TagListView(title: String(localized: "kept", defaultValue: "保留"), tags: diff.unchanged, color: .secondary)
                    }
                }
            }
        }
    }
}

private struct TagListView: View {
    let title: String
    let tags: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(color)
            WrapTags(tags: tags, color: color)
        }
    }
}

private struct WrapTags: View {
    let tags: [String]
    let color: Color

    var body: some View {
        FlexibleTagFlow(tags: tags) { tag in
            Text(tag)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
                .foregroundStyle(color)
        }
    }
}

private struct FlexibleTagFlow<Content: View>: View {
    let tags: [String]
    let content: (String) -> Content
    
    @State private var totalHeight = CGFloat.zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                content(tag)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
                    .alignmentGuide(.leading, computeValue: { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if index == tags.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { dimension in
                        let result = height
                        if index == tags.count - 1 {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

private struct ParameterDiffSection: View {
    let diffs: [VersioningService.ParameterDiff]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "parameter_defaults", defaultValue: "参数默认值"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if diffs.isEmpty {
                Text(String(localized: "no_change", defaultValue: "无变化"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(diffs) { diff in
                        ParameterDiffRow(diff: diff)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.cardSurface.opacity(0.65))
                            )
                    }
                }
            }
        }
    }
}

private struct ParameterDiffRow: View {
    let diff: VersioningService.ParameterDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("{\(diff.key)}")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "current_value", defaultValue: "当前值"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                DiffTextView(segments: diff.valueSegments)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "default_value", defaultValue: "默认值"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                DiffTextView(segments: diff.defaultValueSegments)
            }
        }
    }

    private var statusText: String {
        switch diff.change {
        case .added:
            return String(localized: "added", defaultValue: "新增")
        case .removed:
            return String(localized: "param_removed", defaultValue: "已移除")
        case .modified:
            return String(localized: "param_modified", defaultValue: "已更新")
        case .unchanged:
            return String(localized: "param_unchanged", defaultValue: "未变化")
        }
    }

    private var statusColor: Color {
        switch diff.change {
        case .added:
            return .green
        case .removed:
            return .red
        case .modified:
            return .orange
        case .unchanged:
            return .secondary
        }
    }
}

private extension Array {
    var isNotEmpty: Bool { isEmpty == false }
}
