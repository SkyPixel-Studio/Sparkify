//
//  OperationToast.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation

struct OperationToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let iconSystemName: String
}
