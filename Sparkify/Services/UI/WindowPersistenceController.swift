//
//  WindowPersistenceController.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/29.
//

import AppKit

@MainActor
final class WindowPersistenceController: NSObject {
    static let shared = WindowPersistenceController()

    private let autosaveName = "SparkifyMainWindow"

    func configureIfNeeded(for window: NSWindow) {
        guard shouldManageWindow(window) else { return }

        if window.identifier != autosaveIdentifier {
            window.identifier = autosaveIdentifier
        }

        let hasPersistedFrame = isFramePersisted()
        if window.frameAutosaveName != autosaveName {
            window.setFrameAutosaveName(autosaveName)
        }

        window.isRestorable = true

        if hasPersistedFrame == false {
            applyDefaultSize(to: window)
        }
    }

    private lazy var autosaveIdentifier = NSUserInterfaceItemIdentifier(autosaveName)
    private let defaultWindowSize = NSSize(width: 1760, height: 760)

    private func shouldManageWindow(_ window: NSWindow) -> Bool {
        if window is NSPanel {
            return false
        }

        if window.level != .normal {
            return false
        }

        return true
    }

    private func isFramePersisted() -> Bool {
        UserDefaults.standard.string(forKey: autosaveDefaultsKey) != nil
    }

    private func applyDefaultSize(to window: NSWindow) {
        guard window.styleMask.contains(.resizable) else { return }
        window.setContentSize(defaultWindowSize)
        window.center()
    }

    private var autosaveDefaultsKey: String {
        "NSWindow Frame \(autosaveName)"
    }
}
