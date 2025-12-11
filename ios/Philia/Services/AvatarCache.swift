//
//  AvatarCache.swift
//  Philia
//
//  Local avatar storage for custom uploaded avatars
//

import Foundation
import UIKit
import Combine

class AvatarCache: ObservableObject {
    static let shared = AvatarCache()

    /// Published when any avatar is updated - views can observe this to refresh
    @Published private(set) var lastUpdatedTargetId: UUID?

    private let fileManager = FileManager.default
    private let avatarDirectory: URL

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        avatarDirectory = documentsPath.appendingPathComponent("avatars", isDirectory: true)

        // Create avatars directory if it doesn't exist
        if !fileManager.fileExists(atPath: avatarDirectory.path) {
            try? fileManager.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public Methods

    /// Save avatar data for a target ID
    func saveAvatar(data: Data, for targetId: UUID) {
        let fileURL = avatarDirectory.appendingPathComponent("\(targetId.uuidString).png")
        try? data.write(to: fileURL)

        // Notify observers that this avatar was updated
        DispatchQueue.main.async {
            self.lastUpdatedTargetId = targetId
        }
    }

    /// Load avatar data for a target ID
    func loadAvatar(for targetId: UUID) -> Data? {
        let fileURL = avatarDirectory.appendingPathComponent("\(targetId.uuidString).png")
        return try? Data(contentsOf: fileURL)
    }

    /// Load avatar as UIImage for a target ID
    func loadAvatarImage(for targetId: UUID) -> UIImage? {
        guard let data = loadAvatar(for: targetId) else { return nil }
        return UIImage(data: data)
    }

    /// Check if local avatar exists for a target ID
    func hasLocalAvatar(for targetId: UUID) -> Bool {
        let fileURL = avatarDirectory.appendingPathComponent("\(targetId.uuidString).png")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Delete avatar for a target ID
    func deleteAvatar(for targetId: UUID) {
        let fileURL = avatarDirectory.appendingPathComponent("\(targetId.uuidString).png")
        try? fileManager.removeItem(at: fileURL)

        // Notify observers that this avatar was updated (deleted)
        DispatchQueue.main.async {
            self.lastUpdatedTargetId = targetId
        }
    }
}
