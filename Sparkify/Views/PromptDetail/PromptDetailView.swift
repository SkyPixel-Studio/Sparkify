//
//  PromptDetailView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem
    @FocusState private var focusedField: DetailField?
    @State private var bodyViewMode: BodyViewMode = .edit
    @State private var draft: PromptDraft = .empty
    @State private var hasLoadedDraft = false
    @State private var pendingDialog: PendingDialog?
    @State private var activePage: DetailPage = .editor
    @State private var selectedBaselineRevisionID: String?
    @State private var selectedComparisonRevisionID: String?

    private enum DetailField: Hashable {
        case title, body
    }

    private enum BodyViewMode: String, CaseIterable {
        case edit
        case preview

        var label: String {
            switch self {
            case .edit:
                return "编辑"
            case .preview:
                return "Markdown 预览"
            }
        }
    }

    private enum DetailPage: String, CaseIterable {
        case editor
        case history

        var label: String {
            switch self {
            case .editor:
                return "编辑内容"
            case .history:
                return "版本历史"
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
                Button("放弃修改", role: .destructive, action: dismissWithoutSaving)
                Button("继续编辑", role: .cancel) {}
            case .deletePrompt:
                Button("删除模板", role: .destructive, action: deletePrompt)
                Button("取消", role: .cancel) {}
            case .none:
                EmptyView()
            }
        } message: {
            if let message = currentDialogMessage {
                Text(message)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模板标题")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("模板标题", text: $draft.title, axis: .vertical)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .focused($focusedField, equals: .title)

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
                FilterChip(title: draft.pinned ? "已置顶" : "未置顶", isActive: draft.pinned, tint: draft.pinned ? Color.neonYellow : nil) {
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
            Picker("内容视图", selection: $activePage) {
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

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("正文模板")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("正文模式", selection: $bodyViewMode) {
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
                        Text("正文为空，暂无 Markdown 预览")
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
            Text("标签（逗号分隔）")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("summary, outreach", text: Binding(
                get: { draft.tags.joined(separator: ", ") },
                set: { newValue in
                    draft.tags = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var parameterDefaultsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参数默认值")
                .font(.caption)
                .foregroundStyle(.secondary)

            if draft.params.isEmpty {
                Text("正文中的 {placeholder} 会自动同步到这里，方便为每个参数配置默认值。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(draft.params.enumerated()), id: \.element.id) { index, param in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("{\(param.key)}")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.appForeground)
                                Spacer()
                                Button {
                                    draft.params[index].value = draft.params[index].defaultValue ?? ""
                                } label: {
                                    Label("同步到卡片", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                                .disabled(shouldDisableApplyDefault(for: draft.params[index]))
                                .opacity(shouldDisableApplyDefault(for: draft.params[index]) ? 0.35 : 1)
                                .help("将默认值直接写入模板卡片的当前参数值")
                            }

                            TextField("默认值", text: Binding(
                                get: { draft.params[index].defaultValue ?? "" },
                                set: {
                                    let trimmedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                    var updated = draft.params[index]
                                    updated.defaultValue = trimmedValue.isEmpty ? nil : trimmedValue
                                    if trimmed(updated.value).isEmpty {
                                        updated.value = updated.defaultValue ?? ""
                                    }
                                    draft.params[index] = updated
                                }
                            ), prompt: Text("留空代表默认不填"))
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
                Label("删除模板", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                togglePinned()
            } label: {
                Label(draft.pinned ? "取消置顶" : "置顶", systemImage: draft.pinned ? "pin.slash" : "pin.fill")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("b", modifiers: .command)

            Spacer()

            if isDirty {
                HStack(spacing: 12) {
                    Button("取消") {
                        attemptCancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.bordered)

                    Button("保存") {
                        saveDraftAndDismiss()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.neonYellow)
                    .foregroundStyle(Color.black)
                }
            } else {
                Button("关闭") {
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

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldDisableApplyDefault(for param: ParamDraft) -> Bool {
        trimmed(param.defaultValue ?? "").isEmpty
    }

    private func parameterStatusText(for param: ParamDraft) -> String {
        let effectiveValue = trimmed(param.resolvedValue)
        let currentValue = trimmed(param.value)
        let defaultValue = trimmed(param.defaultValue ?? "")

        if effectiveValue.isEmpty {
            return "此参数默认保持为空，卡片视图会提示补全。"
        }

        if currentValue.isEmpty, defaultValue.isEmpty == false {
            return "卡片默认填入：\(param.defaultValue ?? "")"
        }

        return "当前卡片值：\(param.value)"
    }

    private func syncDraftParams() {
        let keys = TemplateEngine.placeholders(in: draft.body)
        var existing = Dictionary(uniqueKeysWithValues: draft.params.map { ($0.key, $0) })
        var ordered: [ParamDraft] = []

        for key in keys {
            if let current = existing.removeValue(forKey: key) {
                ordered.append(current)
            } else {
                let created = ParamDraft(key: key, value: "", defaultValue: nil)
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
            print("保存模板失败: \(error)")
        }
    }

    private func applyDraftToPrompt() {
        prompt.title = draft.title
        prompt.body = draft.body
        prompt.pinned = draft.pinned
        prompt.tags = draft.tags

        var existing = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0) })
        var ordered: [ParamKV] = []

        for param in draft.params {
            if let current = existing.removeValue(forKey: param.key) {
                current.value = param.value
                current.defaultValue = param.defaultValue
                ordered.append(current)
            } else {
                let created = ParamKV(key: param.key, value: param.value, defaultValue: param.defaultValue, owner: prompt)
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
            return "放弃修改？"
        case .deletePrompt:
            return "删除模板？"
        case .none:
            return ""
        }
    }

    private var currentDialogMessage: String? {
        switch pendingDialog {
        case .discardDraft:
            return "取消后当前缓冲的修改会丢失，确定要放弃吗？"
        case .deletePrompt:
            return "此操作不可撤销，将永久删除该模板及其参数，确定要删除吗？"
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
        var value: String
        var defaultValue: String?

        var id: String { key }

        var resolvedValue: String {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue.isEmpty {
                return (defaultValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return value
        }
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
            self.tags = prompt.tags
            self.params = prompt.params.map { ParamDraft(key: $0.key, value: $0.value, defaultValue: $0.defaultValue) }
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
                if draftParam.value != modelParam.value { return true }
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
            print("删除模板失败: \(error)")
        }
    }
}
