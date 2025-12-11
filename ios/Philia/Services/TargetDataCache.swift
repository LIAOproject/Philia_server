//
//  TargetDataCache.swift
//  Philia
//
//  Cache for target-related data (memories, chatbots)
//  Uses stale-while-revalidate pattern for better UX
//

import Foundation

/// Cached data with timestamp
struct CachedData<T: Codable>: Codable {
    let data: T
    let cachedAt: Date

    /// Check if cache is fresh (within given seconds)
    func isFresh(maxAge: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(cachedAt) < maxAge
    }
}

/// Cache for target-specific data
class TargetDataCache {
    static let shared = TargetDataCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // In-memory cache for faster access
    private var memoriesCache: [UUID: CachedData<[Memory]>] = [:]
    private var chatbotsCache: [UUID: CachedData<[Chatbot]>] = [:]
    private var mentorsCache: CachedData<[Mentor]>?

    private let queue = DispatchQueue(label: "com.philia.targetDataCache", attributes: .concurrent)

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("target_cache", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load disk cache into memory on init
        loadDiskCache()
    }

    // MARK: - Memories Cache

    /// Get cached memories for a target
    func getMemories(targetId: UUID) -> [Memory]? {
        queue.sync {
            memoriesCache[targetId]?.data
        }
    }

    /// Check if memories cache is fresh
    func isMemoriesFresh(targetId: UUID, maxAge: TimeInterval = 300) -> Bool {
        queue.sync {
            memoriesCache[targetId]?.isFresh(maxAge: maxAge) ?? false
        }
    }

    /// Save memories to cache
    func saveMemories(_ memories: [Memory], targetId: UUID) {
        let cached = CachedData(data: memories, cachedAt: Date())
        queue.async(flags: .barrier) {
            self.memoriesCache[targetId] = cached
            self.saveToDisk(cached, filename: "memories_\(targetId.uuidString).json")
        }
    }

    /// Invalidate memories cache for a target
    func invalidateMemories(targetId: UUID) {
        queue.async(flags: .barrier) {
            self.memoriesCache.removeValue(forKey: targetId)
            self.deleteFromDisk(filename: "memories_\(targetId.uuidString).json")
        }
    }

    // MARK: - Chatbots Cache

    /// Get cached chatbots for a target
    func getChatbots(targetId: UUID) -> [Chatbot]? {
        queue.sync {
            chatbotsCache[targetId]?.data
        }
    }

    /// Check if chatbots cache is fresh
    func isChatbotsFresh(targetId: UUID, maxAge: TimeInterval = 300) -> Bool {
        queue.sync {
            chatbotsCache[targetId]?.isFresh(maxAge: maxAge) ?? false
        }
    }

    /// Save chatbots to cache
    func saveChatbots(_ chatbots: [Chatbot], targetId: UUID) {
        let cached = CachedData(data: chatbots, cachedAt: Date())
        queue.async(flags: .barrier) {
            self.chatbotsCache[targetId] = cached
            self.saveToDisk(cached, filename: "chatbots_\(targetId.uuidString).json")
        }
    }

    /// Invalidate chatbots cache for a target
    func invalidateChatbots(targetId: UUID) {
        queue.async(flags: .barrier) {
            self.chatbotsCache.removeValue(forKey: targetId)
            self.deleteFromDisk(filename: "chatbots_\(targetId.uuidString).json")
        }
    }

    // MARK: - Mentors Cache (global, not per-target)

    /// Get cached mentors
    func getMentors() -> [Mentor]? {
        queue.sync {
            mentorsCache?.data
        }
    }

    /// Check if mentors cache is fresh (5 minutes)
    func isMentorsFresh(maxAge: TimeInterval = 300) -> Bool {
        queue.sync {
            mentorsCache?.isFresh(maxAge: maxAge) ?? false
        }
    }

    /// Save mentors to cache
    func saveMentors(_ mentors: [Mentor]) {
        let cached = CachedData(data: mentors, cachedAt: Date())
        queue.async(flags: .barrier) {
            self.mentorsCache = cached
            self.saveToDisk(cached, filename: "mentors.json")
        }
    }

