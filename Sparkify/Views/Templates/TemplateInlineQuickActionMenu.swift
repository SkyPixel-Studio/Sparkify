import Foundation
import SwiftUI

struct TemplateInlineQuickActionMenu: View {
    struct ToolboxAppLite: Identifiable, Hashable {
        let id: String
        let displayName: String
        let kind: ToolboxApp.OptionKind
    }

    struct Snapshot: Hashable {
        let id: String
        let isPinned: Bool
        let createdAt: Date
        let updatedAt: Date
        let tags: [String]
        let toolboxApps: [ToolboxAppLite]
        let kind: PromptItem.Kind

        init(
            id: String,
            isPinned: Bool,
            createdAt: Date,
            updatedAt: Date,
            tags: [String],
            toolboxApps: [ToolboxAppLite],
            kind: PromptItem.Kind
        ) {
            self.id = id
            self.isPinned = isPinned
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.tags = Array(tags)
            self.toolboxApps = toolboxApps
            self.kind = kind
        }
    }

    enum QuickAction: Hashable {
        case openDetail(id: String)
        case copyFilledPrompt(id: String)
        case copyTemplateOnly(id: String)
        case overwriteAgentFiles(id: String)
        case syncAgentFromFile(id: String)
        case togglePin(id: String)
        case rename(id: String)
        case clone(id: String)
        case resetAllParams(id: String)
        case delete(id: String)
        case filterByTag(id: String, tag: String)
        case launchToolboxApp(id: String, appID: String)
    }

    private struct ActionItem: Identifiable {
        let id: String
        let action: QuickAction
        let title: String
        let systemImage: String?
        let role: ButtonRole?

        init(action: QuickAction, title: String, systemImage: String? = nil, role: ButtonRole? = nil) {
            self.action = action
            self.title = title
            self.systemImage = systemImage
            self.role = role
            self.id = ActionItem.makeID(for: action)
        }

        private static func makeID(for action: QuickAction) -> String {
            switch action {
            case let .openDetail(id): return "openDetail-\(id)"
            case let .copyFilledPrompt(id): return "copyFilled-\(id)"
            case let .copyTemplateOnly(id): return "copyTemplate-\(id)"
            case let .overwriteAgentFiles(id): return "overwriteAgent-\(id)"
            case let .syncAgentFromFile(id): return "syncAgent-\(id)"
            case let .togglePin(id): return "togglePin-\(id)"
            case let .rename(id): return "rename-\(id)"
            case let .clone(id): return "clone-\(id)"
            case let .resetAllParams(id): return "resetAll-\(id)"
            case let .delete(id): return "delete-\(id)"
            case let .filterByTag(id, tag): return "filterTag-\(id)-\(tag)"
            case let .launchToolboxApp(id, appID): return "launchToolbox-\(id)-\(appID)"
            }
        }
    }

    private struct InfoItem: Identifiable {
        let id: String
        let text: String
    }

    let snapshot: Snapshot
    let onAction: (QuickAction) -> Void

    var body: some View {
        Section("快捷操作") {
            ForEach(primaryItems) { item in
                actionButton(for: item)
            }
        }

        Section("时间信息") {
            ForEach(infoItems) { info in
                infoRow(info)
            }
        }

        if snapshot.tags.isEmpty == false {
            Menu("快捷筛选") {
                ForEach(tagItems) { item in
                    actionButton(for: item)
                }
            }
        }

        if snapshot.toolboxApps.isEmpty == false {
            Menu("复制并打开Toolbox") {
                ForEach(toolboxItems) { item in
                    actionButton(for: item)
                }
            }
        }
    }

    private var primaryItems: [ActionItem] {
        var actions: [ActionItem] = [
            ActionItem(action: .openDetail(id: snapshot.id), title: "编辑模板", systemImage: "rectangle.and.pencil.and.ellipsis"),
            ActionItem(action: .copyFilledPrompt(id: snapshot.id), title: "复制", systemImage: "square.and.pencil"),
            ActionItem(action: .copyTemplateOnly(id: snapshot.id), title: "仅复制模板", systemImage: "doc.on.doc"),
            ActionItem(action: .togglePin(id: snapshot.id), title: snapshot.isPinned ? "取消置顶" : "置顶此模板", systemImage: "pin"),
            ActionItem(action: .rename(id: snapshot.id), title: "更改摘要…", systemImage: "text.badge.star"),
            ActionItem(action: .clone(id: snapshot.id), title: "克隆模板", systemImage: "doc.on.doc"),
            ActionItem(action: .resetAllParams(id: snapshot.id), title: "重置所有参数", systemImage: "arrow.counterclockwise.circle"),
            ActionItem(action: .delete(id: snapshot.id), title: "删除模板", systemImage: "trash", role: .destructive)
        ]
        if snapshot.kind == .agentContext {
            actions.insert(
                ActionItem(action: .overwriteAgentFiles(id: snapshot.id), title: "覆写到文件", systemImage: "square.and.arrow.down"),
                at: 3
            )
            actions.insert(
                ActionItem(action: .syncAgentFromFile(id: snapshot.id), title: "与文件同步", systemImage: "arrow.down.doc"),
                at: 4
            )
        }
        return actions
    }

    private var tagItems: [ActionItem] {
        snapshot.tags.map { tag in
            ActionItem(
                action: .filterByTag(id: snapshot.id, tag: tag),
                title: "显示同标签「\(tag)」的其他模板"
            )
        }
    }

    private var toolboxItems: [ActionItem] {
        snapshot.toolboxApps.map { app in
            ActionItem(
                action: .launchToolboxApp(id: snapshot.id, appID: app.id),
                title: app.displayName,
                systemImage: Self.iconName(for: app.kind)
            )
        }
    }

    private var infoItems: [InfoItem] {
        [
            InfoItem(id: "created-\(snapshot.id)", text: "创建于 \(Self.formattedAbsoluteDate(snapshot.createdAt))"),
            InfoItem(id: "updated-\(snapshot.id)", text: "最近更新 \(Self.formattedAbsoluteDate(snapshot.updatedAt))")
        ]
    }

    private func actionButton(for item: ActionItem) -> some View {
        Button(role: item.role) {
            onAction(item.action)
        } label: {
            if let systemImage = item.systemImage {
                Label(item.title, systemImage: systemImage)
            } else {
                Text(item.title)
            }
        }
    }

    private func infoRow(_ info: InfoItem) -> some View {
        Text(info.text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    static func iconName(for kind: ToolboxApp.OptionKind) -> String {
        switch kind {
        case .nativeApp:
            return "sparkle.magnifyingglass"
        case .web:
            return "globe"
        }
    }

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static func formattedAbsoluteDate(_ date: Date) -> String {
        absoluteFormatter.string(from: date)
    }
}
