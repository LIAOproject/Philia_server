//
//  MemoryService.swift
//  Philia
//
//  Memory operations
//

import Foundation

class MemoryService {
    static let shared = MemoryService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Memory Operations

    func listMemories(targetId: UUID, sourceType: String? = nil, skip: Int = 0, limit: Int = 100) async throws -> MemoryListResponse {
        var queryItems = [
            URLQueryItem(name: "target_id", value: targetId.uuidString),
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let source = sourceType {
            queryItems.append(URLQueryItem(name: "source_type", value: source))
        }

        return try await api.request("memories", queryItems: queryItems)
    }

    func getMemory(id: UUID) async throws -> Memory {
        return try await api.request("memories/\(id.uuidString)")
    }

    func deleteMemory(id: UUID) async throws {
        try await api.requestVoid("memories/\(id.uuidString)")
    }

    func getTimeline(targetId: UUID, skip: Int = 0, limit: Int = 100) async throws -> MemoryListResponse {
        let queryItems = [
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        return try await api.request("memories/target/\(targetId.uuidString)/timeline", queryItems: queryItems)
    }
}
