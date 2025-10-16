//
//  DoubleShiftToSearch.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/15.
//

import SwiftUI
import AppKit

/// A view that monitors double-shift key presses to trigger search focus.
/// Only works on macOS and uses local event monitoring to avoid global key capture.
struct DoubleShiftToSearch: NSViewRepresentable {
    let action: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ view: NSView, context: Context) {}
    
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }
    
    final class Coordinator {
        private var monitor: Any?
        private var lastShiftTime: CFTimeInterval = 0
        private let threshold: CFTimeInterval = 0.35  // Double-tap window in seconds
        private let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        func start() {
            // Use local monitor to only capture events within this app
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                guard let self else { return event }
                
                let isShiftDown = event.modifierFlags.contains(.shift)
                let hasOtherMods = !event.modifierFlags.intersection([.command, .option, .control]).isEmpty
                let isShiftOnly = isShiftDown && !hasOtherMods
                
                // Left Shift: keyCode 56, Right Shift: keyCode 60
                if isShiftOnly && (event.keyCode == 56 || event.keyCode == 60) {
                    let now = CACurrentMediaTime()
                    
                    if now - lastShiftTime < threshold {
                        // Detected double-shift
                        DispatchQueue.main.async {
                            self.action()
                        }
                        lastShiftTime = 0  // Reset to prevent triple-tap triggering
                    } else {
                        lastShiftTime = now
                    }
                }
                
                return event
            }
        }
        
        func stop() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

