//
//  OperationToast.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import Foundation

struct OperationToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let iconSystemName: String
}
