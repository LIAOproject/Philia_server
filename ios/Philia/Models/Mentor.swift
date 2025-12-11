//
//  Mentor.swift
//  Philia
//
//  AI Mentor data model
//

import Foundation

struct Mentor: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let iconUrl: String?
    let styleTag: String?
    let isActive: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconUrl = "icon_url"
        case styleTag = "style_tag"
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - API Response Types

struct MentorListResponse: Codable {
    let total: Int
    let items: [Mentor]
}
