//
//  PromptTransferError+Detail.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation

extension PromptTransferError {
    var detailedMessage: String {
        if let reason = failureReason, reason.isEmpty == false {
            return "\(localizedDescription)\n\(reason)"
        }
        return localizedDescription
    }
}
