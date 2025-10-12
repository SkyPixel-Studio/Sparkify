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
    }
    
    // MARK: - Properties
    
    /// User's signature for version authorship. Defaults to system username if not set.
    var userSignature: String {
        didSet {
            UserDefaults.standard.set(userSignature, forKey: Keys.userSignature)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load signature from UserDefaults, or use system username as default
        if let saved = UserDefaults.standard.string(forKey: Keys.userSignature) {
            self.userSignature = saved
        } else {
            // Use system username as default
            self.userSignature = NSUserName()
        }
    }
    
    // MARK: - Methods
    
    /// Reset signature to system username
    func resetSignatureToDefault() {
        userSignature = NSUserName()
    }
}

