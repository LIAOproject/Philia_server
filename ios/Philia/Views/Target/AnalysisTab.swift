//
//  AnalysisTab.swift
//  Philia
//
//  Analysis tab - profile data and editable parameters
//

import SwiftUI

struct AnalysisTab: View {
    @Binding var target: Target

    @State private var isSaving = false
    @State private var errorMessage: String?

    // Editing states
    @State private var editingField: EditingField?
    @State private var editingText: String = ""

    enum EditingField: Identifiable {
        case ageRange, location, occupation, education, mbti, zodiac

        var id: String {
            switch self {
            case .ageRange: return "ageRange"
            case .location: return "location"
            case .occupation: return "occupation"
            case .education: return "education"
            case .mbti: return "mbti"
            case .zodiac: return "zodiac"
            }
        }

        var title: String {
            switch self {
            case .ageRange: return "年龄"
            case .location: return "所在地"
            case .occupation: return "职业"
            case .education: return "学历"
            case .mbti: return "MBTI"
            case .zodiac: return "星座"
            }
        }
    }

    var body: some View {
        List {
            // AI Summary
            if let summary = target.aiSummary, !summary.isEmpty {
                Section("AI 总结") {
                    Text(summary)
                        .font(.body)
                }
            }

            // Tags
            if let tags = target.profileData.tags, !tags.isEmpty {
                Section("标签") {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Editable Profile Data
            Section("基本信息") {
                EditableProfileRow(
                    label: "年龄",
                    value: target.profileData.ageRange,
                    onTap: {
                        editingText = target.profileData.ageRange ?? ""
                        editingField = .ageRange
                    }
                )

                EditableProfileRow(
                    label: "所在地",
                    value: target.profileData.location,
                    onTap: {
                        editingText = target.profileData.location ?? ""
                        editingField = .location
                    }
                )

                EditableProfileRow(
                    label: "职业",
                    value: target.profileData.occupation,
                    onTap: {
                        editingText = target.profileData.occupation ?? ""
                        editingField = .occupation
                    }
                )

                EditableProfileRow(
                    label: "学历",
                    value: target.profileData.education,
                    onTap: {
                        editingText = target.profileData.education ?? ""
                        editingField = .education
                    }
                )

                EditableProfileRow(
                    label: "MBTI",
                    value: target.profileData.mbti,
                    onTap: {
                        editingText = target.profileData.mbti ?? ""
                        editingField = .mbti
                    }
                )

                EditableProfileRow(
                    label: "星座",
                    value: target.profileData.zodiac,
                    onTap: {
                        editingText = target.profileData.zodiac ?? ""
                        editingField = .zodiac
                    }
                )
            }

            // Appearance
            if let appearance = target.profileData.appearance, !appearance.isEmpty {
                Section("外貌特征") {
                    ForEach(Array(appearance.keys.sorted()), id: \.self) { key in
                        ProfileRow(label: key.capitalized, value: appearance[key])
                    }
                }
            }

            // Personality
            if let personality = target.profileData.personality, !personality.isEmpty {
                Section("性格特点") {
                    ForEach(Array(personality.keys.sorted()), id: \.self) { key in
                        ProfileRow(label: key.capitalized, value: personality[key])
                    }
                }
            }

            // Preferences
            Section("喜欢") {
                if target.preferences.likes.isEmpty {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(target.preferences.likes, id: \.self) { like in
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .font(.caption)
                            Text(like)
                        }
                    }
                }
            }

            Section("不喜欢") {
                if target.preferences.dislikes.isEmpty {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(target.preferences.dislikes, id: \.self) { dislike in
                        HStack {
                            Image(systemName: "hand.thumbsdown.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text(dislike)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingField) { field in
            EditFieldSheet(
                field: field,
                text: $editingText,
                onSave: {
                    Task { await saveField(field) }
                }
            )
        }
        .overlay {
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("保存中...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
    }

    private func saveField(_ field: EditingField) async {
        isSaving = true
        errorMessage = nil

        var updatedProfileData = target.profileData
        let value = editingText.isEmpty ? nil : editingText

        switch field {
        case .ageRange:
            updatedProfileData.ageRange = value
        case .location:
            updatedProfileData.location = value
        case .occupation:
            updatedProfileData.occupation = value
        case .education:
            updatedProfileData.education = value
        case .mbti:
            updatedProfileData.mbti = value
        case .zodiac:
            updatedProfileData.zodiac = value
        }

        let update = TargetUpdateRequest(profileData: updatedProfileData)

        do {
            let updated = try await TargetService.shared.updateTarget(id: target.id, update: update)
            target = updated
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Editable Profile Row

struct EditableProfileRow: View {
    let label: String
    let value: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value ?? "点击编辑")
                    .foregroundColor(value != nil ? .primary : .secondary.opacity(0.6))
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Row (Read-only)

struct ProfileRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value ?? "-")
                .foregroundColor(value != nil ? .primary : .secondary)
        }
    }
}

// MARK: - Edit Field Sheet

struct EditFieldSheet: View {
    let field: AnalysisTab.EditingField
    @Binding var text: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch field {
                case .mbti:
                    Picker("MBTI", selection: $text) {
                        Text("未知").tag("")
                        ForEach(Constants.mbtiTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.wheel)

                case .zodiac:
                    Picker("星座", selection: $text) {
                        Text("未知").tag("")
                        ForEach(Constants.zodiacSigns, id: \.self) { sign in
                            Text(sign).tag(sign)
                        }
                    }
                    .pickerStyle(.wheel)

                default:
                    TextField(field.title, text: $text)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("编辑\(field.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        AnalysisTab(target: .constant(Target(
            id: UUID(),
            name: "Test",
            avatarUrl: nil,
            currentStatus: "dating",
            profileData: ProfileData(
                tags: ["cute", "smart"],
                mbti: "INFJ",
                zodiac: "Leo",
                ageRange: "25-30",
                occupation: "Designer"
            ),
            preferences: Preferences(likes: ["coffee", "movies"], dislikes: ["loud noise"]),
            aiSummary: "This person seems to be creative and thoughtful. They enjoy artistic activities and prefer quiet environments.",
            createdAt: Date(),
            updatedAt: Date()
        )))
    }
}
