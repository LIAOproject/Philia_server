//
//  Constants.swift
//  Philia
//
//  App-wide constants and configuration
//

import SwiftUI

enum Constants {
    // MARK: - API Configuration
    static let defaultAPIBaseURL = "http://14.103.211.140:8000/api/v1"

    // MARK: - Philia Brand (PNG format for iOS compatibility)
    static let philiaAvatarURL = "https://api.dicebear.com/7.x/adventurer/png?seed=Philia&hair=long16&hairColor=0ea5e9&skinColor=f5cfa0&size=128"

    // MARK: - Source Types
    static let sourceTypes = [
        "wechat": "微信",
        "qq": "QQ",
        "tantan": "探探",
        "soul": "Soul",
        "xiaohongshu": "小红书",
        "photo": "照片"
    ]

    // MARK: - Relationship Status
    enum RelationshipStatus: String, CaseIterable {
        case pursuing = "pursuing"
        case dating = "dating"
        case friend = "friend"
        case complicated = "complicated"
        case ended = "ended"

        var displayName: String {
            switch self {
            case .pursuing: return "追求中"
            case .dating: return "交往中"
            case .friend: return "朋友"
            case .complicated: return "复杂"
            case .ended: return "已结束"
            }
        }

        var color: Color {
            switch self {
            case .pursuing: return .pink
            case .dating: return .red
            case .friend: return .blue
            case .complicated: return .yellow
            case .ended: return .gray
            }
        }

        var emoji: String {
            switch self {
            case .pursuing: return "💘"
            case .dating: return "❤️"
            case .friend: return "💙"
            case .complicated: return "💛"
            case .ended: return "🖤"
            }
        }
    }

    // MARK: - MBTI Types
    static let mbtiTypes = [
        "INTJ", "INTP", "ENTJ", "ENTP",
        "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ",
        "ISTP", "ISFP", "ESTP", "ESFP"
    ]

    // MARK: - Zodiac Signs
    static let zodiacSigns = [
        "白羊座", "金牛座", "双子座", "巨蟹座",
        "狮子座", "处女座", "天秤座", "天蝎座",
        "射手座", "摩羯座", "水瓶座", "双鱼座"
    ]
}

// MARK: - App Storage Keys
enum StorageKeys {
    static let apiBaseURL = "api_base_url"
    static let isAuthenticated = "is_authenticated"
    static let userId = "user_id"
}
