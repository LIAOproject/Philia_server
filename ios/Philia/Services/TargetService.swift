//
//  TargetService.swift
//  Philia
//
//  Target CRUD operations
//

import Foundation

class TargetService {
    static let shared = TargetService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - CRUD Operations

    func listTargets(skip: Int = 0, limit: Int = 50, statusFilter: String? = nil) async throws -> TargetListResponse {
        var queryItems = [
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let status = statusFilter {
            queryItems.append(URLQueryItem(name: "status_filter", value: status))
        }

        return try await api.request("targets", queryItems: queryItems)
    }

    func getTarget(id: UUID) async throws -> Target {
        return try await api.request("targets/\(id.uuidString)")
    }

    func createTarget(name: String, status: String = "pursuing", avatarUrl: String? = nil) async throws -> Target {
        let request = TargetCreateRequest(
            name: name,
            avatarUrl: avatarUrl,
            currentStatus: status,
            profileData: ProfileData(),
            preferences: Preferences()
        )
        return try await api.request("targets", method: "POST", body: request)
    }

    func updateTarget(id: UUID, update: TargetUpdateRequest) async throws -> Target {
        return try await api.request("targets/\(id.uuidString)", method: "PATCH", body: update)
    }

    func deleteTarget(id: UUID) async throws {
        try await api.requestVoid("targets/\(id.uuidString)")
    }
}
