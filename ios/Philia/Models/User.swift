//
//  User.swift
//  Philia
//
//  User model for authentication
//

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let deviceId: String
    let appleId: String?
    let email: String?
    let nickname: String?
    let avatarUrl: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let lastLoginAt: Date?
    let isAppleLinked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case appleId = "apple_id"
        case email
        case nickname
        case avatarUrl = "avatar_url"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLoginAt = "last_login_at"
        case isAppleLinked = "is_apple_linked"
    }

    /// Display name: nickname > email > "Guest"
    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return nickname
        }
        if let email = email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return "Guest"
    }

    /// Whether this is a guest account (not linked to Apple ID)
    var isGuest: Bool {
        return appleId == nil
    }
}

// MARK: - Auth Response

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let user: User
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case user
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - Auth Requests

struct DeviceAuthRequest: Codable {
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let userIdentifier: String
    let email: String?
    let fullName: String?
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case userIdentifier = "user_identifier"
        case email
        case fullName = "full_name"
        case deviceId = "device_id"
    }
}

struct LinkAppleRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let userIdentifier: String
    let email: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case userIdentifier = "user_identifier"
        case email
        case fullName = "full_name"
    }
}
