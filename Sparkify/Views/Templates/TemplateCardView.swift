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

    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: PromptItem

    let onOpenDetail: () -> Void

    @State private var showCopiedHUD = false
    @State private var isMarkdownPreview = false
    @State private var contentMode: CardContentMode = .template
    @FocusState private var focusedParam: ParamFocusTarget?
    @State private var paramToReset: ParamKV?
    @State private var showResetAllConfirmation = false

    private var renderResult: TemplateEngine.RenderResult {
        let values = Dictionary(uniqueKeysWithValues: prompt.params.map { ($0.key, $0.resolvedValue) })
        return TemplateEngine.render(template: prompt.body, values: values)
    }

    private func isParamMissing(_ param: ParamKV) -> Bool {
        param.isEffectivelyEmpty
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
            Text("确定要将 {\(param.key)} 重置为默认值吗？\n当前值：\(param.value.isEmpty ? "（空）" : param.value)\n默认值：\(param.defaultValue?.isEmpty == false ? param.defaultValue! : "（空）")")
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text(prompt.title.isEmpty ? "未命名摘要" : prompt.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appForeground.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                HStack(spacing: 10) {
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
                            .background(Capsule().fill(Color.black))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
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
                        .foregroundStyle(Color.appForeground.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.cardSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.cardOutline.opacity(0.8), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("将所有参数重置为默认值")
                }
                .padding(.bottom, 4)

                ForEach(prompt.params, id: \.persistentModelID) { paramModel in
                    let isMissing = isParamMissing(paramModel)
                    HStack(spacing: 10) {
                        Text("\(paramModel.key)=")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.neonYellow.opacity(0.4)))
                            .foregroundStyle(Color.black)

                        TextField("{\(paramModel.key)}", text: Binding(
                            get: { paramModel.value },
                            set: { newValue in
                                paramModel.value = newValue
                                persistChange()
                            }
                        ), prompt: (paramModel.defaultValue ?? "").isEmpty ? nil : Text(paramModel.defaultValue ?? ""))
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
                        .focused($focusedParam, equals: ParamFocusTarget(id: paramModel.persistentModelID))
                        .font(.system(size: 13, weight: .regular, design: .monospaced))

                        Button {
                            paramToReset = paramModel
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.appForeground.opacity(0.6))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.cardSurface))
                                .overlay(Circle().stroke(Color.cardOutline.opacity(0.8), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("重置为默认值")
                    }
                    .padding(.horizontal, 4)
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
            param.value = param.defaultValue ?? ""
            persistChange()
            paramToReset = nil
        }
    }

    private func resetAllParams() {
        withAnimation {
            for param in prompt.params {
                param.value = param.defaultValue ?? ""
            }
            persistChange()
            showResetAllConfirmation = false
        }
    }
}
