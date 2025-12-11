//
//  Font+Brand.swift
//  Philia
//
//  Custom font extension for brand typography
//

import SwiftUI

extension Font {
    /// Brand font for "Philia" text - Norican Regular
    static func brand(size: CGFloat) -> Font {
        .custom("Norican-Regular", size: size)
    }
}

// Preview helper to verify font is loaded correctly
#Preview {
    VStack(spacing: 20) {
        Text("Philia")
            .font(.brand(size: 32))

        Text("Philia")
            .font(.brand(size: 24))

        Text("Philia")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
}
