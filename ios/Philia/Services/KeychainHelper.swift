//
//  KeychainHelper.swift
//  Philia
//
//  Secure storage using iOS Keychain
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case notFound
    case encodingError
}

class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.philia.app"

    private init() {}

    // MARK: - Keys

    enum Key: String {
        case accessToken = "access_token"
        case userId = "user_id"
        case deviceId = "device_id"
        case userInfo = "user_info"
    }

    // MARK: - Generic Methods

    func save(_ data: Data, for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        // Delete existing item if exists
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    func read(for key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        for key in [Key.accessToken, Key.userId, Key.deviceId, Key.userInfo] {
            delete(for: key)
        }
    }

    // MARK: - Convenience Methods

    func saveString(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(data, for: key)
    }

    func readString(for key: Key) -> String? {
        guard let data = read(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveUser(_ user: User) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(user)
        try save(data, for: .userInfo)
    }

    func readUser() -> User? {
        guard let data = read(for: .userInfo) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(User.self, from: data)
    }

    // MARK: - Auth Token

    var accessToken: String? {
        get { readString(for: .accessToken) }
        set {
            if let value = newValue {
                try? saveString(value, for: .accessToken)
            } else {
                delete(for: .accessToken)
            }
        }
    }

    var userId: String? {
        get { readString(for: .userId) }
        set {
            if let value = newValue {
                try? saveString(value, for: .userId)
            } else {
                delete(for: .userId)
            }
        }
    }
}
