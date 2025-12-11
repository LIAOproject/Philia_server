//
//  ChatMessage.swift
//  Philia
//
//  Chat message data model
//

import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let chatbotId: UUID
    let role: String  // "user" or "assistant"
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chatbotId = "chatbot_id"
        case role, content
        case createdAt = "created_at"
    }

    var isUser: Bool {
        role == "user"
    }

    var isAssistant: Bool {
        role == "assistant"
    }
}

// MARK: - API Request/Response Types

struct SendMessageRequest: Codable {
    let message: String
}

struct SendMessageResponse: Codable {
    let userMessage: ChatMessage
    let assistantMessage: ChatMessage
    let memoriesRetrieved: Int
    let memoryCreated: Bool

    enum CodingKeys: String, CodingKey {
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
        case memoriesRetrieved = "memories_retrieved"
        case memoryCreated = "memory_created"
    }
}

struct ChatMessageListResponse: Codable {
    let total: Int
    let items: [ChatMessage]
}

// MARK: - Common API Response

struct MessageResponse: Codable {
    let message: String
}
