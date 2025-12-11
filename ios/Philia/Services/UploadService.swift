//
//  UploadService.swift
//  Philia
//
//  Image upload and analysis
//

import Foundation
import UIKit

class UploadService {
    static let shared = UploadService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Upload Operations

    func analyzeImage(
        image: UIImage,
        targetId: UUID,
        sourceType: String = "photo",
        happenedAt: Date? = nil
    ) async throws -> UploadResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }

        var parameters: [String: String] = [
            "target_id": targetId.uuidString,
            "source_type": sourceType
        ]

        if let date = happenedAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            parameters["happened_at"] = formatter.string(from: date)
        }

        return try await api.upload(
            endpoint: "upload/analyze",
            fileData: imageData,
            fileName: "image.jpg",
            mimeType: "image/jpeg",
            parameters: parameters
        )
    }

    func analyzeImageOnly(image: UIImage) async throws -> AIAnalysisResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }

        return try await api.upload(
            endpoint: "upload/analyze-only",
            fileData: imageData,
            fileName: "image.jpg",
            mimeType: "image/jpeg",
            parameters: [:]
        ).analysisResult ?? AIAnalysisResult()
    }
}
