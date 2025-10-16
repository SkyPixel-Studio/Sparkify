//
//  CopiedHUDView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct CopiedHUDView: View {
    var body: some View {
        Label("已复制", systemImage: "checkmark.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }
}
