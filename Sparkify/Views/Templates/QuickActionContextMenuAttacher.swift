import SwiftUI
import AppKit

struct QuickActionContextMenuAttacher: NSViewRepresentable {
    typealias MenuBuilder = () -> NSMenu

    let menuBuilder: MenuBuilder

    func makeCoordinator() -> Coordinator {
        Coordinator(menuBuilder: menuBuilder)
    }

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        context.coordinator.update(menuBuilder: menuBuilder)
        nsView.coordinator = context.coordinator
        context.coordinator.reattach(from: nsView)
    }

    final class AttachmentView: NSView {
        weak var coordinator: Coordinator? {
            didSet {
                guard oldValue !== coordinator else { return }
                coordinator?.reattach(from: self)
            }
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            isHidden = true
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            coordinator?.reattach(from: self)
        }
    }

    final class Coordinator: NSObject {
        private var menuBuilder: MenuBuilder
        private weak var hostingView: NSView?
        private var rightClickRecognizer: NSClickGestureRecognizer?

        init(menuBuilder: @escaping MenuBuilder) {
            self.menuBuilder = menuBuilder
        }

        func reattach(from attachmentView: AttachmentView?) {
            guard let attachmentView else {
                attach(to: nil)
                return
            }

            let resolvedHost = resolveHost(for: attachmentView)
            attach(to: resolvedHost)
        }

        func update(menuBuilder: @escaping MenuBuilder) {
            self.menuBuilder = menuBuilder
            refreshMenu()
        }

        private func attach(to host: NSView?) {
            guard let host else {
                detach()
                return
            }

            if hostingView === host {
                refreshMenu()
                return
            }

            detach()
            hostingView = host
            installRightClickRecognizer(on: host)
            refreshMenu()
        }

        private func resolveHost(for attachmentView: AttachmentView) -> NSView? {
            var candidate: NSView? = attachmentView.superview
            var fallback = candidate

            while let current = candidate {
                if shouldSkipForAttachment(current) {
                    candidate = current.superview
                    continue
                }
                return current
            }

            return fallback
        }

        private func shouldSkipForAttachment(_ view: NSView) -> Bool {
            let className = NSStringFromClass(type(of: view))
            return className.contains("BackgroundHostingView")
                || className.contains("OverlayHostingView")
                || className.contains("VisualEffectView")
        }

        private func refreshMenu() {
            guard let host = hostingView else { return }
            host.menu = menuBuilder()
        }

        private func detach() {
            if let recognizer = rightClickRecognizer, let host = hostingView {
                host.removeGestureRecognizer(recognizer)
            }
            rightClickRecognizer = nil
            hostingView?.menu = nil
            hostingView = nil
        }

        private func installRightClickRecognizer(on host: NSView) {
            if let recognizer = rightClickRecognizer {
                host.removeGestureRecognizer(recognizer)
            }

            let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
            recognizer.buttonMask = 0x2
            recognizer.numberOfClicksRequired = 1
            recognizer.delaysPrimaryMouseButtonEvents = false
            host.addGestureRecognizer(recognizer)
            rightClickRecognizer = recognizer
        }

        @objc private func handleRightClick(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended, let host = hostingView else {
                return
            }

            let location = recognizer.location(in: host)
            let menu = menuBuilder()
            menu.popUp(positioning: nil, at: location, in: host)
        }

        deinit {
            detach()
        }
    }
}

struct NativeMenuButton: NSViewRepresentable {
    private let menuBuilder: () -> NSMenu

    init(
        prompt: PromptItem,
        toolboxApps: [ToolboxApp],
        onOpenDetail: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onClone: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onResetAllParams: @escaping () -> Void,
        onFilterByTag: @escaping (String) -> Void,
        onLaunchToolboxApp: @escaping (ToolboxApp) -> Void
    ) {
        self.menuBuilder = {
            TemplateQuickActionMenu.makeNativeMenu(
                prompt: prompt,
                onOpenDetail: onOpenDetail,
                onTogglePin: onTogglePin,
                onClone: onClone,
                onDelete: onDelete,
                onRename: onRename,
                onResetAllParams: onResetAllParams,
                onFilterByTag: onFilterByTag,
                toolboxApps: toolboxApps,
                onLaunchToolboxApp: onLaunchToolboxApp
            )
        }
    }

    func makeNSView(context: Context) -> MenuButtonHostView {
        let view = MenuButtonHostView(frame: .init(origin: .zero, size: .init(width: 40, height: 40)))
        view.menuBuilder = menuBuilder
        return view
    }

    func updateNSView(_ nsView: MenuButtonHostView, context: Context) {
        nsView.menuBuilder = menuBuilder
    }

    static func dismantleNSView(_ nsView: MenuButtonHostView, coordinator: ()) {
        nsView.menuBuilder = nil
    }
}

final class MenuButtonHostView: NSView {
    var menuBuilder: (() -> NSMenu)?

    override func mouseDown(with event: NSEvent) {
        guard let menu = menuBuilder?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
