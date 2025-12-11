//
//  AppLogoView.swift
//  Philia
//
//  App Logo 图片组件
//

import SwiftUI

struct AppLogoView: View {
    let size: CGFloat
    var isCircle: Bool = false
    var showGloss: Bool = false  // iOS 26 style glossy overlay

    private var logoImage: UIImage? {
        if let path = Bundle.main.path(forResource: "AppLogo", ofType: "png"),
           let uiImage = UIImage(contentsOfFile: path) {
            return uiImage
        }
        return UIImage(named: "AppLogo")
    }

    private var cornerRadius: CGFloat {
        isCircle ? size / 2 : size * 0.2
    }

    var body: some View {
        Group {
            if let uiImage = logoImage {
                if isCircle {
                    // 圆形：需要裁剪和边框
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.6),
                                            Color.pink.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .shadow(color: Color.purple.opacity(0.4), radius: 3, x: 0, y: 0)
                        )
                } else if showGloss {
                    // iOS 26 风格：圆角 + 半透明蒙层
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            ZStack {
                                // 顶部高光（iOS 经典 gloss）
                                Ellipse()
                                    .fill(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(0.5), location: 0),
                                                .init(color: Color.white.opacity(0.2), location: 0.5),
                                                .init(color: Color.clear, location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: size * 1.2, height: size * 0.5)
                                    .offset(y: -size * 0.3)
                                    .blur(radius: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        )
                } else {
                    // 方形：图片本身已有圆角，直接显示
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            } else {
                // Placeholder：需要 clipShape 和 overlay
                (isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: size * 0.2)))
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Text("P")
                            .font(.system(size: size * 0.5, weight: .bold))
                            .foregroundColor(.purple)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Group {
                            if isCircle {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.purple.opacity(0.6),
                                                Color.pink.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                                    .shadow(color: Color.purple.opacity(0.4), radius: 3, x: 0, y: 0)
                            } else {
                                RoundedRectangle(cornerRadius: size * 0.2)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.purple.opacity(0.6),
                                                Color.pink.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        }
                    )
            }
        }
        .contentShape(Rectangle())
    }
}

// 用于在运行时切换 Shape 类型
struct AnyShape: Shape, @unchecked Sendable {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        let shapeCopy = shape
        pathBuilder = { rect in
            shapeCopy.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

#Preview {
    AppLogoView(size: 64)
}
