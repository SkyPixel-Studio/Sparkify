//
//  OperationToastView.swift
//  Sparkify
//
//  Created by Assistant on 2025/10/12.
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
                .fill(Color.black.opacity(0.92))
        )
        .foregroundStyle(Color.white)
        .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
    }
}
