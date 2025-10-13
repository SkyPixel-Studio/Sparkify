import Foundation
import SwiftUI
import AppKit

struct TemplateQuickActionMenu: View {
    let prompt: PromptItem
    let onOpenDetail: () -> Void
    let onTogglePin: () -> Void
    let onClone: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onResetAllParams: () -> Void
    let onFilterByTag: (String) -> Void
    let toolboxApps: [ToolboxApp]
    let onLaunchToolboxApp: (ToolboxApp) -> Void

    var body: some View {
        Section("快捷操作") {
            Button(action: onOpenDetail) {
                Label("编辑模板", systemImage: "rectangle.and.pencil.and.ellipsis")
            }

            Button(action: onTogglePin) {
                Label(prompt.pinned ? "取消置顶" : "置顶此模板", systemImage: "pin")
            }

            Button(action: onRename) {
                Label("更改摘要…", systemImage: "text.badge.star")
            }

            Button(action: onClone) {
                Label("克隆模板", systemImage: "doc.on.doc")
            }

            Button(action: onResetAllParams) {
                Label("重置所有参数", systemImage: "arrow.counterclockwise.circle")
            }

            Button(role: .destructive, action: onDelete) {
                Label("删除模板", systemImage: "trash")
            }
            .tint(.red)
        }

        Section("时间信息") {
            disabledInfoRow(text: "创建于 \(Self.formattedAbsoluteDate(prompt.createdAt))")
            disabledInfoRow(text: "最近更新 \(Self.formattedAbsoluteDate(prompt.updatedAt))")
        }

        if prompt.tags.isEmpty == false {
            Section("快捷筛选") {
                ForEach(prompt.tags, id: \.self) { tag in
                    Button {
                        onFilterByTag(tag)
                    } label: {
                        Text("显示同标签「\(tag)」的其他模板")
                    }
                }
            }
        }

        if toolboxApps.isEmpty == false {
            Section("Toolbox") {
                Text("复制后打开 Toolbox")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ForEach(toolboxApps) { app in
                    Button {
                        onLaunchToolboxApp(app)
                    } label: {
                        Label(app.displayName, systemImage: Self.iconName(for: app))
                    }
                }
            }
        }
    }

    private func disabledInfoRow(text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
    }

    static func iconName(for app: ToolboxApp) -> String {
        switch app.optionKind {
        case .nativeApp:
            return "sparkle.magnifyingglass"
        case .web:
            return "globe"
        }
    }

    static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static func formattedAbsoluteDate(_ date: Date) -> String {
        absoluteFormatter.string(from: date)
    }
}

extension TemplateQuickActionMenu {
    static func makeNativeMenu(
        prompt: PromptItem,
        onOpenDetail: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onClone: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onResetAllParams: @escaping () -> Void,
        onFilterByTag: @escaping (String) -> Void,
        toolboxApps: [ToolboxApp],
        onLaunchToolboxApp: @escaping (ToolboxApp) -> Void
    ) -> NSMenu {
        let menu = NSMenu(title: "快捷操作")
        menu.autoenablesItems = false

        menu.addItem(ClosureMenuItem(title: "编辑模板", action: onOpenDetail))
        menu.addItem(ClosureMenuItem(title: prompt.pinned ? "取消置顶" : "置顶此模板", action: onTogglePin))
        menu.addItem(ClosureMenuItem(title: "更改摘要…", action: onRename))
        menu.addItem(ClosureMenuItem(title: "克隆模板", action: onClone))
        menu.addItem(ClosureMenuItem(title: "重置所有参数", action: onResetAllParams))

        let deleteItem = ClosureMenuItem(title: "删除模板", action: onDelete)
        deleteItem.attributedTitle = NSAttributedString(
            string: deleteItem.title,
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        menu.addItem(deleteItem)

        menu.addItem(.separator())

        let createdText = "创建于 \(formattedAbsoluteDate(prompt.createdAt))"
        let updatedText = "最近更新 \(formattedAbsoluteDate(prompt.updatedAt))"
        menu.addItem(ClosureMenuItem(infoText: createdText))
        menu.addItem(ClosureMenuItem(infoText: updatedText))

        if prompt.tags.isEmpty == false {
            menu.addItem(.separator())
            for tag in prompt.tags {
                menu.addItem(ClosureMenuItem(title: "显示同标签「\(tag)」的其他模板") {
                    onFilterByTag(tag)
                })
            }
        }

        if toolboxApps.isEmpty == false {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(infoText: "复制后打开 Toolbox"))
            for app in toolboxApps {
                let appItem = ClosureMenuItem(title: app.displayName) {
                    onLaunchToolboxApp(app)
                }
                appItem.image = NSImage(systemSymbolName: iconName(for: app), accessibilityDescription: nil)
                menu.addItem(appItem)
            }
        }

        return menu
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: (() -> Void)?

    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }

    init(infoText: String) {
        handler = nil
        super.init(title: infoText, action: nil, keyEquivalent: "")
        isEnabled = false
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler?()
    }
}
