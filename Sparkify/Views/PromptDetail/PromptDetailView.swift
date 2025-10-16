//
//  PromptDetailView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem
    @Query(sort: \PromptItem.updatedAt, order: .reverse) private var allPrompts: [PromptItem]
    @FocusState private var focusedField: DetailField?
    @State private var bodyViewMode: BodyViewMode = .edit
    @State private var draft: PromptDraft = .empty
    @State private var hasLoadedDraft = false
    @State private var pendingDialog: PendingDialog?
    @State private var activePage: DetailPage = .editor
    @State private var selectedBaselineRevisionID: String?
    @State private var selectedComparisonRevisionID: String?
    @State private var isPushingAgentFiles = false
    @State private var isPullingAgentFile = false
    @State private var attachmentToast: OperationToast?
    @State private var attachmentAlert: AlertItem?

    private enum DetailField: Hashable {
        case title, body
    }

    private func attachmentStatus(for attachment: PromptFileAttachment) -> String {
        let syncText = formatTimestamp(attachment.lastSyncedAt)
        let overwriteText = formatTimestamp(attachment.lastOverwrittenAt)
        return String(format: String(localized: "sync_overwrite_format", defaultValue: "同步：%@ · 覆写：%@"), syncText, overwriteText)
    }

    private func formatTimestamp(_ date: Date?) -> String {
        guard let date else {
            return String(localized: "not_performed", defaultValue: "未执行")
        }
        return Self.timestampFormatter.string(from: date)
    }

    private var isAgentContext: Bool {
        prompt.kind == .agentContext
    }

    private var orderedAttachments: [PromptFileAttachment] {
        prompt.attachments.sorted { lhs, rhs in
            if lhs.orderHint == rhs.orderHint {
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.orderHint < rhs.orderHint
        }
    }

    private var hasAgentAttachments: Bool {
        orderedAttachments.isEmpty == false
    }

    private var primaryAttachment: PromptFileAttachment? {
        orderedAttachments.first
    }

    private var hasAttachmentOperationInFlight: Bool {
        isPushingAgentFiles || isPullingAgentFile
    }

    private enum BodyViewMode: String, CaseIterable {
        case edit
        case preview

        var label: String {
            switch self {
            case .edit:
                return String(localized: "edit", defaultValue: "编辑")
            case .preview:
                return String(localized: "markdown_preview", defaultValue: "Markdown 预览")
            }
        }
    }

    private enum DetailPage: String, CaseIterable {
        case editor
        case history

        var label: String {
            switch self {
            case .editor:
                return String(localized: "edit_content", defaultValue: "编辑内容")
            case .history:
                return String(localized: "version_history", defaultValue: "版本历史")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pagePicker
                Divider()
                    .overlay(Color.cardOutline.opacity(0.15))
                if activePage == .editor {
                    editorPage
                } else {
                    historyPage
                }
            }
        }
        .onAppear {
            guard hasLoadedDraft == false else { return }
            draft = PromptDraft(from: prompt)
            hasLoadedDraft = true
            syncDraftParams()
            VersioningService.ensureBaselineRevision(for: prompt, in: modelContext, author: "Local")
            refreshRevisionSelections()
        }
        .onChange(of: prompt.revisions.count, initial: false) { _, _ in
            refreshRevisionSelections()
        }
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(currentDialogTitle, isPresented: dialogPresentedBinding, titleVisibility: .visible) {
            switch pendingDialog {
            case .discardDraft:
                Button(String(localized: "discard_changes", defaultValue: "放弃修改"), role: .destructive, action: dismissWithoutSaving)
                Button(String(localized: "continue_editing", defaultValue: "继续编辑"), role: .cancel) {}
            case .deletePrompt:
                Button(String(localized: "delete_prompt", defaultValue: "删除模板"), role: .destructive, action: deletePrompt)
                Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) {}
            case .none:
                EmptyView()
            }
        } message: {
            if let message = currentDialogMessage {
                Text(message)
            }
        }
        .alert(item: $attachmentAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(String(localized: "ok", defaultValue: "好")))
            )
        }
        .overlay(alignment: .top) {
            if let toast = attachmentToast {
                OperationToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 18)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "template_summary", defaultValue: "模板摘要"))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "summary", defaultValue: "摘要"), text: $draft.title, axis: .vertical)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .title)

            HStack(spacing: 16) {
                Text(prompt.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label {
                    Text(String(localized: "recently_updated_prefix", defaultValue: "最近更新")) + Text(" ") + Text(prompt.updatedAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                FilterChip(title: draft.pinned ? String(localized: "pinned", defaultValue: "已置顶") : String(localized: "not_pinned", defaultValue: "未置顶"), isActive: draft.pinned, tint: draft.pinned ? Color.neonYellow : nil) {
                    togglePinned()
                }
            }
        }
    }

    private var divider: some View {
        Divider()
            .overlay(Color.cardOutline.opacity(0.4))
    }

    private var pagePicker: some View {
        HStack(alignment: .center, spacing: 0) {
            Picker(String(localized: "content_view_picker", defaultValue: "内容视图"), selection: $activePage) {
                ForEach(DetailPage.allCases, id: \.self) { page in
                    Text(page.label).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.cardSurface.opacity(0.5))
    }

    private var editorPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    divider
                    if isAgentContext {
                        attachmentsSection
                        divider
                    }
                    bodyEditor
                    divider
                    parameterDefaultsEditor
                    divider
                    tagsEditor
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())

            Divider()
                .overlay(Color.cardOutline.opacity(0.2))

            actionBar
        }
    }

    private var historyPage: some View {
        VersionHistoryView(
            prompt: prompt,
            baselineRevisionID: $selectedBaselineRevisionID,
            comparisonRevisionID: $selectedComparisonRevisionID,
            onClose: {
                dismiss()
            }
        )
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(String(localized: "linked_files", defaultValue: "关联文件"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addAgentContextFiles()
                } label: {
                    Label(String(localized: "add_files", defaultValue: "添加文件…"), systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cardSurface.opacity(0.85))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.cardOutline.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if orderedAttachments.isEmpty {
                Text(String(localized: "no_linked_files_hint", defaultValue: "尚未关联文件。点击\"添加文件…\"选择一个或多个 Markdown 文件，支持按 ⌘⇧. 显示隐藏文件。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(orderedAttachments, id: \.persistentModelID) { attachment in
                        attachmentRow(for: attachment)
                    }
                }
                .transition(.opacity)

                agentAttachmentActionBar
            }
        }
    }

    private var agentAttachmentActionBar: some View {
        HStack(spacing: 12) {
            Button {
                pushAgentBodyToFiles()
            } label: {
                HStack(spacing: 8) {
                    if isPushingAgentFiles {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.65)
                            .tint(Color.black.opacity(0.85))
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(String(localized: "overwrite_to_file", defaultValue: "覆写到文件"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(hasAgentAttachments ? Color.neonYellow : Color.cardSurface.opacity(0.6))
                )
                .foregroundStyle(hasAgentAttachments ? Color.black : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(hasAgentAttachments == false || hasAttachmentOperationInFlight)

            Button {
                syncAgentBodyFromFile()
            } label: {
                HStack(spacing: 8) {
                    if isPullingAgentFile {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.65)
                            .tint(Color.appForeground)
                    } else {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(String(localized: "sync_with_file", defaultValue: "与文件同步"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.cardSurface.opacity(hasAgentAttachments ? 0.9 : 0.5))
                )
                .foregroundStyle(hasAgentAttachments ? Color.appForeground.opacity(0.88) : Color.secondary)
                .overlay(
                    Capsule()
                        .stroke(Color.cardOutline.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(hasAgentAttachments == false || hasAttachmentOperationInFlight)
        }
    }

    @ViewBuilder
    private func attachmentRow(for attachment: PromptFileAttachment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(attachment.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appForeground)
                        if attachment.persistentModelID == primaryAttachment?.persistentModelID {
                            Text(String(localized: "primary_file", defaultValue: "主文件"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.neonYellow.opacity(0.4))
                                )
                                .foregroundStyle(Color.black)
                        }
                    }
                    Text(attachmentStatus(for: attachment))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        moveAttachment(attachment, direction: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.cardSurface.opacity(0.85))
                            )
                            .foregroundStyle(Color.appForeground.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .disabled(orderedAttachments.first?.persistentModelID == attachment.persistentModelID || hasAttachmentOperationInFlight)

                    Button {
                        moveAttachment(attachment, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.cardSurface.opacity(0.85))
                            )
                            .foregroundStyle(Color.appForeground.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .disabled(orderedAttachments.last?.persistentModelID == attachment.persistentModelID || hasAttachmentOperationInFlight)

                    Menu {
                        Button(String(localized: "set_as_primary", defaultValue: "设为首要")) {
                            makeAttachmentPrimary(attachment)
                        }
                        .disabled(primaryAttachment?.persistentModelID == attachment.persistentModelID || hasAttachmentOperationInFlight)

                        Divider()

                        Button(String(localized: "sync_from_this_file_only", defaultValue: "仅从该文件同步")) {
                            syncFromAttachment(attachment)
                        }
                        .disabled(hasAttachmentOperationInFlight)

                        Button(String(localized: "overwrite_single_file", defaultValue: "仅覆写该文件")) {
                            overwriteSingleAttachment(attachment)
                        }
                        .disabled(hasAttachmentOperationInFlight)

                        Divider()

                        Button(String(localized: "remove_attachment", defaultValue: "移除附件"), role: .destructive) {
                            removeAttachment(attachment)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.appForeground.opacity(0.85))
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            if let error = attachment.lastErrorMessage,
               error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cardOutline.opacity(0.6), lineWidth: 1)
        )
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(String(localized: "body_template", defaultValue: "正文模板"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker(String(localized: "body_mode_picker", defaultValue: "正文模式"), selection: $bodyViewMode) {
                    ForEach(BodyViewMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            if bodyViewMode == .edit {
                TextEditor(text: $draft.body)
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
                    .onChange(of: draft.body, initial: false) { _, _ in
                        syncDraftParams()
                    }
            } else {
                ScrollView {
                    if draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(String(localized: "empty_body_no_markdown_preview", defaultValue: "正文为空，暂无 Markdown 预览"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    } else {
                        Markdown(draft.body)
                            .markdownTheme(markdownPreviewTheme)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
                .frame(minHeight: 240)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardOutline.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }

    private var markdownPreviewTheme: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(Color.appForeground)
            }
            .link {
                ForegroundColor(Color.neonYellow)
            }
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "tags_comma_separated", defaultValue: "标签（逗号分隔）"))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: Binding(
                get: {
                    PromptTagPolicy
                        .removingReservedTags(from: draft.tags)
                        .joined(separator: ", ")
                },
                set: { newValue in
                    // 自动替换全角逗号、分号（全角/半角）为半角逗号
                    let normalized = newValue
                        .replacingOccurrences(of: "，", with: ",")  // 全角逗号 → 半角逗号
                        .replacingOccurrences(of: "；", with: ",")  // 全角分号 → 半角逗号
                        .replacingOccurrences(of: ";", with: ",")   // 半角分号 → 半角逗号
                    let rawTags = normalized
                        .split(separator: ",")
                        .map { String($0) }
                    draft.tags = PromptTagPolicy.normalize(rawTags, for: prompt.kind)
                }
            ))
            .textFieldStyle(.roundedBorder)
            
            if recentTags.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "recent_tags", defaultValue: "最近使用的标签"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    TagFlowLayout(spacing: 6) {
                        ForEach(recentTags, id: \.self) { tag in
                            Button {
                                addTagIfNeeded(tag)
                            } label: {
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(draft.tags.contains(tag) ? Color.neonYellow : Color.cardSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.cardOutline.opacity(0.4), lineWidth: 1)
                                    )
                                    .foregroundStyle(draft.tags.contains(tag) ? Color.black : Color.appForeground)
                            }
                            .buttonStyle(.plain)
                            .disabled(draft.tags.contains(tag))
                        }
                    }
                }
            }
        }
    }

    private var parameterDefaultsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "parameter_defaults", defaultValue: "参数默认值"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(localized: "param_defaults_description", defaultValue: "这里修改的值只影响模板默认配置，不会立即覆盖主页 Workspace 中的实时参数。"))
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if draft.params.isEmpty {
                Text(String(localized: "param_defaults_empty", defaultValue: "正文中的 {placeholder} 会自动同步到这里，方便为每个参数配置默认值。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(draft.params.enumerated()), id: \.element.id) { index, param in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("{\(param.key)}")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.appForeground)

                            TextField(String(localized: "default_value", defaultValue: "默认值"), text: Binding(
                                get: { draft.params[index].defaultValue ?? "" },
                                set: {
                                    let trimmedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                    draft.params[index].defaultValue = trimmedValue.isEmpty ? nil : trimmedValue
                                }
                            ), prompt: Text(String(localized: "empty_means_no_default", defaultValue: "留空代表默认不填")))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))

                            Text(parameterStatusText(for: draft.params[index]))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.cardSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cardOutline.opacity(0.45), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                attemptDelete()
            } label: {
                Label(String(localized: "delete_prompt", defaultValue: "删除模板"), systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                togglePinned()
            } label: {
                Label(draft.pinned ? String(localized: "unpin", defaultValue: "取消置顶") : String(localized: "pin", defaultValue: "置顶"), systemImage: draft.pinned ? "pin.slash" : "pin.fill")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("b", modifiers: .command)

            Spacer()

            if isDirty {
                HStack(spacing: 12) {
                    Button(String(localized: "cancel", defaultValue: "取消")) {
                        attemptCancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)

                    Button(String(localized: "save", defaultValue: "保存")) {
                        saveDraftAndDismiss()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.neonYellow)
                    .foregroundStyle(Color.black)
                }
            } else {
                Button(String(localized: "close", defaultValue: "关闭")) {
                    dismissWithoutSaving()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Color.cardSurface)
    }

    private func togglePinned() {
        withAnimation(.easeInOut(duration: 0.2)) {
            draft.pinned.toggle()
        }
    }

    private func parameterStatusText(for param: ParamDraft) -> String {
        let defaultValue = param.defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if defaultValue.isEmpty {
            return String(localized: "no_default_value_set", defaultValue: "未设置默认值，在模板卡片使用时会高亮提示补全。")
        }
        
        return String(format: String(localized: "param_default_value", defaultValue: "默认值：%@"), defaultValue)
    }

    private func syncDraftParams() {
        let keys = TemplateEngine.placeholders(in: draft.body)
        var existing = Dictionary(uniqueKeysWithValues: draft.params.map { ($0.key, $0) })
        var ordered: [ParamDraft] = []

        for key in keys {
            if let current = existing.removeValue(forKey: key) {
                ordered.append(current)
            } else {
                // 新占位符默认为空默认值，等待用户填写
                let created = ParamDraft(key: key, defaultValue: nil)
                ordered.append(created)
            }
        }

        draft.params = ordered
    }

    private func saveDraftAndDismiss() {
        guard isDirty else {
            pendingDialog = nil
            dismiss()
            return
        }

        applyDraftToPrompt()
        prompt.updateTimestamp()
        let capturedRevision = VersioningService.captureRevision(for: prompt, in: modelContext)
        do {
            try modelContext.save()
            if capturedRevision != nil {
                refreshRevisionSelections()
            }
            pendingDialog = nil
            dismiss()
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    private func applyDraftToPrompt() {
        prompt.title = draft.title
        prompt.body = draft.body
        prompt.pinned = draft.pinned
        prompt.tags = PromptTagPolicy.normalize(draft.tags, for: prompt.kind)

        var existing = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0) })
        var ordered: [ParamKV] = []

        for param in draft.params {
            let normalizedDefault = param.defaultValue
            if let current = existing.removeValue(forKey: param.key) {
                current.defaultValue = normalizedDefault
                ordered.append(current)
            } else {
                let created = ParamKV(
                    key: param.key,
                    value: "",
                    defaultValue: normalizedDefault,
                    owner: prompt
                )
                ordered.append(created)
            }
        }

        for removed in existing.values {
            modelContext.delete(removed)
        }

        prompt.params = ordered
    }

    private func attemptCancel() {
        if isDirty {
            pendingDialog = .discardDraft
        } else {
            dismiss()
        }
    }

    private func dismissWithoutSaving() {
        pendingDialog = nil
        dismiss()
    }

    private func attemptDelete() {
        pendingDialog = .deletePrompt
    }

    private var isDirty: Bool {
        guard hasLoadedDraft else { return false }
        return draft.differs(from: prompt)
    }

    private func refreshRevisionSelections() {
        let availableIDs = Set(prompt.revisions.map(\.uuid))
        if let baselineID = selectedBaselineRevisionID, availableIDs.contains(baselineID) == false {
            selectedBaselineRevisionID = nil
        }
        if let comparisonID = selectedComparisonRevisionID,
           comparisonID != VersionHistoryCurrentSelectionID,
           availableIDs.contains(comparisonID) == false {
            selectedComparisonRevisionID = nil
        }
        if selectedComparisonRevisionID == nil {
            selectedComparisonRevisionID = VersionHistoryCurrentSelectionID
        }
    }

    private var dialogPresentedBinding: Binding<Bool> {
        Binding(
            get: { pendingDialog != nil },
            set: { newValue in
                if newValue == false {
                    pendingDialog = nil
                }
            }
        )
    }

    private var currentDialogTitle: String {
        switch pendingDialog {
        case .discardDraft:
            return String(localized: "discard_changes_title", defaultValue: "放弃修改？")
        case .deletePrompt:
            return String(localized: "delete_prompt_title", defaultValue: "删除模板？")
        case .none:
            return ""
        }
    }

    private var currentDialogMessage: String? {
        switch pendingDialog {
        case .discardDraft:
            return String(localized: "discard_changes_message", defaultValue: "取消后当前缓冲的修改会丢失，确定要放弃吗？")
        case .deletePrompt:
            return String(localized: "delete_prompt_message", defaultValue: "此操作不可撤销，将永久删除该模板及其参数，确定要删除吗？")
        case .none:
            return nil
        }
    }

    private enum PendingDialog: Identifiable {
        case discardDraft
        case deletePrompt
        var id: Int { hashValue }
    }

    private struct ParamDraft: Identifiable, Equatable {
        let key: String
        var defaultValue: String?

        var id: String { key }
    }

    private struct PromptDraft: Equatable {
        var title: String
        var body: String
        var pinned: Bool
        var tags: [String]
        var params: [ParamDraft]

        static let empty = PromptDraft(title: "", body: "", pinned: false, tags: [], params: [])

        init(title: String, body: String, pinned: Bool, tags: [String], params: [ParamDraft]) {
            self.title = title
            self.body = body
            self.pinned = pinned
            self.tags = tags
            self.params = params
        }

        init(from prompt: PromptItem) {
            self.title = prompt.title
            self.body = prompt.body
            self.pinned = prompt.pinned
            self.tags = PromptTagPolicy.normalize(prompt.tags, for: prompt.kind)
            self.params = prompt.params.map { param in
                ParamDraft(key: param.key, defaultValue: param.defaultValue)
            }
        }

        func differs(from prompt: PromptItem) -> Bool {
            if title != prompt.title { return true }
            if body != prompt.body { return true }
            if pinned != prompt.pinned { return true }
            if tags != prompt.tags { return true }

            let modelParams = prompt.params
            if params.count != modelParams.count { return true }

            let lookup = Dictionary(uniqueKeysWithValues: modelParams.map { ($0.key, $0) })
            for draftParam in params {
                guard let modelParam = lookup[draftParam.key] else { return true }
                if draftParam.defaultValue != modelParam.defaultValue { return true }
            }
            return false
        }
    }

    private func deletePrompt() {
        modelContext.delete(prompt)
        do {
            try modelContext.save()
            pendingDialog = nil
            dismiss()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
    
    private func addAgentContextFiles() {
        Task { @MainActor in
            do {
                let urls = try AgentContextFileService.shared.chooseMarkdownFiles()
                guard urls.isEmpty == false else { return }
                try AgentContextFileService.shared.appendAttachments(urls, to: prompt)
                normalizeAttachmentOrder()
                saveContextAfterAttachmentChange(reason: "agentContext-add")
                showAttachmentToast(message: String(format: String(localized: "files_associated", defaultValue: "已关联 %lld 个文件"), urls.count), icon: "paperclip")
            } catch AgentContextFileService.SelectionError.userCancelled {
                // 用户取消，无需处理
            } catch {
                attachmentAlert = AlertItem(
                    title: String(localized: "add_file_failed", defaultValue: "添加失败"),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func pushAgentBodyToFiles() {
        guard hasAgentAttachments else {
            attachmentAlert = AlertItem(
                title: String(localized: "no_files_to_overwrite", defaultValue: "没有可覆写的文件"),
                message: String(localized: "add_markdown_files_first", defaultValue: "请先添加需要同步的 Markdown 文件。")
            )
            return
        }
        guard hasAttachmentOperationInFlight == false else { return }
        guard commitDraftForAgentOperation() else { return }

        isPushingAgentFiles = true
        Task { @MainActor in
            defer { isPushingAgentFiles = false }
            let results = AgentContextFileService.shared.overwrite(prompt.body, to: orderedAttachments)
            saveContextAfterAttachmentChange(reason: "agentContext-pushAll")

            let successCount = results.filter(\.isSuccess).count
            if successCount > 0 {
                showAttachmentToast(message: String(format: String(localized: "overwrite_success", defaultValue: "已覆写 %lld 个文件"), successCount), icon: "square.and.arrow.down")
            }

            if let failure = results.first(where: { $0.isSuccess == false }),
               let error = failure.error {
                attachmentAlert = AlertItem(
                    title: String(localized: "overwrite_failed", defaultValue: "覆写失败"),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func syncAgentBodyFromFile() {
        guard let attachment = primaryAttachment else {
            attachmentAlert = AlertItem(
                title: String(localized: "cannot_sync", defaultValue: "无法同步"),
                message: String(localized: "add_file_before_sync", defaultValue: "请先在附件列表中添加并排序至少一个文件。")
            )
            return
        }
        guard hasAttachmentOperationInFlight == false else { return }

        isPullingAgentFile = true
        Task { @MainActor in
            defer { isPullingAgentFile = false }
            let result = AgentContextFileService.shared.pullContent(from: attachment)
            if let error = result.error {
                saveContextAfterAttachmentChange(reason: "agentContext-syncPrimary-error")
                attachmentAlert = AlertItem(
                    title: String(localized: "sync_failed", defaultValue: "同步失败"),
                    message: error.localizedDescription
                )
                return
            }

            let newBody = result.content ?? ""
            draft.body = newBody
            syncDraftParams()
            if commitDraftForAgentOperation() {
                showAttachmentToast(message: String(format: String(localized: "sync_from_file", defaultValue: "已从「%@」同步"), attachment.displayName), icon: "arrow.down.doc")
            }
        }
    }

    private func overwriteSingleAttachment(_ attachment: PromptFileAttachment) {
        guard hasAttachmentOperationInFlight == false else { return }
        guard commitDraftForAgentOperation() else { return }

        isPushingAgentFiles = true
        Task { @MainActor in
            defer { isPushingAgentFiles = false }
            let result = AgentContextFileService.shared.overwrite(prompt.body, to: [attachment]).first
            saveContextAfterAttachmentChange(reason: "agentContext-pushSingle")

            if let result, result.isSuccess {
                showAttachmentToast(message: String(format: String(localized: "overwritten_file", defaultValue: "已覆写「%@」"), attachment.displayName), icon: "square.and.arrow.down")
            } else if let error = result?.error {
                attachmentAlert = AlertItem(
                    title: String(format: String(localized: "file_overwrite_failed", defaultValue: "%@ 覆写失败"), attachment.displayName),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func syncFromAttachment(_ attachment: PromptFileAttachment) {
        guard hasAttachmentOperationInFlight == false else { return }

        isPullingAgentFile = true
        Task { @MainActor in
            defer { isPullingAgentFile = false }
            let result = AgentContextFileService.shared.pullContent(from: attachment)
            if let error = result.error {
                saveContextAfterAttachmentChange(reason: "agentContext-syncSingle-error")
                attachmentAlert = AlertItem(
                    title: String(format: String(localized: "file_sync_failed", defaultValue: "%@ 同步失败"), attachment.displayName),
                    message: error.localizedDescription
                )
                return
            }

            let newBody = result.content ?? ""
            draft.body = newBody
            syncDraftParams()
            if commitDraftForAgentOperation() {
                showAttachmentToast(message: String(format: String(localized: "sync_from_file", defaultValue: "已从「%@」同步"), attachment.displayName), icon: "arrow.down.doc")
            }
        }
    }

    private func moveAttachment(_ attachment: PromptFileAttachment, direction: Int) {
        guard let currentIndex = orderedAttachments.firstIndex(where: { $0.persistentModelID == attachment.persistentModelID }) else {
            return
        }
        let targetIndex = currentIndex + direction
        var reordered = orderedAttachments
        guard reordered.indices.contains(targetIndex) else { return }
        reordered.swapAt(currentIndex, targetIndex)
        for (index, item) in reordered.enumerated() {
            item.orderHint = index
        }
        prompt.attachments = reordered
        saveContextAfterAttachmentChange(reason: "agentContext-move")
    }

    private func makeAttachmentPrimary(_ attachment: PromptFileAttachment) {
        guard primaryAttachment?.persistentModelID != attachment.persistentModelID else { return }
        var reordered = orderedAttachments.filter { $0.persistentModelID != attachment.persistentModelID }
        reordered.insert(attachment, at: 0)
        for (index, item) in reordered.enumerated() {
            item.orderHint = index
        }
        prompt.attachments = reordered
        saveContextAfterAttachmentChange(reason: "agentContext-primary")
    }

    private func removeAttachment(_ attachment: PromptFileAttachment) {
        modelContext.delete(attachment)
        prompt.attachments.removeAll { $0.persistentModelID == attachment.persistentModelID }
        normalizeAttachmentOrder()
        saveContextAfterAttachmentChange(reason: "agentContext-remove")
        showAttachmentToast(message: String(format: String(localized: "removed_attachment", defaultValue: "已移除「%@」"), attachment.displayName), icon: "trash")
    }

    private func normalizeAttachmentOrder() {
        let normalized = orderedAttachments.enumerated().map { index, item -> PromptFileAttachment in
            item.orderHint = index
            return item
        }
        prompt.attachments = normalized
    }

    @discardableResult
    private func commitDraftForAgentOperation(updateTimestamp: Bool = true) -> Bool {
        syncDraftParams()
        applyDraftToPrompt()
        if updateTimestamp {
            prompt.updateTimestamp()
        }
        do {
            try modelContext.save()
            draft = PromptDraft(from: prompt)
            return true
        } catch {
            attachmentAlert = AlertItem(
                title: String(localized: "save_failure", defaultValue: "保存失败"),
                message: error.localizedDescription
            )
            return false
        }
    }

    private func saveContextAfterAttachmentChange(reason _: String) {
        do {
            try modelContext.save()
        } catch {
            attachmentAlert = AlertItem(
                title: String(localized: "save_failure", defaultValue: "保存失败"),
                message: error.localizedDescription
            )
        }
    }

    private func showAttachmentToast(message: String, icon: String) {
        let toast = OperationToast(message: message, iconSystemName: icon)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            attachmentToast = toast
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if attachmentToast?.id == toast.id {
                withAnimation(.easeInOut(duration: 0.25)) {
                    attachmentToast = nil
                }
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var recentTags: [String] {
        var tagFrequency: [String: (count: Int, lastUsed: Date)] = [:]
        
        for promptItem in allPrompts {
            for tag in promptItem.tags {
                let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedTag.isEmpty == false else { continue }
                if PromptTagPolicy.isReservedTag(trimmedTag) {
                    continue
                }
                
                if let existing = tagFrequency[trimmedTag] {
                    tagFrequency[trimmedTag] = (
                        count: existing.count + 1,
                        lastUsed: max(existing.lastUsed, promptItem.updatedAt)
                    )
                } else {
                    tagFrequency[trimmedTag] = (count: 1, lastUsed: promptItem.updatedAt)
                }
            }
        }
        
        return tagFrequency
            .sorted { lhs, rhs in
                if lhs.value.lastUsed != rhs.value.lastUsed {
                    return lhs.value.lastUsed > rhs.value.lastUsed
                }
                return lhs.value.count > rhs.value.count
            }
            .prefix(10)
            .map(\.key)
    }
    
    private func addTagIfNeeded(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTag.isEmpty == false else { return }
        if PromptTagPolicy.isReservedTag(trimmedTag), prompt.kind != .agentContext {
            return
        }
        guard draft.tags.contains(trimmedTag) == false else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            draft.tags = PromptTagPolicy.normalize(draft.tags + [trimmedTag], for: prompt.kind)
        }
    }
}
