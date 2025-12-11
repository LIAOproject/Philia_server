//
//  ChatService.swift
//  Philia
//
//  Chat and mentor operations
//

import Foundation

class ChatService {
    static let shared = ChatService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Mentor Operations

    func listMentors(activeOnly: Bool = true) async throws -> MentorListResponse {
        let queryItems = [
            URLQueryItem(name: "active_only", value: String(activeOnly))
        ]
        return try await api.request("chat/mentors", queryItems: queryItems)
    }

    func getMentor(id: UUID) async throws -> Mentor {
        return try await api.request("chat/mentors/\(id.uuidString)")
    }

    // MARK: - Chatbot Operations

    func listChatbots(targetId: UUID? = nil, status: String? = nil, skip: Int = 0, limit: Int = 50) async throws -> ChatbotListResponse {
        var queryItems = [
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let targetId = targetId {
            queryItems.append(URLQueryItem(name: "target_id", value: targetId.uuidString))
        }

        if let status = status {
            queryItems.append(URLQueryItem(name: "status_filter", value: status))
        }

        return try await api.request("chat/chatbots", queryItems: queryItems)
    }

    func getChatbot(id: UUID) async throws -> ChatbotDetail {
        return try await api.request("chat/chatbots/\(id.uuidString)")
    }

    func createChatbot(targetId: UUID, mentorId: UUID, title: String? = nil) async throws -> Chatbot {
        let request = ChatbotCreateRequest(targetId: targetId, mentorId: mentorId, title: title)
        return try await api.request("chat/chatbots", method: "POST", body: request)
    }

    func deleteChatbot(id: UUID) async throws {
        try await api.requestVoid("chat/chatbots/\(id.uuidString)")
    }

    // MARK: - Message Operations

    func listMessages(chatbotId: UUID, skip: Int = 0, limit: Int = 100) async throws -> ChatMessageListResponse {
        let queryItems = [
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await api.request("chat/chatbots/\(chatbotId.uuidString)/messages", queryItems: queryItems)
    }

    func sendMessage(chatbotId: UUID, message: String) async throws -> SendMessageResponse {
        let request = SendMessageRequest(message: message)
        return try await api.request("chat/chatbots/\(chatbotId.uuidString)/send", method: "POST", body: request)
    }

    func sendMessageStream(
        chatbotId: UUID,
        message: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        let request = SendMessageRequest(message: message)
        await api.streamRequest(
            "chat/chatbots/\(chatbotId.uuidString)/send/stream",
            body: request,
            onChunk: onChunk,
            onComplete: onComplete,
            onError: onError
        )
    }
}
