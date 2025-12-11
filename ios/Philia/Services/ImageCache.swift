//
//  ImageCache.swift
//  Philia
//
//  Image caching service with disk persistence
//  Implements stale-while-revalidate pattern
//

import SwiftUI
import CryptoKit

class ImageCache {
    static let shared = ImageCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, UIImage>()

    private init() {
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachePath.appendingPathComponent("image_cache", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    // MARK: - Cache Key

    private func cacheKey(for url: String) -> String {
        // Use SHA256 hash of URL as filename
        let data = Data(url.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func cacheFileURL(for url: String) -> URL {
        let key = cacheKey(for: url)
        return cacheDirectory.appendingPathComponent(key)
    }

    // MARK: - Get Image

    /// Get cached image (memory first, then disk)
    func getCachedImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url) as NSString

        // Check memory cache first
        if let image = memoryCache.object(forKey: key) {
            return image
        }

        // Check disk cache
        let fileURL = cacheFileURL(for: url)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory cache for faster access
            memoryCache.setObject(image, forKey: key)
            return image
        }

        return nil
    }

    // MARK: - Save Image

    /// Save image to both memory and disk cache
    func saveImage(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url) as NSString

        // Save to memory cache
        memoryCache.setObject(image, forKey: key)

        // Save to disk cache (background)
        DispatchQueue.global(qos: .utility).async {
            let fileURL = self.cacheFileURL(for: url)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
            }
        }
    }

    // MARK: - Fetch and Cache

    /// Fetch image from network and cache it
    func fetchAndCache(url: String) async -> UIImage? {
        guard let imageURL = URL(string: url) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let image = UIImage(data: data) {
                saveImage(image, for: url)
                return image
            }
        } catch {
            // Silently fail - will use cached version if available
        }

        return nil
    }

    // MARK: - Clear Cache

    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()

        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Get cache size in bytes
    func cacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
}
