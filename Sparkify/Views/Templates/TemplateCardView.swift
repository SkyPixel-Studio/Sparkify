//
//  TemplateCardView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
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
                return String(localized: "template", defaultValue: "模板")
            case .preview:
                return String(localized: "preview", defaultValue: "预览")
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
    let onShowToast: (String, String) -> Void
    let onPresentError: (String, String) -> Void
    let isHighlighted: Bool

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
    @State private var isCopyTemplateHovered = false
    @State private var isOverwriteHovered = false
    @State private var isSyncHovered = false
    @State private var isEditHovered = false
    @State private var isResetAllHovered = false
    @State private var hoveredResetParamID: PersistentIdentifier?
    @State private var hoveredLayoutParamID: PersistentIdentifier?
    @State private var isShowingRenameSheet = false
    @State private var draftSummaryTitle = ""
    @State private var paramDrafts: [PersistentIdentifier: String] = [:]
    @State private var pendingSaveTasks: [PersistentIdentifier: Task<Void, Never>] = [:]
    @State private var paramLayoutOverrides: [PersistentIdentifier: ParamInputLayoutOverride] = [:]
    @State private var isPushingAgentAttachments = false
    @State private var isPullingAgentAttachment = false

    private var renderResult: TemplateEngine.RenderResult {
        let values = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0.resolvedValue) })
        return TemplateEngine.render(template: prompt.body, values: values)
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

    private var primaryAttachment: PromptFileAttachment? {
        orderedAttachments.first
    }

    private var hasAgentAttachments: Bool {
        orderedAttachments.isEmpty == false
    }

    private func isParamMissing(_ param: ParamKV) -> Bool {
        param.isEffectivelyEmpty
    }
    
    /// 判断参数值是否应该使用多行输入框
    private func shouldUseMultilineInput(_ param: ParamKV) -> Bool {
        let content = layoutCandidateContent(for: param)
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
                    .strokeBorder(cardBorderColor, lineWidth: cardBorderWidth)
            )
            .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowYOffset)
    }

    private var cardBorderColor: Color {
        if isHighlighted {
            return Color.neonYellow
        }
        return Color.cardOutline.opacity(isHoveringCard ? 0.7 : 0.45)
    }

    private var cardShadowColor: Color {
        if isHighlighted {
            return Color.neonYellow.opacity(0.4)
        }
        return Color.black.opacity(isHoveringCard ? 0.18 : 0.08)
    }

    private var cardShadowRadius: CGFloat {
        if isHighlighted {
            return 16
        }
        return isHoveringCard ? 12 : 20
    }

    private var cardShadowYOffset: CGFloat {
        if isHighlighted {
            return 0
        }
        return isHoveringCard ? 6 : 12
    }
    
    private var cardBorderWidth: CGFloat {
        isHighlighted ? 2.5 : 1
    }

    private var copyButtonBackground: Color {
        return isCopyHovered ? Color.neonYellow : Color.black
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
        return isCopyHovered ? Color.black : Color.white
    }

    private var copyButtonBorder: Color {
        return isCopyHovered ? Color.neonYellow.opacity(0.9) : Color.clear
    }

    private var overwriteButtonBackground: Color {
        if hasAgentAttachments == false {
            return Color.cardSurface.opacity(0.6)
        }
        return Color.neonYellow.opacity(isOverwriteHovered ? 1.0 : 0.92)
    }

    private var overwriteButtonForeground: Color {
        if hasAgentAttachments == false {
            return Color.secondary
        }
        return Color.black.opacity(isOverwriteHovered ? 0.95 : 0.85)
    }

    private var overwriteButtonBorder: Color {
        if hasAgentAttachments == false {
            return Color.cardOutline.opacity(0.4)
        }
        return Color.neonYellow.opacity(isOverwriteHovered ? 1.0 : 0.85)
    }

    @ViewBuilder
    private var agentFileActionColumn: some View {
        VStack(spacing: 4) {
            Button {
                overwriteAttachments()
            } label: {
                HStack(spacing: 8) {
                    if isPushingAgentAttachments {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.65)
                            .tint(Color.black.opacity(0.85))
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(String(localized: "overwrite_to_file", defaultValue: "覆写到文件"))
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(overwriteButtonBackground)
                )
                .foregroundStyle(overwriteButtonForeground)
                .overlay(
                    Capsule()
                        .stroke(overwriteButtonBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPushingAgentAttachments || isPullingAgentAttachment || hasAgentAttachments == false)
            .onHover { hovering in
                guard hasAgentAttachments else {
                    isOverwriteHovered = false
                    return
                }
                guard isOverwriteHovered != hovering else { return }
                withAnimation(interactionAnimation) {
                    isOverwriteHovered = hovering
                }
            }
            .scaleEffect(isOverwriteHovered ? 1.04 : 1.0)
            .animation(interactionAnimation, value: isOverwriteHovered)
            .help(String(localized: "write_back_to_all_files", defaultValue: "将模板正文写回所有关联文件"))

            Button(String(localized: "sync_with_file", defaultValue: "与文件同步")) {
                synchronizeFromPrimaryAttachment()
            }
            .font(.system(size: 11, weight: .semibold))
            .fixedSize()
            .foregroundStyle(
                hasAgentAttachments
                    ? Color.appForeground.opacity(isSyncHovered ? 1.0 : 0.75)
                    : Color.secondary.opacity(0.5)
            )
            .buttonStyle(.plain)
            .disabled(isPullingAgentAttachment || hasAgentAttachments == false)
            .onHover { hovering in
                guard hasAgentAttachments else {
                    isSyncHovered = false
                    return
                }
                guard isSyncHovered != hovering else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSyncHovered = hovering
                }
            }
            .overlay(alignment: .trailing) {
                if isPullingAgentAttachment {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.55)
                        .tint(Color.appForeground)
                        .offset(x: 18)
                }
            }
            .help(String(localized: "read_from_primary_file", defaultValue: "从首个关联文件读取内容并刷新模板正文"))
        }
    }

    @ViewBuilder
    private var copyActionColumn: some View {
        VStack(spacing: isAgentContext ? 4 : 6) {
            Button {
                copyFilledPrompt()
            } label: {
                Label(String(localized: "copy", defaultValue: "复制"), systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize()
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

            Button(String(localized: "copy_template_only", defaultValue: "仅复制模板")) {
                copyTemplateOnly()
            }
            .font(.system(size: 11, weight: .semibold))
            .fixedSize()
            .foregroundStyle(Color.appForeground.opacity(isCopyTemplateHovered ? 0.95 : 0.75))
            .buttonStyle(.plain)
            .onHover { hovering in
                guard isCopyTemplateHovered != hovering else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCopyTemplateHovered = hovering
                }
            }
        }
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
            },
            kind: prompt.kind
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
        let title = prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title
        var actions: [TemplateCardContextMenuBridge.Configuration.Action] = [
            .init(
                title: String(localized: "edit_template", defaultValue: "编辑模板"),
                systemImageName: "rectangle.and.pencil.and.ellipsis"
            ) {
                sendQuickAction(.openDetail(id: snapshot.id))
            },
            .init(
                title: String(localized: "copy", defaultValue: "复制"),
                systemImageName: "square.and.pencil"
            ) {
                sendQuickAction(.copyFilledPrompt(id: snapshot.id))
            },
            .init(
                title: String(localized: "copy_template_only", defaultValue: "仅复制模板"),
                systemImageName: "doc.on.doc"
            ) {
                sendQuickAction(.copyTemplateOnly(id: snapshot.id))
            }
        ]

        if isAgentContext {
            actions.append(
                .init(
                    title: String(localized: "overwrite_to_file", defaultValue: "覆写到文件"),
                    systemImageName: "square.and.arrow.down"
                ) {
                    sendQuickAction(.overwriteAgentFiles(id: snapshot.id))
                }
            )
            actions.append(
                .init(
                    title: String(localized: "sync_with_file", defaultValue: "与文件同步"),
                    systemImageName: "arrow.down.doc"
                ) {
                    sendQuickAction(.syncAgentFromFile(id: snapshot.id))
                }
            )
        }

        actions.append(
            .init(
                title: snapshot.isPinned ? String(localized: "unpin_template", defaultValue: "取消置顶") : String(localized: "pin_template", defaultValue: "置顶此模板"),
                systemImageName: "pin"
            ) {
                sendQuickAction(.togglePin(id: snapshot.id))
            }
        )

        actions.append(
            .init(
                title: String(localized: "rename_summary", defaultValue: "更改摘要…"),
                systemImageName: "text.badge.star"
            ) {
                sendQuickAction(.rename(id: snapshot.id))
            }
        )

        actions.append(
            .init(
                title: String(localized: "clone_template", defaultValue: "克隆模板"),
                systemImageName: "doc.on.doc"
            ) {
                sendQuickAction(.clone(id: snapshot.id))
            }
        )

        actions.append(
            .init(
                title: String(localized: "reset_all_params", defaultValue: "重置所有参数"),
                systemImageName: "arrow.counterclockwise.circle"
            ) {
                sendQuickAction(.resetAllParams(id: snapshot.id))
            }
        )

        actions.append(
            .init(
                title: String(localized: "delete_prompt", defaultValue: "删除模板"),
                systemImageName: "trash",
                role: .destructive
            ) {
                sendQuickAction(.delete(id: snapshot.id))
            }
        )

        return TemplateCardContextMenuBridge.Configuration(
            headerTitle: title,
            actions: actions
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
        onShowToast: @escaping (String, String) -> Void = { _, _ in },
        onPresentError: @escaping (String, String) -> Void = { _, _ in },
        onOpenDetail: @escaping () -> Void,
        isHighlighted: Bool = false
    ) {
        self._prompt = Bindable(prompt)
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onClone = onClone
        self.onFilterByTag = onFilterByTag
        self.onLaunchToolboxApp = onLaunchToolboxApp
        self.toolboxApps = toolboxApps
        self.onShowToast = onShowToast
        self.onPresentError = onPresentError
        self.onOpenDetail = onOpenDetail
        self.isHighlighted = isHighlighted
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
                    .zIndex(1)
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
        .overlay(
            TemplateCardContextMenuBridge(configuration: contextMenuConfiguration)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .id(prompt.id)
        .confirmationDialog(
            String(localized: "confirmation_reset_parameters", defaultValue: "重置参数"),
            isPresented: Binding(
                get: { paramToReset != nil },
                set: { if !$0 { paramToReset = nil } }
            ),
            presenting: paramToReset
        ) { param in
            Button(String(localized: "reset_to_default", defaultValue: "重置为默认值"), role: .destructive) {
                resetParam(param)
            }
            Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) {
                paramToReset = nil
            }
        } message: { param in
            Text(String(format: String(localized: "reset_param_confirm", defaultValue: "确定要将参数 {%@} 重置为默认值吗？"), param.key))
        }
        .confirmationDialog(
            String(localized: "reset_all_params", defaultValue: "重置所有参数"),
            isPresented: $showResetAllConfirmation
        ) {
            Button(String(localized: "reset_all_params", defaultValue: "重置所有参数"), role: .destructive) {
                resetAllParams()
            }
            Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) {
                showResetAllConfirmation = false
            }
        } message: {
            Text(String(format: String(localized: "reset_all_params_confirm", defaultValue: "确定要将所有 %lld 个参数重置为默认值吗？此操作将覆盖所有当前值。"), prompt.params.count))
        }
        .confirmationDialog(
            String(localized: "delete_prompt", defaultValue: "删除模板"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete", defaultValue: "删除"), role: .destructive) {
                onDelete(prompt)
                showDeleteConfirmation = false
            }
            Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text(String(format: String(localized: "delete_template_confirm", defaultValue: "确定要删除「%@」吗？此操作不可撤销。"), prompt.title.isEmpty ? String(localized: "unnamed_template", defaultValue: "未命名模板") : prompt.title))
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
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "summary", defaultValue: "摘要"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text(prompt.title.isEmpty ? String(localized: "unnamed", defaultValue: "未命名") : prompt.title)
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
                    .help(prompt.pinned ? String(localized: "unpin") : String(localized: "pin"))

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
                    .help(String(localized: "view_more_settings", defaultValue: "查看更多设置"))

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
                    .help(String(localized: "quick_actions", defaultValue: "快捷操作"))
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
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(alignment: .trailing, spacing: isAgentContext ? 10 : 8) {
                    if isAgentContext {
                        HStack(alignment: .top, spacing: 6) {
                            agentFileActionColumn
                            copyActionColumn
                        }
                    } else {
                        copyActionColumn
                    }

                    if isAgentContext, hasAgentAttachments {
                        Text(String(format: String(localized: "linked_files_count", defaultValue: "关联文件：%lld 个"), orderedAttachments.count))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var parameterFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            if prompt.params.isEmpty {
                Text(String(localized: "no_params_copy_directly", defaultValue: "此模板暂无参数，直接复制即可"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center) {
                    Text(String(localized: "parameters", defaultValue: "参数"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showResetAllConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text(String(localized: "reset_all", defaultValue: "重置所有"))
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
                    .help(String(localized: "reset_all_params", defaultValue: "将所有参数重置为默认值"))
                }
                .padding(.bottom, 4)

                ForEach(prompt.params, id: \.persistentModelID) { paramModel in
                    let isMissing = isParamMissing(paramModel)
                    let focusTarget = ParamFocusTarget(id: paramModel.persistentModelID)
                    let useMultiline = resolvedShouldUseMultiline(for: paramModel)
                    let isFocused = focusedParam == focusTarget

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

                                    Text(String(localized: "multiline_input", defaultValue: "多行输入"))
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
                                    
                                    if isFocused {
                                        layoutToggleButton(for: paramModel, isMultiline: useMultiline)
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
                                    .help(String(localized: "reset_to_default", defaultValue: "重置为默认值"))
                                }

                                MacPlainTextEditor(
                                    text: binding(for: paramModel),
                                    font: .monospacedSystemFont(ofSize: 13, weight: .regular)
                                )
                                .frame(minHeight: 80, maxHeight: 140, alignment: .topLeading)
                                .padding(10)
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
                        syncOverrideWithLayout(for: paramModel)
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
                            .transition(.opacity)
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
                                .autocorrectionDisabled()
                                .onAppear {
                                    primeDraft(for: paramModel)
                                    restoreFocusIfNeeded(for: paramModel)
                                }
                                .onChange(of: focusedParam == focusTarget) { isFocused in
                                    if isFocused {
                                        primeDraft(for: paramModel)
                                        syncOverrideWithLayout(for: paramModel)
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

                                if isFocused {
                                    layoutToggleButton(for: paramModel, isMultiline: useMultiline)
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
                                .help(String(localized: "reset_to_default", defaultValue: "重置为默认值"))
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.12), value: useMultiline)
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
                    .help(isMarkdownPreview ? String(localized: "switch_to_plain_text", defaultValue: "切换到纯文本预览") : String(localized: "switch_to_markdown", defaultValue: "切换到 Markdown 预览"))
                }

                Spacer()
            }

            ScrollView {
                switch contentMode {
                case .template:
                    let trimmed = prompt.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        Text(String(localized: "empty_template_content", defaultValue: "模板内容为空"))
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
                            Text(String(localized: "empty_preview_content", defaultValue: "预览内容为空"))
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
        case let .overwriteAgentFiles(id):
            guard id == prompt.uuid else { return }
            overwriteAttachments()
        case let .syncAgentFromFile(id):
            guard id == prompt.uuid else { return }
            synchronizeFromPrimaryAttachment()
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
            print("Failed to save template: \(error)")
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

    private func resolvedShouldUseMultiline(for param: ParamKV) -> Bool {
        guard let override = paramLayoutOverrides[param.persistentModelID] else {
            return shouldUseMultilineInput(param)
        }
        return override == .multiline
    }

    private func cycleLayoutOverride(for param: ParamKV) {
        let id = param.persistentModelID
        let current = paramLayoutOverrides[id]
        let next: ParamInputLayoutOverride?
        if current == .multiline {
            next = .single
        } else {
            next = .multiline
        }

        if let override = next {
            paramLayoutOverrides[id] = override
        } else {
            paramLayoutOverrides.removeValue(forKey: id)
        }

        logParamEvent("layoutOverrideChanged", param: param, extra: "state=\(describeOverride(next))")
    }

    private func syncOverrideWithLayout(for param: ParamKV) {
        let id = param.persistentModelID
        // 如果已经手动覆盖，就保持用户选择
        guard paramLayoutOverrides[id] == nil else { return }
        let heuristicMultiline = shouldUseMultilineInput(param)
        if heuristicMultiline {
            paramLayoutOverrides[id] = .multiline
        } else {
            paramLayoutOverrides.removeValue(forKey: id)
        }
        logParamEvent("syncOverrideWithLayout", param: param, extra: "heuristic=\(heuristicMultiline)")
    }

    private func describeOverride(_ override: ParamInputLayoutOverride?) -> String {
        switch override {
        case .none:
            return "auto"
        case .some(.single):
            return "single"
        case .some(.multiline):
            return "multiline"
        }
    }
    
    private func layoutCandidateContent(for param: ParamKV) -> String {
        let id = param.persistentModelID
        let base = paramDrafts[id] ?? param.value
        if base.isEmpty {
            return param.defaultValue ?? ""
        }
        return base
    }

    @ViewBuilder
    private func layoutToggleButton(for param: ParamKV, isMultiline: Bool) -> some View {
        let id = param.persistentModelID
        let isHovered = hoveredLayoutParamID == id

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                cycleLayoutOverride(for: param)
            }
        } label: {
            Image(systemName: isMultiline ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appForeground.opacity(isHovered ? 0.9 : 0.7))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.cardSurface.opacity(isHovered ? 1.0 : 0.82))
                )
                .overlay(
                    Circle()
                        .stroke(Color.cardOutline.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(interactionAnimation) {
                hoveredLayoutParamID = hovering ? id : nil
            }
        }
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(interactionAnimation, value: isHovered)
        .help(isMultiline ? String(localized: "switch_to_single_line", defaultValue: "切换到单行模式") : String(localized: "switch_to_multiline", defaultValue: "切换到多行模式"))
    }

    private func draftValue(for param: ParamKV) -> String {
        let id = param.persistentModelID
        if let cached = paramDrafts[id] {
            return cached
        }
        // 如果当前值为空但有默认值，就使用默认值初始化
        let currentValue = param.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = currentValue.isEmpty ? (param.defaultValue ?? "") : param.value
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
            // 如果当前值为空但有默认值，就使用默认值初始化
            let currentValue = param.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let initial = currentValue.isEmpty ? (param.defaultValue ?? "") : param.value
            paramDrafts[id] = initial
            logParamEvent("primeDraft", param: param, extra: "length=\(initial.count)")
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

    private func finalizeAllParamDrafts(reason: String) {
        logDebug("finalizeAllParamDrafts(reason=\(reason)) start")
        let previousFocus = focusedParam
        focusedParam = nil

        for param in prompt.params {
            finalizeDraft(for: param)
        }

        if let previousFocus {
            logDebug("finalizeAllParamDrafts cleared focus id=\(previousFocus.id)")
        }

        logDebug("finalizeAllParamDrafts(reason=\(reason)) end")
    }

    private func copyFilledPrompt() {
        finalizeAllParamDrafts(reason: "copyFilledPrompt")
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
        finalizeAllParamDrafts(reason: "copyTemplateOnly")
        let template = prompt.body
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(template, forType: .string) {
            showCopiedHUDFeedback()
        } else {
            print("复制失败：无法写入剪贴板")
        }
    }

    private func overwriteAttachments() {
        guard isAgentContext else { return }
        guard hasAgentAttachments else {
            onPresentError("没有可覆写的文件", "请先在详情页关联需要同步的 Markdown 文件。")
            return
        }
        guard isPushingAgentAttachments == false else { return }

        isPushingAgentAttachments = true
        Task { @MainActor in
            defer { isPushingAgentAttachments = false }
            let results = AgentContextFileService.shared.overwrite(prompt.body, to: orderedAttachments)
            persistChange(reason: "agentOverwrite")
            let successCount = results.filter(\.isSuccess).count
            if successCount > 0 {
                onShowToast("已覆写 \(successCount) 个文件", "square.and.arrow.down")
            }
            if let failure = results.first(where: { $0.isSuccess == false }),
               let error = failure.error {
                onPresentError("覆写失败", error.localizedDescription)
            }
        }
    }

    private func synchronizeFromPrimaryAttachment() {
        guard isAgentContext else { return }
        guard let primary = primaryAttachment else {
            onPresentError("无法同步", "请先关联至少一个 Markdown 文件。")
            return
        }
        guard isPullingAgentAttachment == false else { return }

        isPullingAgentAttachment = true
        Task { @MainActor in
            defer { isPullingAgentAttachment = false }
            let result = AgentContextFileService.shared.pullContent(from: primary)
            if let error = result.error {
                persistChange(reason: "agentPullError")
                onPresentError("同步失败", error.localizedDescription)
                return
            }

            let newBody = result.content ?? ""
            if prompt.body != newBody {
                prompt.body = newBody
                refreshParamsFromTemplate()
                persistWithTimestampUpdate()
            } else {
                persistChange(reason: "agentPullNoChange")
            }
            onShowToast("已从「\(primary.displayName)」同步", "arrow.down.doc")
        }
    }

    private func refreshParamsFromTemplate() {
        let keys = TemplateEngine.placeholders(in: prompt.body)
        var existing = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0) })
        var ordered: [ParamKV] = []

        for key in keys {
            if let param = existing.removeValue(forKey: key) {
                ordered.append(param)
            } else {
                let created = ParamKV(key: key, value: "", owner: prompt)
                ordered.append(created)
            }
        }

        for removed in existing.values {
            modelContext.delete(removed)
        }

        prompt.params = ordered
        pendingSaveTasks.values.forEach { $0.cancel() }
        pendingSaveTasks.removeAll()
        paramDrafts.removeAll()
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
                Text(String(localized: "rename_summary_title", defaultValue: "更改摘要"))
                    .font(.title3.weight(.semibold))
                Text(String(localized: "rename_summary_description", defaultValue: "更新模板摘要会刷新最近修改时间。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField(String(localized: "unnamed_template", defaultValue: "未命名模板"), text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .autocorrectionDisabled()
                .onSubmit(onConfirm)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(String(localized: "cancel", defaultValue: "取消"), role: .cancel, action: onCancel)
                Button(String(localized: "save", defaultValue: "保存")) {
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
