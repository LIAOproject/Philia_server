//
//  AsyncImageView.swift
//  Philia
//
//  Async image loading with caching (stale-while-revalidate)
//  Shows cached image immediately, refreshes from network in background
//

import SwiftUI

struct AsyncImageView: View {
    let url: String?
    var placeholder: String = "person.crop.circle.fill"
    var size: CGFloat = 44
    var targetId: UUID? = nil  // Optional: for checking local avatar cache

    @StateObject private var avatarCache = AvatarCache.shared
    @State private var localAvatarImage: UIImage?
    @State private var cachedImage: UIImage?
    @State private var hasCheckedCache = false

    var body: some View {
        Group {
            // First check for local avatar if targetId is provided
            if let image = localAvatarImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let image = cachedImage {
                // Show cached image (from memory or disk)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if hasCheckedCache {
                // No cached image and already checked - show placeholder
                Image(systemName: placeholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.secondary)
            } else {
                // Still loading - show placeholder (no spinner for better UX)
                Image(systemName: placeholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadLocalAvatar()
            loadImage()
        }
        .onChange(of: url) { _ in
            cachedImage = nil
            hasCheckedCache = false
            loadImage()
        }
        .onChange(of: avatarCache.lastUpdatedTargetId) { updatedId in
            // Refresh when our target's avatar is updated
            if let targetId = targetId, updatedId == targetId {
                loadLocalAvatar()
            }
        }
    }

    private func loadLocalAvatar() {
        guard let targetId = targetId else {
            localAvatarImage = nil
            return
        }
        localAvatarImage = AvatarCache.shared.loadAvatarImage(for: targetId)
    }

    private func loadImage() {
        guard let urlString = url, !urlString.isEmpty else {
            hasCheckedCache = true
            return
        }

        let cache = ImageCache.shared

        // 1. Show cached image immediately (if available)
        if let cached = cache.getCachedImage(for: urlString) {
            cachedImage = cached
        }

        hasCheckedCache = true

        // 2. Always fetch from network in background to update cache
        Task {
            if let newImage = await cache.fetchAndCache(url: urlString) {
                await MainActor.run {
                    cachedImage = newImage
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AsyncImageView(url: Constants.philiaAvatarURL, size: 60)
        AsyncImageView(url: nil, size: 60)
    }
}