    /// Invalidate mentors cache
    func invalidateMentors() {
        queue.async(flags: .barrier) {
            self.mentorsCache = nil
            self.deleteFromDisk(filename: "mentors.json")
        }
    }

    // MARK: - Preload

    /// Preload data for a target in the background
    /// Call this when target becomes visible or when entering home page
    func preloadTarget(_ targetId: UUID) {
        // Skip if cache is fresh
        if isMemoriesFresh(targetId: targetId) && isChatbotsFresh(targetId: targetId) {
            return
        }

        Task.detached(priority: .background) {
            // Preload memories if not fresh
            if !self.isMemoriesFresh(targetId: targetId) {
                do {
                    let response = try await MemoryService.shared.listMemories(targetId: targetId)
                    let memories = response.items.filter { $0.imageUrl != nil }
                    self.saveMemories(memories, targetId: targetId)
                } catch {
                    // Silently fail - preload is best effort
                }
            }

            // Preload chatbots if not fresh
            if !self.isChatbotsFresh(targetId: targetId) {
                do {
                    let response = try await ChatService.shared.listChatbots(targetId: targetId)
                    self.saveChatbots(response.items, targetId: targetId)
                } catch {
                    // Silently fail - preload is best effort
                }
            }
        }
    }

    /// Preload data for multiple targets (first N)
    func preloadTargets(_ targets: [Target], limit: Int = 5) {
        // Also preload mentors (global)
        if !isMentorsFresh() {
            Task.detached(priority: .background) {
                do {
                    let response = try await ChatService.shared.listMentors()
                    self.saveMentors(response.items)
                } catch {
                    // Silently fail
                }
            }
        }

        // Preload first N targets
        for target in targets.prefix(limit) {
            preloadTarget(target.id)
        }
    }

    // MARK: - Clear Cache

    /// Clear all cache for a specific target
    func clearTargetCache(targetId: UUID) {
        invalidateMemories(targetId: targetId)
        invalidateChatbots(targetId: targetId)
    }

    /// Clear all caches
    func clearAllCache() {
        queue.async(flags: .barrier) {
            self.memoriesCache.removeAll()
            self.chatbotsCache.removeAll()
            self.mentorsCache = nil

            // Delete all files in cache directory
            if let files = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil) {
                for file in files {
                    try? self.fileManager.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - Disk Persistence

    private func saveToDisk<T: Codable>(_ data: CachedData<T>, filename: String) {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: fileURL)
        }
    }

    private func deleteFromDisk(filename: String) {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    private func loadFromDisk<T: Codable>(_ type: CachedData<T>.Type, filename: String) -> CachedData<T>? {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL),
              let cached = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return cached
    }

    private func loadDiskCache() {
        // Load mentors
        if let cached = loadFromDisk(CachedData<[Mentor]>.self, filename: "mentors.json") {
            mentorsCache = cached
        }

        // Load memories and chatbots per target
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                let filename = file.lastPathComponent

                if filename.hasPrefix("memories_"), filename.hasSuffix(".json") {
                    let uuidString = filename.replacingOccurrences(of: "memories_", with: "").replacingOccurrences(of: ".json", with: "")
                    if let uuid = UUID(uuidString: uuidString),
                       let cached = loadFromDisk(CachedData<[Memory]>.self, filename: filename) {
                        memoriesCache[uuid] = cached
                    }
                }

                if filename.hasPrefix("chatbots_"), filename.hasSuffix(".json") {
                    let uuidString = filename.replacingOccurrences(of: "chatbots_", with: "").replacingOccurrences(of: ".json", with: "")
                    if let uuid = UUID(uuidString: uuidString),
                       let cached = loadFromDisk(CachedData<[Chatbot]>.self, filename: filename) {
                        chatbotsCache[uuid] = cached
                    }
                }
            }
        }
    }
}
