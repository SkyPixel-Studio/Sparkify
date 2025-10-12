//
//  PreferencesService.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation

/// Manages user preferences using UserDefaults
@Observable
final class PreferencesService {
    // MARK: - Singleton
    
    static let shared = PreferencesService()
    
    // MARK: - Keys
    
    private enum Keys {
        static let userSignature = "userSignature"
        static let enabledToolboxApps = "enabledToolboxApps"
        static let toolboxOrder = "toolboxOrder"
    }
    
    // MARK: - Properties
    
    /// User's signature for version authorship. Defaults to system username if not set.
    var userSignature: String {
        didSet {
            UserDefaults.standard.set(userSignature, forKey: Keys.userSignature)
        }
    }

    /// Enabled toolbox app identifiers. Defaults to all known apps.
    var enabledToolboxAppIDs: Set<String> {
        didSet {
            let list = Array(enabledToolboxAppIDs)
            UserDefaults.standard.set(list, forKey: Keys.enabledToolboxApps)
        }
    }

    var toolboxOrder: [String] {
        didSet {
            UserDefaults.standard.set(toolboxOrder, forKey: Keys.toolboxOrder)
        }
    }

    private let defaultToolboxIDs = Set(ToolboxApp.all.filter { $0.isEnabledByDefault }.map(\.id))
    private let knownToolboxIDs = Set(ToolboxApp.all.map(\.id))
    
    // MARK: - Initialization
    
    private init() {
        // Load signature from UserDefaults, or use system username as default
        if let saved = UserDefaults.standard.string(forKey: Keys.userSignature) {
            self.userSignature = saved
        } else {
            // Use system username as default
            self.userSignature = NSUserName()
        }

        let defaults = defaultToolboxIDs

        if let stored = UserDefaults.standard.array(forKey: Keys.enabledToolboxApps) as? [String] {
            let storedSet = Set(stored)
            let normalized = storedSet.intersection(knownToolboxIDs)
            self.enabledToolboxAppIDs = normalized.isEmpty ? defaults : normalized
        } else {
            self.enabledToolboxAppIDs = defaults
        }

        if let storedOrder = UserDefaults.standard.array(forKey: Keys.toolboxOrder) as? [String] {
            self.toolboxOrder = Self.normalizeToolboxOrder(storedOrder)
        } else {
            self.toolboxOrder = Self.normalizeToolboxOrder(ToolboxApp.defaultOrder)
        }
    }
    
    // MARK: - Methods
    
    /// Reset signature to system username
    func resetSignatureToDefault() {
        userSignature = NSUserName()
    }

    func isToolEnabled(_ app: ToolboxApp) -> Bool {
        enabledToolboxAppIDs.contains(app.id)
    }

    func setTool(_ app: ToolboxApp, enabled: Bool) {
        if enabled {
            enabledToolboxAppIDs.insert(app.id)
        } else {
            enabledToolboxAppIDs.remove(app.id)
        }
    }

    func moveToolboxAppUp(at index: Int) {
        guard index > 0, toolboxOrder.indices.contains(index) else { return }
        var current = toolboxOrder
        let item = current.remove(at: index)
        current.insert(item, at: index - 1)
        toolboxOrder = Self.normalizeToolboxOrder(current)
    }

    func moveToolboxAppDown(at index: Int) {
        guard toolboxOrder.indices.contains(index), index < toolboxOrder.count - 1 else { return }
        var current = toolboxOrder
        let item = current.remove(at: index)
        current.insert(item, at: index + 1)
        toolboxOrder = Self.normalizeToolboxOrder(current)
    }

    private static func normalizeToolboxOrder(_ proposed: [String]) -> [String] {
        let known = ToolboxApp.defaultOrder
        var seen = Set<String>()
        var result: [String] = []

        for id in proposed where known.contains(id) && seen.contains(id) == false {
            result.append(id)
            seen.insert(id)
        }

        for id in known where seen.contains(id) == false {
            result.append(id)
            seen.insert(id)
        }

        return result
    }
}
