//
//  LoadingView.swift
//  Philia
//
//  Loading indicator component
//

import SwiftUI

struct LoadingView: View {
    var message: String = "加载中..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingView(message: "加载对象中...")
}
