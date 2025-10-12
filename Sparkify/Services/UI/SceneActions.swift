//
//  SceneActions.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import SwiftUI

struct FocusSearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct DeleteActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearchAction: (() -> Void)? {
        get { self[FocusSearchActionKey.self] }
        set { self[FocusSearchActionKey.self] = newValue }
    }

    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }

    var deleteAction: (() -> Void)? {
        get { self[DeleteActionKey.self] }
        set { self[DeleteActionKey.self] = newValue }
    }
}
