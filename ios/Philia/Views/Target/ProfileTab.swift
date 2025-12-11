//
//  ProfileTab.swift
//  Philia
//
//  Profile tab - displays uploaded images/memories
//

import SwiftUI
import PhotosUI

struct ProfileTab: View {
    let targetId: UUID

    @State private var memories: [Memory] = []
    @State private var isLoading = true
    @State private var isRefreshing = false  // Background refresh (no loading spinner)
    @State private var errorMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedMemory: Memory?

    // Upload progress states
    @State private var isUploading = false
    @State private var uploadProgress: (current: Int, total: Int) = (0, 0)
    @State private var uploadError: String?

    private let cache = TargetDataCache.shared

    // Split memories into two columns for waterfall layout
    private var leftColumnMemories: [Memory] {
        memories.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
    }

    private var rightColumnMemories: [Memory] {
        memories.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }
    }

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "加载图片中...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await loadMemories() }
                    }
                }
            } else if memories.isEmpty {
                EmptyStateView(
                    icon: "photo.stack",
                    title: "还没有图片",
                    message: "上传聊天截图进行分析"
                )
            } else {
                ScrollView {
                    // Waterfall layout - two columns
                    HStack(alignment: .top, spacing: 8) {
                        // Left column
                        LazyVStack(spacing: 8) {
                            ForEach(leftColumnMemories) { memory in
                                WaterfallImageCard(memory: memory)
                                    .onTapGesture {
                                        selectedMemory = memory
                                    }
                            }
                        }

                        // Right column
                        LazyVStack(spacing: 8) {
                            ForEach(rightColumnMemories) { memory in
                                WaterfallImageCard(memory: memory)
                                    .onTapGesture {
                                        selectedMemory = memory
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 100)
                }
            }

            // Floating bottom button - PhotosPicker
            VStack {
                Spacer()
                if isUploading {
                    // Upload progress indicator
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("上传中 \(uploadProgress.current)/\(uploadProgress.total)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.8))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 24)
                } else {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 9,
                        matching: .images
                    ) {
                        Text("上传新资料")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 24)
                }

                // Upload error toast
                if let error = uploadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                        .onAppear {
                            // Auto-dismiss after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                uploadError = nil
                            }
                        }
                }
            }
        }
        .onChange(of: selectedPhotoItems) { newItems in
            guard !newItems.isEmpty else { return }
            Task { await uploadSelectedPhotos(newItems) }
        }
        .sheet(item: $selectedMemory) { memory in
            MemoryDetailSheet(memory: memory)
        }
        .task {
            await loadMemories()
        }
    }

    private func loadMemories(forceRefresh: Bool = false) async {
        // 1. Try to show cached data first (instant, no loading)
        if !forceRefresh, let cachedMemories = cache.getMemories(targetId: targetId) {
            memories = cachedMemories
            isLoading = false

            // If cache is fresh, skip network request
            if cache.isMemoriesFresh(targetId: targetId) {
                return
            }

            // Otherwise, refresh in background
            isRefreshing = true
        } else {
            // No cache, show loading
            isLoading = memories.isEmpty
        }

        errorMessage = nil

        // 2. Fetch fresh data from API
        do {
            let response = try await MemoryService.shared.listMemories(targetId: targetId)
            let freshMemories = response.items.filter { $0.imageUrl != nil }

            // Update UI and cache
            memories = freshMemories
            cache.saveMemories(freshMemories, targetId: targetId)
        } catch {
            // Only show error if we have no cached data
            if memories.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
        isRefreshing = false
    }

    private func uploadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isUploading = true
        uploadProgress = (0, items.count)
        uploadError = nil

        var successCount = 0
        var lastError: String?

        for (index, item) in items.enumerated() {
            uploadProgress = (index + 1, items.count)

            do {
                // Load image data from PhotosPickerItem
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }

                // Upload to backend (source_type is auto-detected by AI)
                _ = try await UploadService.shared.analyzeImage(
                    image: image,
                    targetId: targetId
                )

                successCount += 1
            } catch {
                lastError = error.localizedDescription
            }
        }

        // Clear selection
        selectedPhotoItems = []
        isUploading = false

        // Show result
        if successCount > 0 {
            // Invalidate cache and refresh
            cache.invalidateMemories(targetId: targetId)
            await loadMemories(forceRefresh: true)
        }

        if let error = lastError, successCount < items.count {
            uploadError = "部分上传失败: \(error)"
        }
    }
}

