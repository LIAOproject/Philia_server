//
//  CachedAsyncImage.swift
//  Philia
//
//  Async image with local caching (stale-while-revalidate)
//  Shows cached image immediately, refreshes from network in background
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }

    private func loadImage() {
        guard let urlString = url, !urlString.isEmpty else {
            image = nil
            return
        }

        let cache = ImageCache.shared

        // 1. Show cached image immediately (if available)
        if let cachedImage = cache.getCachedImage(for: urlString) {
            image = cachedImage
        } else {
            isLoading = true
        }

        // 2. Always fetch from network in background to update cache
        Task {
            if let newImage = await cache.fetchAndCache(url: urlString) {
                await MainActor.run {
                    // Only update if image changed or wasn't cached
                    if image == nil || image != newImage {
                        image = newImage
                    }
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}

// MARK: - Simple Cached Image View

/// A simple cached image view with common defaults
struct SimpleCachedImage: View {
    let url: String?
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 0
    var isCircle: Bool = false
    var placeholderIcon: String = "photo"

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .if(isCircle) { view in
                    view.clipShape(Circle())
                }
                .if(!isCircle && cornerRadius > 0) { view in
                    view.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .if(!isCircle && cornerRadius == 0) { view in
                    view.clipped()
                }
        } placeholder: {
            Group {
                if isCircle {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: placeholderIcon)
                                .foregroundColor(.secondary)
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: placeholderIcon)
                                .foregroundColor(.secondary)
                        )
                }
            }
        }
    }
}

// MARK: - View Extension for Conditional Modifier

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SimpleCachedImage(
            url: "https://api.dicebear.com/7.x/micah/png?seed=Test&size=128",
            size: 80,
            isCircle: true,
            placeholderIcon: "person.crop.circle.fill"
        )

        SimpleCachedImage(
            url: "https://api.dicebear.com/7.x/micah/png?seed=Test2&size=128",
            size: 100,
            cornerRadius: 12,
            placeholderIcon: "photo"
        )
    }
}
