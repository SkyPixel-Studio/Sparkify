//
//  OperationToastView.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

struct OperationToastView: View {
    let toast: OperationToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.iconSystemName)
                .font(.system(size: 14, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.neutralHigh.opacity(0.92))
        )
        .foregroundStyle(Color.invertedForeground)
        .shadow(color: Color.shadowStrong, radius: 14, y: 8)
    }
}
