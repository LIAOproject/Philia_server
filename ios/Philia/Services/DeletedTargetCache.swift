//
//  DeletedTargetCache.swift
//  Philia
//
//  Local storage for soft-deleted targets (30-day recovery)
//

import Foundation

struct DeletedTarget: Codable, Identifiable {
    let target: Target
    let deletedAt: Date

    var id: UUID { target.id }

    // Check if still within 30-day recovery period
    var isRecoverable: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return deletedAt > thirtyDaysAgo
    }

    // Days remaining for recovery
    var daysRemaining: Int {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: deletedAt)!
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, days)
    }
}

class DeletedTargetCache {
    static let shared = DeletedTargetCache()

    private let fileManager = FileManager.default
    private let cacheFile: URL

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFile = documentsPath.appendingPathComponent("deleted_targets.json")
    }

    // MARK: - Public Methods

    /// Add a target to the deleted cache
    func addDeletedTarget(_ target: Target) {
        var deletedTargets = loadDeletedTargets()

        // Remove if already exists (shouldn't happen, but be safe)
        deletedTargets.removeAll { $0.id == target.id }

        // Add new deleted target
        let deletedTarget = DeletedTarget(target: target, deletedAt: Date())
        deletedTargets.append(deletedTarget)

        saveDeletedTargets(deletedTargets)
    }

    /// Get all recoverable deleted targets (within 30 days)
    func getRecoverableTargets() -> [DeletedTarget] {
        let allDeleted = loadDeletedTargets()
        let recoverable = allDeleted.filter { $0.isRecoverable }

        // Clean up expired ones
        if recoverable.count != allDeleted.count {
            saveDeletedTargets(recoverable)
        }

        // Sort by deletion date, newest first
        return recoverable.sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Remove a target from deleted cache (after restore or permanent delete)
    func removeFromCache(targetId: UUID) {
        var deletedTargets = loadDeletedTargets()
        deletedTargets.removeAll { $0.id == targetId }
        saveDeletedTargets(deletedTargets)

        // Also remove avatar cache
        AvatarCache.shared.deleteAvatar(for: targetId)
    }

    /// Get a specific deleted target
    func getDeletedTarget(id: UUID) -> DeletedTarget? {
        return loadDeletedTargets().first { $0.id == id }
    }

    /// Check if a target is in deleted cache
    func isDeleted(targetId: UUID) -> Bool {
        return loadDeletedTargets().contains { $0.id == targetId }
    }

    // MARK: - Private Methods

    private func loadDeletedTargets() -> [DeletedTarget] {
        guard fileManager.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile),
              let targets = try? JSONDecoder().decode([DeletedTarget].self, from: data) else {
            return []
        }
        return targets
    }

    private func saveDeletedTargets(_ targets: [DeletedTarget]) {
        guard let data = try? JSONEncoder().encode(targets) else { return }
        try? data.write(to: cacheFile)
    }
}
