//
//  TemplateCardView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import AppKit
import MarkdownUI
import SwiftData
import SwiftUI

struct TemplateCardView: View {
    private enum CardContentMode: String, CaseIterable {
        case template
        case preview

        var label: String {
            switch self {
            case .template:
                return "模板"
            case .preview:
                return "预览"
            }
        }
    }

    private struct ParamFocusTarget: Hashable {
        let id: PersistentIdentifier
    }

    private struct ContextQuickActionSnapshot {
        let id: String
        let isPinned: Bool
    }

    private enum ParamInputLayoutOverride: Hashable {
        case auto
        case single
        case multiline
    }

    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem

    let onOpenDetail: () -> Void
    let onCopy: () -> Void
    let onDelete: (PromptItem) -> Void
    let onClone: (PromptItem) -> Void
    let onFilterByTag: (String) -> Void
    let onLaunchToolboxApp: (ToolboxApp) -> Void
    let toolboxApps: [ToolboxApp]

    @State private var showCopiedHUD = false
    @State private var isMarkdownPreview = false
    @State private var contentMode: CardContentMode = .template
    @FocusState private var focusedParam: ParamFocusTarget?
    @State private var lastFocusedParam: ParamFocusTarget?
    @State private var paramToReset: ParamKV?
    @State private var showResetAllConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isHoveringCard = false
    @State private var isPinHovered = false
    @State private var isCopyHovered = false
    @State private var isEditHovered = false
    @State private var isResetAllHovered = false
    @State private var hoveredResetParamID: PersistentIdentifier?
    @State private var isShowingRenameSheet = false
    @State private var draftSummaryTitle = ""
    @State private var paramDrafts: [PersistentIdentifier: String] = [:]
    @State private var pendingSaveTasks: [PersistentIdentifier: Task<Void, Never>] = [:]
    @State private var paramLayoutOverrides: [PersistentIdentifier: ParamInputLayoutOverride] = [:]

