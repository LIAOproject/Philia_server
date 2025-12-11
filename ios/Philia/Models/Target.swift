//
//  Target.swift
//  Philia
//
//  Target (relationship person) data model
//

import Foundation

struct Target: Codable, Identifiable {
    let id: UUID
    var name: String
    var avatarUrl: String?
    var currentStatus: String
    var profileData: ProfileData
    var preferences: Preferences
    var aiSummary: String?
    var memoryCount: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case avatarUrl = "avatar_url"
        case currentStatus = "current_status"
        case profileData = "profile_data"
        case preferences
        case aiSummary = "ai_summary"
        case memoryCount = "memory_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProfileData: Codable {
    var tags: [String]?
    var mbti: String?
    var zodiac: String?
    var ageRange: String?
    var occupation: String?
    var location: String?
    var education: String?
    var appearance: [String: String]?
    var personality: [String: String]?

    enum CodingKeys: String, CodingKey {
        case tags, mbti, zodiac
        case ageRange = "age_range"
        case occupation, location, education
        case appearance, personality
    }

    init(tags: [String]? = nil, mbti: String? = nil, zodiac: String? = nil,
         ageRange: String? = nil, occupation: String? = nil, location: String? = nil,
         education: String? = nil, appearance: [String: String]? = nil,
         personality: [String: String]? = nil) {
        self.tags = tags
        self.mbti = mbti
        self.zodiac = zodiac
        self.ageRange = ageRange
        self.occupation = occupation
        self.location = location
        self.education = education
        self.appearance = appearance
        self.personality = personality
    }
}

struct Preferences: Codable {
    var likes: [String]
    var dislikes: [String]

    init(likes: [String] = [], dislikes: [String] = []) {
        self.likes = likes
        self.dislikes = dislikes
    }
}

// MARK: - API Request/Response Types

struct TargetCreateRequest: Codable {
    let name: String
    var avatarUrl: String?
    var currentStatus: String?
    var profileData: ProfileData?
    var preferences: Preferences?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
        case currentStatus = "current_status"
        case profileData = "profile_data"
        case preferences
    }
}

struct TargetUpdateRequest: Codable {
    var name: String?
    var avatarUrl: String?
    var currentStatus: String?
    var profileData: ProfileData?
    var preferences: Preferences?
    var aiSummary: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
        case currentStatus = "current_status"
        case profileData = "profile_data"
        case preferences
        case aiSummary = "ai_summary"
    }
}

struct TargetListResponse: Codable {
    let total: Int
    let items: [Target]
}
