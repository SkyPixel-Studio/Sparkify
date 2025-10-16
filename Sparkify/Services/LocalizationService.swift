//
//  LocalizationService.swift
//  Sparkify
//
//  Manages app language preferences and localization
//

import Foundation
import SwiftUI

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "system_default", defaultValue: "跟随系统")
        case .zhHans:
            return String(localized: "simplified_chinese", defaultValue: "简体中文")
        case .en:
            return String(localized: "english", defaultValue: "English")
        }
    }
    
    /// Get the language code for UserDefaults AppleLanguages
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}

/// Service to manage app localization settings
@Observable
final class LocalizationService {
    // MARK: - Singleton
    
    static let shared = LocalizationService()
    
    // MARK: - Keys
    
    private enum Keys {
        static let appLanguage = "appLanguage"
    }
    
    // MARK: - Properties
    
    /// Current app language setting
    var currentLanguage: AppLanguage {
        didSet {
            guard currentLanguage != oldValue else { return }
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Keys.appLanguage)
            applyLanguage(currentLanguage)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved language preference
        if let savedRaw = UserDefaults.standard.string(forKey: Keys.appLanguage),
           let saved = AppLanguage(rawValue: savedRaw) {
            self.currentLanguage = saved
        } else {
            self.currentLanguage = .system
        }
        
        // Apply the language on init
        applyLanguage(currentLanguage)
    }
    
    // MARK: - Methods
    
    /// Apply the selected language by modifying UserDefaults AppleLanguages
    private func applyLanguage(_ language: AppLanguage) {
        if let code = language.languageCode {
            // Set specific language
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            // Remove override to follow system
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Check if changing language requires app restart
    var requiresRestart: Bool {
        // Language changes via AppleLanguages typically require app restart
        return true
    }
}

