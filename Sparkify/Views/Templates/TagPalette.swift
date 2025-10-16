//
//  TagPalette.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct TagStyle {
    let background: Color
    let foreground: Color
}

enum TagPalette {
    private static let styles: [TagStyle] = [
        TagStyle(background: Color(red: 0.96, green: 0.99, blue: 0.76), foreground: Color(red: 0.24, green: 0.28, blue: 0.04)),
        TagStyle(background: Color(red: 0.93, green: 0.97, blue: 1.0), foreground: Color(red: 0.18, green: 0.32, blue: 0.46)),
        TagStyle(background: Color(red: 1.0, green: 0.92, blue: 0.94), foreground: Color(red: 0.54, green: 0.18, blue: 0.26)),
        TagStyle(background: Color(red: 0.95, green: 0.92, blue: 1.0), foreground: Color(red: 0.33, green: 0.26, blue: 0.64)),
        TagStyle(background: Color(red: 0.92, green: 1.0, blue: 0.95), foreground: Color(red: 0.1, green: 0.36, blue: 0.23)),
        TagStyle(background: Color(red: 1.0, green: 0.95, blue: 0.88), foreground: Color(red: 0.47, green: 0.3, blue: 0.12))
    ]

    static func style(for tag: String) -> TagStyle {
        guard styles.isEmpty == false else {
            return TagStyle(background: Color.neonYellow.opacity(0.3), foreground: .black)
        }
        // Use stable hash based on UTF-8 bytes to ensure consistent colors across app launches
        let hash = tag.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7FFFFFFF }
        let index = hash % styles.count
        return styles[index]
    }
}