    private var renderResult: TemplateEngine.RenderResult {
        let values = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0.resolvedValue) })
        return TemplateEngine.render(template: prompt.body, values: values)
    }

    private func isParamMissing(_ param: ParamKV) -> Bool {
        param.isEffectivelyEmpty
    }
    
    /// 判断参数值是否应该使用多行输入框
    private func shouldUseMultilineInput(_ param: ParamKV) -> Bool {
        let content = param.value.isEmpty ? (param.defaultValue ?? "") : param.value
        return content.count > 16 || content.contains("\n")
    }

    private var cardMarkdownTheme: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(Color.appForeground)
            }
            .link {
                ForegroundColor(Color.neonYellow)
            }
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(cardBorderColor, lineWidth: 1)
            )
            .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowYOffset)
    }

    private var cardBorderColor: Color {
        Color.cardOutline.opacity(isHoveringCard ? 0.7 : 0.45)
    }

    private var cardShadowColor: Color {
        Color.black.opacity(isHoveringCard ? 0.18 : 0.08)
    }

    private var cardShadowRadius: CGFloat {
        isHoveringCard ? 12 : 20
    }

    private var cardShadowYOffset: CGFloat {
        isHoveringCard ? 6 : 12
    }

    private var copyButtonBackground: Color {
        isCopyHovered ? Color.neonYellow : Color.black
    }

    /// 确保在布局切换后仍然聚焦到用户正在编辑的参数。
    private func restoreFocusIfNeeded(for param: ParamKV) {
        guard lastFocusedParam?.id == param.persistentModelID else { return }
        let target = ParamFocusTarget(id: param.persistentModelID)
        DispatchQueue.main.async {
            guard focusedParam?.id != param.persistentModelID else { return }
            focusedParam = target
        }
    }

    private var copyButtonForeground: Color {
        isCopyHovered ? Color.black : Color.white
    }

    private var copyButtonBorder: Color {
        isCopyHovered ? Color.neonYellow.opacity(0.9) : Color.clear
    }

    private let quickActionVisualDiameter: CGFloat = 26
    private let quickActionTapTarget: CGFloat = 34

    private var interactionAnimation: Animation {
        .spring(response: 0.2, dampingFraction: 0.82)
    }

    /// Snapshot for inline quick action menu showing full metadata
    private func makeInlineQuickActionSnapshot() -> TemplateInlineQuickActionMenu.Snapshot {
        TemplateInlineQuickActionMenu.Snapshot(
            id: prompt.uuid,
            isPinned: prompt.pinned,
            createdAt: prompt.createdAt,
            updatedAt: prompt.updatedAt,
            tags: prompt.tags,
            toolboxApps: toolboxApps.map {
                TemplateInlineQuickActionMenu.ToolboxAppLite(
                    id: $0.id,
                    displayName: $0.displayName,
                    kind: $0.optionKind
                )
            }
        )
    }

    /// Snapshot for lightweight context menu usage
    private func makeContextQuickActionSnapshot() -> ContextQuickActionSnapshot {
        ContextQuickActionSnapshot(
            id: prompt.uuid,
            isPinned: prompt.pinned
        )
    }

    private var contextMenuConfiguration: TemplateCardContextMenuBridge.Configuration {
        let snapshot = makeContextQuickActionSnapshot()
        let title = prompt.title.isEmpty ? "未命名模板" : prompt.title
        return TemplateCardContextMenuBridge.Configuration(
            headerTitle: title,
            actions: [
                .init(
                    title: "编辑模板",
                    systemImageName: "rectangle.and.pencil.and.ellipsis"
                ) {
                    sendQuickAction(.openDetail(id: snapshot.id))
                },
                .init(
                    title: "复制",
                    systemImageName: "square.and.pencil"
                ) {
                    sendQuickAction(.copyFilledPrompt(id: snapshot.id))
                },
                .init(
                    title: "仅复制模板",
                    systemImageName: "doc.on.doc"
                ) {
                    sendQuickAction(.copyTemplateOnly(id: snapshot.id))
                },
                .init(
                    title: snapshot.isPinned ? "取消置顶" : "置顶此模板",
                    systemImageName: "pin"
                ) {
                    sendQuickAction(.togglePin(id: snapshot.id))
                },
                .init(
                    title: "更改摘要…",
                    systemImageName: "text.badge.star"
                ) {
                    sendQuickAction(.rename(id: snapshot.id))
                },
                .init(
                    title: "克隆模板",
                    systemImageName: "doc.on.doc"
                ) {
                    sendQuickAction(.clone(id: snapshot.id))
                },
                .init(
                    title: "重置所有参数",
                    systemImageName: "arrow.counterclockwise.circle"
                ) {
                    sendQuickAction(.resetAllParams(id: snapshot.id))
                },
                .init(
                    title: "删除模板",
                    systemImageName: "trash",
                    role: .destructive
                ) {
                    sendQuickAction(.delete(id: snapshot.id))
                }
            ]
        )
    }

    init(
        prompt: PromptItem,
        toolboxApps: [ToolboxApp] = [],
        onCopy: @escaping () -> Void = {},
        onDelete: @escaping (PromptItem) -> Void = { _ in },
        onClone: @escaping (PromptItem) -> Void = { _ in },
        onFilterByTag: @escaping (String) -> Void = { _ in },
        onLaunchToolboxApp: @escaping (ToolboxApp) -> Void = { _ in },
        onOpenDetail: @escaping () -> Void
    ) {
        self._prompt = Bindable(prompt)
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onClone = onClone
        self.onFilterByTag = onFilterByTag
        self.onLaunchToolboxApp = onLaunchToolboxApp
        self.toolboxApps = toolboxApps
        self.onOpenDetail = onOpenDetail
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                    .overlay(Color.cardOutline.opacity(0.4))
                parameterFields
                contentSection
            }
            .padding(20)
            .background(cardChrome)

            if showCopiedHUD {
                CopiedHUDView()
                    .padding(.top, -10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { hovering in
            guard isHoveringCard != hovering else { return }
            withAnimation(interactionAnimation) {
                isHoveringCard = hovering
            }
        }
        .animation(interactionAnimation, value: isHoveringCard)
        .onTapGesture(count: 2) {
            onOpenDetail()
        }
        // .id(prompt.id)
        .overlay(
            TemplateCardContextMenuBridge(configuration: contextMenuConfiguration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .id(prompt.id)
        .confirmationDialog(
            "重置参数",
            isPresented: Binding(
                get: { paramToReset != nil },
                set: { if !$0 { paramToReset = nil } }
            ),
            presenting: paramToReset
        ) { param in
            Button("重置为默认值", role: .destructive) {
                resetParam(param)
            }
            Button("取消", role: .cancel) {
                paramToReset = nil
            }
        } message: { param in
            Text("确定要将参数 {\(param.key)} 重置为默认值吗？")
        }
        .confirmationDialog(
            "重置所有参数",
            isPresented: $showResetAllConfirmation
        ) {
            Button("重置所有参数", role: .destructive) {
                resetAllParams()
            }
            Button("取消", role: .cancel) {
                showResetAllConfirmation = false
            }
        } message: {
            Text("确定要将所有 \(prompt.params.count) 个参数重置为默认值吗？此操作将覆盖所有当前值。")
        }
        .confirmationDialog(
            "删除模板",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete(prompt)
                showDeleteConfirmation = false
            }
            Button("取消", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("确定要删除「\(prompt.title.isEmpty ? "未命名模板" : prompt.title)」吗？此操作不可撤销。")
        }
        .sheet(isPresented: $isShowingRenameSheet) {
            RenameSummarySheet(
                title: $draftSummaryTitle,
                onCancel: {
                    isShowingRenameSheet = false
                },
                onConfirm: {
                    applyNewSummary()
                }
            )
            .frame(minWidth: 320, minHeight: 180)
        }
        .onChange(of: focusedParam) { newValue in
            guard let target = newValue else { return }
            lastFocusedParam = target
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text(prompt.title.isEmpty ? "未命名" : prompt.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appForeground.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        togglePinned()
                    } label: {
                        PinGlyph(
                            isPinned: prompt.pinned,
                            circleDiameter: 28,
                            isHighlighted: isPinHovered || (!prompt.pinned && isHoveringCard)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        guard isPinHovered != hovering else { return }
                        withAnimation(interactionAnimation) {
                            isPinHovered = hovering
                        }
                    }
                    .scaleEffect(isPinHovered ? 1.04 : 1.0)
                    .animation(interactionAnimation, value: isPinHovered)
                    .help(prompt.pinned ? "取消置顶" : "置顶")

                    Button {
                        onOpenDetail()
                    } label: {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .imageScale(.medium)
                            .foregroundStyle(Color.appForeground.opacity(isEditHovered ? 1.0 : 0.7))
                            .padding(8)
                            .background(Capsule().strokeBorder(Color.cardOutline.opacity(isEditHovered ? 0.9 : 0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        guard isEditHovered != hovering else { return }
                        withAnimation(interactionAnimation) {
                            isEditHovered = hovering
                        }
                    }
                    .scaleEffect(isEditHovered ? 1.04 : 1.0)
                    .animation(interactionAnimation, value: isEditHovered)
                    .help("查看更多设置")

                    Menu {
                        let snapshot = makeInlineQuickActionSnapshot()
                        TemplateInlineQuickActionMenu(
                            snapshot: snapshot,
                            onAction: sendQuickAction
                        )
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appForeground.opacity(0.7))
                            .frame(width: quickActionVisualDiameter, height: quickActionVisualDiameter)
                            .frame(width: quickActionTapTarget, height: quickActionTapTarget)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("快捷操作")
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if !prompt.tags.isEmpty {
                        TagFlowLayout(spacing: 8) {
                            ForEach(prompt.tags, id: \.self) { tag in
                                TagBadge(tag: tag)
                            }
                        }
                    }
                }
                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Button {
                        copyFilledPrompt()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(copyButtonBackground)
                            )
                            .foregroundStyle(copyButtonForeground)
                            .overlay(
                                Capsule()
                                    .stroke(copyButtonBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        guard isCopyHovered != hovering else { return }
                        withAnimation(interactionAnimation) {
                            isCopyHovered = hovering
                        }
                    }
                    .scaleEffect(isCopyHovered ? 1.04 : 1.0)
                    .animation(interactionAnimation, value: isCopyHovered)
                    .keyboardShortcut("d", modifiers: .command)

                    Button("仅复制模板") {
                        copyTemplateOnly()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appForeground.opacity(0.8))
                    .buttonStyle(.plain)

                    if !renderResult.missingKeys.isEmpty {
                        Text("待填写：\(renderResult.missingKeys.joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private var parameterFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            if prompt.params.isEmpty {
                Text("此模板暂无参数，直接复制即可")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center) {
                    Text("参数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showResetAllConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("重置所有")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.appForeground.opacity(isResetAllHovered ? 0.9 : 0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.cardSurface.opacity(isResetAllHovered ? 1.0 : 0.8))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.cardOutline.opacity(isResetAllHovered ? 1.0 : 0.8), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        guard isResetAllHovered != hovering else { return }
                        withAnimation(interactionAnimation) {
                            isResetAllHovered = hovering
                        }
                    }
                    .scaleEffect(isResetAllHovered ? 1.04 : 1.0)
                    .animation(interactionAnimation, value: isResetAllHovered)
                    .help("将所有参数重置为默认值")
                }
                .padding(.bottom, 4)

                ForEach(prompt.params, id: \.persistentModelID) { paramModel in
                    let isMissing = isParamMissing(paramModel)
                    let focusTarget = ParamFocusTarget(id: paramModel.persistentModelID)
                    let useMultiline = shouldUseMultilineInput(paramModel)

                    Group {
                        if useMultiline {
                            // 多行输入：垂直布局
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text("\(paramModel.key)=")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.neonYellow.opacity(0.4)))
                                        .foregroundStyle(Color.black)

                                    Text("多行输入")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.cardSurface)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.cardOutline.opacity(0.6), lineWidth: 0.8)
                                        )

                                    Spacer()

                                    Button {
                                        paramToReset = paramModel
                                    } label: {
                                        let isHovered = hoveredResetParamID == paramModel.persistentModelID
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.appForeground.opacity(isHovered ? 0.8 : 0.6))
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(Color.cardSurface.opacity(isHovered ? 1.0 : 0.8)))
                                            .overlay(Circle().stroke(Color.cardOutline.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { hovering in
                                        withAnimation(interactionAnimation) {
                                            hoveredResetParamID = hovering ? paramModel.persistentModelID : nil
                                        }
                                    }
                                    .scaleEffect(hoveredResetParamID == paramModel.persistentModelID ? 1.08 : 1.0)
                                    .animation(interactionAnimation, value: hoveredResetParamID == paramModel.persistentModelID)
                                    .help("重置为默认值")
                                }

                                TextEditor(text: binding(for: paramModel))
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.appForeground)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 80, maxHeight: 140, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isMissing ? Color.neonYellow : Color.cardOutline, lineWidth: isMissing ? 1.6 : 1)
                                )
                                .shadow(color: isMissing ? Color.neonYellow.opacity(0.22) : Color.black.opacity(0.04), radius: isMissing ? 6 : 1.2, y: isMissing ? 3 : 1)
                                .focused($focusedParam, equals: focusTarget)
                                .onAppear {
                                    primeDraft(for: paramModel)
                                    restoreFocusIfNeeded(for: paramModel)
                                }
                                .onChange(of: focusedParam == focusTarget) { isFocused in
                                    if isFocused {
                                        logParamEvent("focusGained", param: paramModel)
                                        primeDraft(for: paramModel)
                                    } else {
                                        logParamEvent("focusLost", param: paramModel)
                                        finalizeDraft(for: paramModel)
                                    }
                                }
                                .onChange(of: paramModel.value) { newValue in
                                    syncDraftWithModelValue(newValue, for: paramModel)
                                }
                                .onDisappear {
                                    finalizeDraft(for: paramModel)
                                }
                            }
                            .padding(.horizontal, 4)
                        } else {
                            // 单行输入：保持原来的横向布局
                            HStack(spacing: 10) {
                                Text("\(paramModel.key)=")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.neonYellow.opacity(0.4)))
                                    .foregroundStyle(Color.black)

                                TextField(
                                    "{\(paramModel.key)}",
                                    text: binding(for: paramModel),
                                    prompt: (paramModel.defaultValue ?? "").isEmpty ? nil : Text(paramModel.defaultValue ?? ""),
                                    axis: .horizontal
                                )
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
                                .focused($focusedParam, equals: focusTarget)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .lineLimit(1)
                                .onAppear {
                                    primeDraft(for: paramModel)
                                    restoreFocusIfNeeded(for: paramModel)
                                }
                                .onChange(of: focusedParam == focusTarget) { isFocused in
                                    if isFocused {
                                        primeDraft(for: paramModel)
                                    } else {
                                        finalizeDraft(for: paramModel)
                                    }
                                }
                                .onChange(of: paramModel.value) { newValue in
                                    syncDraftWithModelValue(newValue, for: paramModel)
                                }
                                .onSubmit {
                                    finalizeDraft(for: paramModel)
                                }
                                .onDisappear {
                                    finalizeDraft(for: paramModel)
                                }

                                Button {
                                    paramToReset = paramModel
                                } label: {
                                    let isHovered = hoveredResetParamID == paramModel.persistentModelID
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.appForeground.opacity(isHovered ? 0.8 : 0.6))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.cardSurface.opacity(isHovered ? 1.0 : 0.8)))
                                        .overlay(Circle().stroke(Color.cardOutline.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    withAnimation(interactionAnimation) {
                                        hoveredResetParamID = hovering ? paramModel.persistentModelID : nil
                                    }
                                }
                                .scaleEffect(hoveredResetParamID == paramModel.persistentModelID ? 1.08 : 1.0)
                                .animation(interactionAnimation, value: hoveredResetParamID == paramModel.persistentModelID)
                                .help("重置为默认值")
                            }
                        }
                    }
                    .onAppear {
                        restoreFocusIfNeeded(for: paramModel)
                    }
                    .onChange(of: useMultiline) { _ in
                        restoreFocusIfNeeded(for: paramModel)
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Picker("", selection: $contentMode) {
                    ForEach(CardContentMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if contentMode == .preview {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMarkdownPreview.toggle()
                        }
                    } label: {
                        Text("M")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isMarkdownPreview ? Color.black : Color.appForeground.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(isMarkdownPreview ? Color.neonYellow : Color.cardSurface)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.cardOutline.opacity(isMarkdownPreview ? 0 : 0.8), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isMarkdownPreview ? "切换到纯文本预览" : "切换到 Markdown 预览")
                }

                Spacer()
            }

            ScrollView {
                switch contentMode {
                case .template:
                    let trimmed = prompt.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        Text("模板内容为空")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        Text(attributedTemplateText())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .textSelection(.enabled)
                    }
                case .preview:
                    if isMarkdownPreview {
                        if renderResult.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("预览内容为空")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        } else {
                            Markdown(renderResult.rendered)
                                .markdownTheme(cardMarkdownTheme)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                    } else {
                        Text(attributedPreviewText())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(minHeight: 140, maxHeight: 220)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardOutline.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private func attributedTemplateText() -> AttributedString {
        var attributed = AttributedString(prompt.body)
        if attributed.characters.isEmpty {
            return attributed
        }

        let raw = prompt.body
        let keys = Set(TemplateEngine.placeholders(in: raw))
        for key in keys {
            let placeholder = "{\(key)}"
            var searchStart = raw.startIndex

            while searchStart < raw.endIndex,
                let range = raw.range(of: placeholder, range: searchStart..<raw.endIndex) {
                if let lower = AttributedString.Index(range.lowerBound, within: attributed),
                   let upper = AttributedString.Index(range.upperBound, within: attributed) {
                    let highlightRange = lower..<upper
                    attributed[highlightRange].foregroundColor = Color.appForeground
                    attributed[highlightRange].backgroundColor = Color.neonYellow.opacity(0.12)
                }
                searchStart = range.upperBound
            }
        }
        return attributed
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

    private func sendQuickAction(_ action: TemplateInlineQuickActionMenu.QuickAction) {
        DispatchQueue.main.async {
            handleQuickAction(action)
        }
    }

    private func handleQuickAction(_ action: TemplateInlineQuickActionMenu.QuickAction) {
        switch action {
        case let .openDetail(id):
            guard id == prompt.uuid else { return }
            onOpenDetail()
        case let .copyFilledPrompt(id):
            guard id == prompt.uuid else { return }
            copyFilledPrompt()
        case let .copyTemplateOnly(id):
            guard id == prompt.uuid else { return }
            copyTemplateOnly()
        case let .togglePin(id):
            guard id == prompt.uuid else { return }
            togglePinned()
        case let .rename(id):
            guard id == prompt.uuid else { return }
            presentRenameSheet()
        case let .clone(id):
            guard id == prompt.uuid else { return }
            onClone(prompt)
        case let .resetAllParams(id):
            guard id == prompt.uuid else { return }
            showResetAllConfirmation = true
        case let .delete(id):
            guard id == prompt.uuid else { return }
            showDeleteConfirmation = true
        case let .filterByTag(id, tag):
            guard id == prompt.uuid else { return }
            onFilterByTag(tag)
        case let .launchToolboxApp(id, appID):
            guard id == prompt.uuid else { return }
            guard let app = toolboxApps.first(where: { $0.id == appID }) else { return }
            copyFilledPrompt()
            onLaunchToolboxApp(app)
        }
    }

    private func presentRenameSheet() {
        draftSummaryTitle = prompt.title
        isShowingRenameSheet = true
    }

    private func applyNewSummary() {
        let trimmed = draftSummaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != prompt.title {
            prompt.title = trimmed
            persistWithTimestampUpdate()
        }
        isShowingRenameSheet = false
    }

    // 仅保存，不更新时间戳（用于参数值变化、置顶等 UI 状态变化）
    private func persistChange() {
        do {
            logDebug("persistChange() start")
            try modelContext.save()
            logDebug("persistChange() success")
        } catch {
            logDebug("persistChange() failed error=\(error)")
            print("保存模板失败: \(error)")
        }
    }
    
    // 保存并更新时间戳（用于内容编辑：title, body, tags）
    private func persistWithTimestampUpdate() {
        prompt.updateTimestamp()
        persistChange()
    }

    private func binding(for param: ParamKV) -> Binding<String> {
        Binding(
            get: { draftValue(for: param) },
            set: { newValue in
                setDraft(newValue, for: param)
            }
        )
    }

    private func draftValue(for param: ParamKV) -> String {
        let id = param.persistentModelID
        if let cached = paramDrafts[id] {
            return cached
        }
        let initial = param.value
        paramDrafts[id] = initial
        logParamEvent("draftValue-miss", param: param, extra: "initialize length=\(initial.count)")
        return initial
    }

    private func setDraft(_ value: String, for param: ParamKV) {
        let id = param.persistentModelID
        paramDrafts[id] = value
        logParamEvent("setDraft", param: param, extra: "length=\(value.count)")
        scheduleSave(for: param, value: value)
    }

    private func primeDraft(for param: ParamKV) {
        let id = param.persistentModelID
        if paramDrafts[id] == nil {
            paramDrafts[id] = param.value
            logParamEvent("primeDraft", param: param, extra: "length=\(param.value.count)")
        }
    }

    private func syncDraftWithModelValue(_ value: String, for param: ParamKV) {
        let id = param.persistentModelID
        if paramDrafts[id] != value {
            logParamEvent("syncDraftWithModelValue", param: param, extra: "length=\(value.count)")
            paramDrafts[id] = value
        }
    }

    private func scheduleSave(for param: ParamKV, value: String) {
        let id = param.persistentModelID
        cancelPendingSave(for: id)
        logParamEvent("scheduleSave", param: param, extra: "delay=0.6 length=\(value.count)")

        let task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }

            let isFocused = focusedParam?.id == param.persistentModelID
            if isFocused {
                logParamEvent("debouncedSaveSkippedPersistFocused", param: param, extra: "length=\(value.count)")
                pendingSaveTasks[id] = nil
                return
            } else {
                logParamEvent("debouncedSaveFired", param: param, extra: "length=\(value.count)")
                applyDraft(value, to: param)
            }
            pendingSaveTasks[id] = nil
        }

        pendingSaveTasks[id] = task
    }

    private func finalizeDraft(for param: ParamKV) {
        let id = param.persistentModelID
        logParamEvent("finalizeDraft", param: param)
        cancelPendingSave(for: id)
        let currentDraft = paramDrafts[id] ?? param.value
        applyDraft(currentDraft, to: param)
    }

    private func applyDraft(_ value: String, to param: ParamKV) {
        guard param.value != value else { return }
        logParamEvent(
            "applyDraft",
            param: param,
            extra: "from=\(param.value.count) to=\(value.count)"
        )
        param.value = value
        persistChange(reason: "param:\(param.key)")
    }

    private func cancelPendingSave(for id: PersistentIdentifier) {
        if let task = pendingSaveTasks[id] {
            task.cancel()
            logDebug("cancelPendingSave id=\(id)")
            pendingSaveTasks[id] = nil
        }
    }
#if DEBUG
    private func logParamEvent(_ stage: String, param: ParamKV, extra: String = "") {
        let timestamp = String(format: "%.6f", Date().timeIntervalSince1970)
        let identifier = String(describing: param.persistentModelID)
        if extra.isEmpty {
            print("[ParamDebug \(timestamp)] [\(param.key)] [\(identifier)] \(stage)")
        } else {
            print("[ParamDebug \(timestamp)] [\(param.key)] [\(identifier)] \(stage) :: \(extra)")
        }
    }

    private func logDebug(_ message: String) {
        let timestamp = String(format: "%.6f", Date().timeIntervalSince1970)
        print("[ParamDebug \(timestamp)] \(message)")
    }
#else
    private func logParamEvent(_ stage: String, param: ParamKV, extra: String = "") {}
    private func logDebug(_ message: String) {}
#endif

    private func persistChange(reason: String) {
        logDebug("persistChange(reason=\(reason)) start")
        persistChange()
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

    private func copyTemplateOnly() {
        let template = prompt.body
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(template, forType: .string) {
            showCopiedHUDFeedback()
        } else {
            print("复制失败：无法写入剪贴板")
        }
    }

    private func showCopiedHUDFeedback() {
        withAnimation(.easeOut(duration: 0.2)) {
            showCopiedHUD = true
        }
        onCopy()
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

    private func resetParam(_ param: ParamKV) {
        withAnimation {
            cancelPendingSave(for: param.persistentModelID)
            let newValue = param.defaultValue ?? ""
            param.value = newValue
            paramDrafts[param.persistentModelID] = newValue
            persistChange()
            paramToReset = nil
        }
    }

    private func resetAllParams() {
        withAnimation {
            for param in prompt.params {
                cancelPendingSave(for: param.persistentModelID)
                let newValue = param.defaultValue ?? ""
                param.value = newValue
                paramDrafts[param.persistentModelID] = newValue
            }
            persistChange()
            showResetAllConfirmation = false
        }
    }
}

private struct RenameSummarySheet: View {
    @Binding var title: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("更改摘要")
                    .font(.title3.weight(.semibold))
                Text("更新模板摘要会刷新最近修改时间。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("未命名模板", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit(onConfirm)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("取消", role: .cancel, action: onCancel)
                Button("保存") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            DispatchQueue.main.async {
                isFieldFocused = true
            }
        }
    }
}
