//
//  TemplateCardContextMenuBridge.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/13.
//

import AppKit
import SwiftUI

struct TemplateCardContextMenuBridge: NSViewRepresentable {
    struct Configuration {
        enum ActionRole {
            case normal
            case destructive
        }

        struct Action {
            let title: String
            let systemImageName: String?
            let role: ActionRole
            let handler: () -> Void

            init(
                title: String,
                systemImageName: String? = nil,
                role: ActionRole = .normal,
                handler: @escaping () -> Void
            ) {
                self.title = title
                self.systemImageName = systemImageName
                self.role = role
                self.handler = handler
            }
        }

        let headerTitle: String
        let actions: [Action]

        init(headerTitle: String, actions: [Action]) {
            self.headerTitle = headerTitle
            self.actions = actions
        }
    }

    final class Coordinator {
        private var actionProxies: [MenuActionProxy] = []

        func buildMenu(configuration: Configuration) -> NSMenu {
            actionProxies.removeAll(keepingCapacity: true)

            let menu = NSMenu()
            menu.autoenablesItems = false

            if configuration.headerTitle.isEmpty == false {
                let headerItem = NSMenuItem(title: configuration.headerTitle, action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                headerItem.attributedTitle = NSAttributedString(
                    string: configuration.headerTitle,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                menu.addItem(headerItem)
                menu.addItem(.separator())
            }

            configuration.actions.forEach { action in
                let menuItem = NSMenuItem(
                    title: action.title,
                    action: #selector(MenuActionProxy.performAction(_:)),
                    keyEquivalent: ""
                )
                let proxy = MenuActionProxy(handler: action.handler)
                actionProxies.append(proxy)
                menuItem.target = proxy

                if let symbolName = action.systemImageName,
                   let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                    image.size = NSSize(width: 16, height: 16)
                    menuItem.image = image
                }

                // if action.role == .destructive {
                //     menuItem.attributedTitle = NSAttributedString(
                //         string: action.title,
                //         attributes: [
                //             .foregroundColor: NSColor.systemRed
                //         ]
                //     )
                // }

                menu.addItem(menuItem)
            }

            return menu
        }
    }

    private final class MenuActionProxy: NSObject {
        private let handler: () -> Void

        init(handler: @escaping () -> Void) {
            self.handler = handler
            super.init()
        }

        @objc func performAction(_ sender: Any?) {
            handler()
        }
    }

    final class HostingView: NSView {
        var makeMenu: (() -> NSMenu?)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else {
                return nil
            }

            switch event.type {
            case .rightMouseDown, .otherMouseDown where event.buttonNumber == 2:
                return self
            default:
                return nil
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            guard let menu = makeMenu?() else {
                super.rightMouseDown(with: event)
                return
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        override func otherMouseDown(with event: NSEvent) {
            if event.buttonNumber == 2 {
                rightMouseDown(with: event)
            } else {
                super.otherMouseDown(with: event)
            }
        }

        override var acceptsFirstResponder: Bool {
            false
        }
    }

    let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HostingView {
        let view = HostingView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.makeMenu = { [weak view, weak coordinator = context.coordinator] in
            guard view != nil, let coordinator else { return nil }
            return coordinator.buildMenu(configuration: configuration)
        }
        return view
    }

    func updateNSView(_ nsView: HostingView, context: Context) {
        nsView.makeMenu = { [configuration, weak coordinator = context.coordinator] in
            guard let coordinator else { return nil }
            return coordinator.buildMenu(configuration: configuration)
        }
    }
}
