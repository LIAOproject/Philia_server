//
//  Chatbot.swift
//  Philia
//
//  Chatbot (chat session) data model
//

import Foundation

struct Chatbot: Codable, Identifiable {
    let id: UUID
    let targetId: UUID
    let mentorId: UUID
    var title: String
    var status: String
    let createdAt: Date
    let updatedAt: Date
    var targetName: String?
    var mentorName: String?
    var mentorIconUrl: String?
    var messageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case targetId = "target_id"
        case mentorId = "mentor_id"
        case title, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case targetName = "target_name"
        case mentorName = "mentor_name"
        case mentorIconUrl = "mentor_icon_url"
        case messageCount = "message_count"
    }
}

struct ChatbotDetail: Codable, Identifiable {
    let id: UUID
    let targetId: UUID
    let mentorId: UUID
    var title: String
    var status: String
    let createdAt: Date
    let updatedAt: Date
    var targetName: String?
    var mentorName: String?
    var mentorIconUrl: String?
    var messageCount: Int?
    var recentMessages: [ChatMessage]?

    enum CodingKeys: String, CodingKey {
        case id
        case targetId = "target_id"
        case mentorId = "mentor_id"
        case title, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case targetName = "target_name"
        case mentorName = "mentor_name"
        case mentorIconUrl = "mentor_icon_url"
        case messageCount = "message_count"
        case recentMessages = "recent_messages"
    }
}

// MARK: - API Request/Response Types

struct ChatbotCreateRequest: Codable {
    let targetId: UUID
    let mentorId: UUID
    var title: String?

    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case mentorId = "mentor_id"
        case title
    }
}

struct ChatbotListResponse: Codable {
    let total: Int
    let items: [Chatbot]
}
