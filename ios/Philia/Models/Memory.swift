//
//  Memory.swift
//  Philia
//
//  Memory (event/interaction record) data model
//

import Foundation

struct Memory: Codable, Identifiable {
    let id: UUID
    let targetId: UUID
    let happenedAt: Date
    let sourceType: String
    var content: String?
    var imageUrl: String?
    var extractedFacts: ExtractedFacts
    var sentimentScore: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case targetId = "target_id"
        case happenedAt = "happened_at"
        case sourceType = "source_type"
        case content
        case imageUrl = "image_url"
        case extractedFacts = "extracted_facts"
        case sentimentScore = "sentiment_score"
        case createdAt = "created_at"
    }

    var fullImageUrl: String? {
        guard let imageUrl = imageUrl else { return nil }
        if imageUrl.hasPrefix("http") {
            return imageUrl
        }
        let baseURL = UserDefaults.standard.string(forKey: StorageKeys.apiBaseURL) ?? Constants.defaultAPIBaseURL
        let apiRoot = baseURL.replacingOccurrences(of: "/api/v1", with: "")
        return "\(apiRoot)\(imageUrl)"
    }
}

struct ExtractedFacts: Codable {
    var sentiment: String?
    var keyEvent: String?
    var topics: [String]?
    var subtext: String?
    var redFlags: [String]?
    var greenFlags: [String]?
    var imageType: String?

    enum CodingKeys: String, CodingKey {
        case sentiment
        case keyEvent = "key_event"
        case topics, subtext
        case redFlags = "red_flags"
        case greenFlags = "green_flags"
        case imageType = "image_type"
    }

    init(sentiment: String? = nil, keyEvent: String? = nil, topics: [String]? = nil,
         subtext: String? = nil, redFlags: [String]? = nil, greenFlags: [String]? = nil,
         imageType: String? = nil) {
        self.sentiment = sentiment
        self.keyEvent = keyEvent
        self.topics = topics
        self.subtext = subtext
        self.redFlags = redFlags
        self.greenFlags = greenFlags
        self.imageType = imageType
    }
}

// MARK: - API Response Types

struct MemoryListResponse: Codable {
    let total: Int
    let items: [Memory]
}

// MARK: - Upload Response Types

struct UploadResponse: Codable {
    let success: Bool
    let message: String
    var imageUrl: String?
    var analysisResult: AIAnalysisResult?
    let memoriesCreated: Int
    let profileUpdated: Bool

    enum CodingKeys: String, CodingKey {
        case success, message
        case imageUrl = "image_url"
        case analysisResult = "analysis_result"
        case memoriesCreated = "memories_created"
        case profileUpdated = "profile_updated"
    }
}

struct AIAnalysisResult: Codable {
    var imageType: String?
    var confidence: Double?
    var profileUpdates: ProfileUpdates?
    var newMemories: [NewMemoryInfo]?
    var rawTextExtracted: String?
    var analysisNotes: String?

    enum CodingKeys: String, CodingKey {
        case imageType = "image_type"
        case confidence
        case profileUpdates = "profile_updates"
        case newMemories = "new_memories"
        case rawTextExtracted = "raw_text_extracted"
        case analysisNotes = "analysis_notes"
    }
}

struct ProfileUpdates: Codable {
    var tagsToAdd: [String]?
    var mbti: String?
    var zodiac: String?
    var ageRange: String?
    var occupation: String?
    var location: String?
    var appearanceUpdates: [String: String]?
    var personalityUpdates: [String: String]?
    var likesToAdd: [String]?
    var dislikesToAdd: [String]?

    enum CodingKeys: String, CodingKey {
        case tagsToAdd = "tags_to_add"
        case mbti, zodiac
        case ageRange = "age_range"
        case occupation, location
        case appearanceUpdates = "appearance_updates"
        case personalityUpdates = "personality_updates"
        case likesToAdd = "likes_to_add"
        case dislikesToAdd = "dislikes_to_add"
    }
}

struct NewMemoryInfo: Codable {
    var happenedAt: Date?
    var contentSummary: String?
    var sentiment: String?
    var sentimentScore: Int?
    var keyEvent: String?
    var topics: [String]?
    var subtext: String?
    var redFlags: [String]?
    var greenFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case happenedAt = "happened_at"
        case contentSummary = "content_summary"
        case sentiment
        case sentimentScore = "sentiment_score"
        case keyEvent = "key_event"
        case topics, subtext
        case redFlags = "red_flags"
        case greenFlags = "green_flags"
    }
}
