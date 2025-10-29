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
        guard window.frameAutosaveName != autosaveName else { return }
        window.setFrameAutosaveName(autosaveName)
        window.isRestorable = true
    }
}
