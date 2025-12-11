//
//  PinnedTargetCache.swift
//  Philia
//
//  Local storage for pinned targets
//

import Foundation

class PinnedTargetCache {
    static let shared = PinnedTargetCache()

    private let userDefaults = UserDefaults.standard
    private let pinnedKey = "pinned_target_ids"

    private init() {}

    // MARK: - Public Methods

    /// Get all pinned target IDs
    func getPinnedIds() -> Set<UUID> {
        guard let strings = userDefaults.stringArray(forKey: pinnedKey) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    /// Check if a target is pinned
    func isPinned(_ targetId: UUID) -> Bool {
        return getPinnedIds().contains(targetId)
    }

    /// Pin a target
    func pin(_ targetId: UUID) {
        var pinnedIds = getPinnedIds()
        pinnedIds.insert(targetId)
        savePinnedIds(pinnedIds)
    }

    /// Unpin a target
    func unpin(_ targetId: UUID) {
        var pinnedIds = getPinnedIds()
        pinnedIds.remove(targetId)
        savePinnedIds(pinnedIds)
    }

    /// Toggle pin state
    func togglePin(_ targetId: UUID) -> Bool {
        if isPinned(targetId) {
            unpin(targetId)
            return false
        } else {
            pin(targetId)
            return true
        }
    }

    // MARK: - Private Methods

    private func savePinnedIds(_ ids: Set<UUID>) {
        let strings = ids.map { $0.uuidString }
        userDefaults.set(strings, forKey: pinnedKey)
    }
}
