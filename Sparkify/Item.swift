//
//  Item.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
