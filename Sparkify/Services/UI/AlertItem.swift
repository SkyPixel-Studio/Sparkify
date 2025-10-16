//
//  AlertItem.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import Foundation

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
