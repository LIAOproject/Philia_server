//
//  ImageUploadSheet.swift
//  Philia
//
//  Image upload and analysis sheet
//

import SwiftUI
import PhotosUI

struct ImageUploadSheet: View {
    let targetId: UUID
    var onUploaded: ((UploadResponse) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var sourceType = "wechat"
    @State private var happenedAt = Date()
    @State private var useCustomDate = false

    @State private var isUploading = false
    @State private var uploadResult: UploadResponse?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("选择图片")
                                    .font(.headline)
                                Text("点击从相册选择")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }

                    // Source Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("来源类型")
                            .font(.headline)

                        Picker("来源", selection: $sourceType) {
                            ForEach(Array(Constants.sourceTypes.keys.sorted()), id: \.self) { key in
                                Text(Constants.sourceTypes[key] ?? key).tag(key)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Date Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("自定义日期", isOn: $useCustomDate)

                        if useCustomDate {
                            DatePicker("日期", selection: $happenedAt, displayedComponents: [.date, .hourAndMinute])
                        }
                    }

                    // Upload Button
                    Button(action: uploadImage) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isUploading ? "分析中..." : "上传并分析")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedImage == nil || isUploading ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedImage == nil || isUploading)

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Upload Result
                    if let result = uploadResult {
                        UploadResultView(result: result)
                    }
                }
                .padding()
            }
            .navigationTitle("上传图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                if uploadResult != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
    }

    private func uploadImage() {
        guard let image = selectedImage else { return }

        isUploading = true
        errorMessage = nil
        uploadResult = nil

        Task {
            do {
                let response = try await UploadService.shared.analyzeImage(
                    image: image,
                    targetId: targetId,
                    sourceType: sourceType,
                    happenedAt: useCustomDate ? happenedAt : nil
                )
                uploadResult = response
                onUploaded?(response)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploading = false
        }
    }
}

// MARK: - Upload Result View

struct UploadResultView: View {
    let result: UploadResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Success Banner
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(result.success ? .green : .orange)
                Text(result.message)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(result.success ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Analysis Result
            if let analysis = result.analysisResult {
                VStack(alignment: .leading, spacing: 12) {
                    Text("分析结果")
                        .font(.headline)

                    if let imageType = analysis.imageType {
                        ResultRow(label: "图片类型", value: imageType)
                    }

                    if let confidence = analysis.confidence {
                        ResultRow(label: "置信度", value: String(format: "%.0f%%", confidence * 100))
                    }

                    // Tags to add
                    if let tags = analysis.profileUpdates?.tagsToAdd, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("新标签")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            FlowLayout(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // New memories
                    if let memories = analysis.newMemories, !memories.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("提取的信息")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(memories.enumerated()), id: \.offset) { _, memory in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let content = memory.contentSummary {
                                        Text(content)
                                            .font(.caption)
                                    }
                                    if let sentiment = memory.sentiment {
                                        HStack {
                                            Text("情感:")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(sentiment)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(sentimentColor(sentiment).opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }

            // Stats
            HStack(spacing: 20) {
                StatBadge(
                    icon: "photo.stack",
                    value: "\(result.memoriesCreated)",
                    label: "记忆"
                )

                if result.profileUpdated {
                    StatBadge(
                        icon: "person.fill.checkmark",
                        value: "是",
                        label: "资料已更新"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive": return .green
        case "negative": return .red
        default: return .gray
        }
    }
}

// MARK: - Helper Views

struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ImageUploadSheet(targetId: UUID())
}
