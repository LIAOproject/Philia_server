//
//  AuthService.swift
//  Philia
//
//  Authentication service for device and Apple ID login
//

import Foundation
import AuthenticationServices
import UIKit

enum AuthError: LocalizedError {
    case noDeviceId
    case notAuthenticated
    case appleSignInFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noDeviceId:
            return "Cannot obtain device ID"
        case .notAuthenticated:
            return "Not authenticated"
        case .appleSignInFailed(let message):
            return "Apple Sign In failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let keychain = KeychainHelper.shared
    private let apiClient = APIClient.shared

    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    override private init() {
        super.init()
        // Try to restore session on init
        restoreSession()
    }

    // MARK: - Device ID

    var deviceId: String {
        // Try to get from keychain first (persist across app reinstalls)
        if let savedId = keychain.readString(for: .deviceId) {
            return savedId
        }

        // Get vendor ID or generate UUID
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        try? keychain.saveString(newId, for: .deviceId)
        return newId
    }

    // MARK: - Session Management

    func restoreSession() {
        if keychain.accessToken != nil,
           let user = keychain.readUser() {
            self.currentUser = user
            self.isAuthenticated = true
            print("[Auth] Session restored for user: \(user.displayName)")
        }
    }

    func clearSession() {
        keychain.deleteAll()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Device Auth (Guest Mode)

    func signInWithDevice() async throws -> User {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let request = DeviceAuthRequest(deviceId: deviceId)

        do {
            let response: AuthResponse = try await apiClient.request(
                "auth/device",
                method: "POST",
                body: request
            )

            // Save to keychain
            keychain.accessToken = response.accessToken
            keychain.userId = response.user.id.uuidString
            try? keychain.saveUser(response.user)

            // Update state
            currentUser = response.user
            isAuthenticated = true

            print("[Auth] Device auth success: \(response.message)")
            return response.user
        } catch {
            self.error = error.localizedDescription
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple() async throws -> User {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Start Apple Sign In flow
        let authorization = try await performAppleSignIn()

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.appleSignInFailed("Invalid credential type")
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Missing identity token")
        }

        guard let authCodeData = appleIDCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Missing authorization code")
        }

        // Get full name if available (only on first sign in)
        var fullName: String?
        if let nameComponents = appleIDCredential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: nameComponents)
            if !name.isEmpty {
                fullName = name
            }
        }

        let request = AppleAuthRequest(
            identityToken: identityToken,
            authorizationCode: authCode,
            userIdentifier: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: fullName,
            deviceId: deviceId
        )

        do {
            let response: AuthResponse = try await apiClient.request(
                "auth/apple",
                method: "POST",
                body: request
            )

            // Save to keychain
            keychain.accessToken = response.accessToken
            keychain.userId = response.user.id.uuidString
            try? keychain.saveUser(response.user)

            // Update state
            currentUser = response.user
            isAuthenticated = true

            print("[Auth] Apple auth success: \(response.message)")
            return response.user
        } catch {
            self.error = error.localizedDescription
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Link Apple ID to existing account

    func linkAppleId() async throws -> User {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        let authorization = try await performAppleSignIn()

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.appleSignInFailed("Invalid credential type")
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authCodeData = appleIDCredential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed("Missing credentials")
        }

        var fullName: String?
        if let nameComponents = appleIDCredential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: nameComponents)
            if !name.isEmpty {
                fullName = name
            }
        }

        let request = LinkAppleRequest(
            identityToken: identityToken,
            authorizationCode: authCode,
            userIdentifier: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: fullName
        )

        do {
            let response: AuthResponse = try await apiClient.requestWithAuth(
                "auth/link-apple",
                method: "POST",
                body: request
            )

            // Update keychain
            try? keychain.saveUser(response.user)

            // Update state
            currentUser = response.user

            print("[Auth] Apple ID linked: \(response.message)")
            return response.user
        } catch {
            self.error = error.localizedDescription
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearSession()
        print("[Auth] User signed out")
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard isAuthenticated else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            try await apiClient.requestVoidWithAuth("auth/me", method: "DELETE")
            clearSession()
            print("[Auth] Account deleted")
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Private: Apple Sign In Flow

    private func performAppleSignIn() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            appleSignInContinuation?.resume(returning: authorization)
            appleSignInContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
        }
    }
}
