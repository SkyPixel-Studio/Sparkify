//
//  PromptListFilter.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
//

import Foundation

enum PromptListFilter: Equatable {
    case all
    case pinned
    case tag(String)

    var analyticsName: String {
        switch self {
        case .all:
            return "all"
        case .pinned:
            return "pinned"
        case let .tag(tag):
            return "tag_\(tag)"
        }
    }
}