// MARK: - Waterfall Image Card (小红书风格)

struct WaterfallImageCard: View {
    let memory: Memory

    @State private var cachedImage: UIImage?
    @State private var hasCheckedCache = false

    private var sourceIcon: String {
        switch memory.sourceType {
        case "wechat": return "message.fill"
        case "qq": return "bubble.left.fill"
        case "tantan": return "heart.fill"
        case "soul": return "sparkles"
        case "xiaohongshu": return "book.fill"
        default: return "photo.fill"
        }
    }

    private var sourceName: String {
        Constants.sourceTypes[memory.sourceType] ?? "照片"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: memory.happenedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image - preserves aspect ratio for waterfall effect
            if let image = cachedImage {
                // Show cached image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if hasCheckedCache {
                // No cache - show placeholder
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(0.75, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            } else {
                // Still checking cache - show placeholder (no spinner)
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(0.75, contentMode: .fit)
            }

            // Bottom info bar
            HStack(spacing: 6) {
                Image(systemName: sourceIcon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(sourceName)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let urlString = memory.fullImageUrl, !urlString.isEmpty else {
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

// MARK: - Memory Detail Sheet

struct MemoryDetailSheet: View {
    let memory: Memory
    @Environment(\.dismiss) private var dismiss

    @State private var cachedImage: UIImage?
    @State private var hasCheckedCache = false

    private var sourceName: String {
        Constants.sourceTypes[memory.sourceType] ?? "照片"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: memory.happenedAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Thumbnail image with source info
                    HStack(spacing: 12) {
                        // Thumbnail (cached)
                        Group {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                        .onAppear {
                            loadThumbnail()
                        }

                        // Source and date info
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.image")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Text(sourceName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Info sections
                    VStack(alignment: .leading, spacing: 16) {
                        if let content = memory.content, !content.isEmpty {
                            InfoSection(title: "内容摘要") {
                                Text(content)
                                    .font(.body)
                            }
                        }

                        if let sentiment = memory.extractedFacts.sentiment {
                            InfoSection(title: "情感倾向") {
                                HStack(spacing: 8) {
                                    Text(sentimentEmoji(sentiment))
                                        .font(.title2)
                                    Text(sentiment)
                                        .font(.subheadline)
                                    Text("(\(memory.sentimentScore)分)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let topics = memory.extractedFacts.topics, !topics.isEmpty {
                            InfoSection(title: "话题标签") {
                                FlowLayout(spacing: 8) {
                                    ForEach(topics, id: \.self) { topic in
                                        Text(topic)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }

                        if let redFlags = memory.extractedFacts.redFlags, !redFlags.isEmpty {
                            InfoSection(title: "危险信号") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(redFlags, id: \.self) { flag in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                            Text(flag)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }

                        if let greenFlags = memory.extractedFacts.greenFlags, !greenFlags.isEmpty {
                            InfoSection(title: "积极信号") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(greenFlags, id: \.self) { flag in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                            Text(flag)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }

                        if let subtext = memory.extractedFacts.subtext, !subtext.isEmpty {
                            InfoSection(title: "潜台词分析") {
                                Text(subtext)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("记忆详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func sentimentEmoji(_ sentiment: String) -> String {
        switch sentiment.lowercased() {
        case "positive", "积极": return "😊"
        case "negative", "消极": return "😔"
        case "neutral", "中性": return "😐"
        default: return "🤔"
        }
    }

    private func loadThumbnail() {
        guard let urlString = memory.fullImageUrl, !urlString.isEmpty else {
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

// MARK: - Helper Views

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content()
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    ProfileTab(targetId: UUID())
}
