//
//  AppDelegate.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/29.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置所有现有窗口
        configureExistingWindows()
        
        // 监听新窗口
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            Task { @MainActor in
                WindowPersistenceController.shared.configureIfNeeded(for: window)
            }
        }
    }
    
    private func configureExistingWindows() {
        for window in NSApplication.shared.windows {
            WindowPersistenceController.shared.configureIfNeeded(for: window)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
