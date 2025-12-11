//
//  EditTargetSheet.swift
//  Philia
//
//  Edit target profile
//

import SwiftUI
import PhotosUI

struct EditTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: Target

    // Editable fields
    @State private var editedName: String = ""
    @State private var selectedGender: Gender = .male
    @State private var selectedStatus: Constants.RelationshipStatus = .dating
    @State private var selectedAvatarUrl: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var customAvatarData: Data? = nil
    @State private var imageToCrop: UIImage? = nil
    @State private var showImageCropper = false

    // Edit mode states
    @State private var showAvatarPicker = false
    @State private var showGenderPicker = false
    @State private var showStatusPicker = false

    @State private var isSaving = false
    @State private var errorMessage: String?

    // Gender enum
    enum Gender: String, CaseIterable {
        case male = "male"
        case female = "female"
        case other = "other"

        var displayName: String {
            switch self {
            case .male: return "男生"
            case .female: return "女生"
            case .other: return "其他"
            }
        }

        var icon: String {
            switch self {
            case .male: return "figure.stand"
            case .female: return "figure.stand.dress"
            case .other: return "sparkles"
            }
        }

        var color: Color {
            switch self {
            case .male: return .blue
            case .female: return .pink
            case .other: return .purple
            }
        }
    }

    // Preset avatars
    private let presetAvatars = [
        "https://api.dicebear.com/7.x/micah/png?seed=Leo&backgroundColor=b6e3f4&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Kevin&backgroundColor=c0aede&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Jack&backgroundColor=d1d4f9&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Emma&backgroundColor=ffd5dc&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Sophie&backgroundColor=ffdfbf&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Oliver&backgroundColor=c1f4c5&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Mia&backgroundColor=ffeaa7&size=128",
        "https://api.dicebear.com/7.x/micah/png?seed=Lucas&backgroundColor=dfe6e9&size=128"
    ]

    private var isNameValid: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var length = 0
        for char in trimmed {
            length += char.isASCII ? 1 : 2
        }
        return length >= 2 && length <= 12
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: - Avatar Section
                    VStack(spacing: 16) {
                        // Large avatar display
                        ZStack(alignment: .bottomTrailing) {
                            avatarView
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                            // Edit badge
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 4, y: 4)
                        }
                        .onTapGesture {
                            showAvatarPicker = true
                        }
                    }
                    .padding(.top, 16)

                    // MARK: - Info Fields (Settings style)
                    VStack(alignment: .leading, spacing: 24) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("名称")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("输入名称", text: $editedName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(Color(.systemBackground))
                                .cornerRadius(22)
                        }

                        // Gender Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("性别")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(selectedGender.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Color(.systemBackground))
                            .cornerRadius(22)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showGenderPicker = true
                            }
                        }

                        // Relationship Type Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("关系类型")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(selectedStatus.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Color(.systemBackground))
                            .cornerRadius(22)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showStatusPicker = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("编辑对象资料")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("保存") { saveChanges() }
                            .fontWeight(.semibold)
                            .disabled(!isNameValid)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .onAppear {
            editedName = target.name
            selectedAvatarUrl = target.avatarUrl

            if let status = Constants.RelationshipStatus(rawValue: target.currentStatus) {
                selectedStatus = status
            }

            if let genderStr = target.profileData.personality?["gender"],
               let gender = Gender(rawValue: genderStr) {
                selectedGender = gender
            }

            if let avatarData = AvatarCache.shared.loadAvatar(for: target.id) {
                customAvatarData = avatarData
                selectedAvatarUrl = nil
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(
                selectedAvatarUrl: $selectedAvatarUrl,
                customAvatarData: $customAvatarData,
                selectedPhotoItem: $selectedPhotoItem,
                presetAvatars: presetAvatars
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showGenderPicker) {
            GenderPickerSheet(selectedGender: $selectedGender)
                .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showStatusPicker) {
            StatusPickerSheet(selectedStatus: $selectedStatus)
                .presentationDetents([.height(200)])
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem = newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    imageToCrop = image
                    showImageCropper = true
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showImageCropper) {
            if let image = imageToCrop {
                ImageCropperSheet(image: image) { croppedData in
                    customAvatarData = croppedData
                    selectedAvatarUrl = nil
                    showAvatarPicker = false
                }
            }
        }
    }

    // MARK: - Avatar View
    @ViewBuilder
    private var avatarView: some View {
        if let data = customAvatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = selectedAvatarUrl, let imageUrl = URL(string: url) {
            AsyncImage(url: imageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color(.systemGray4))
            }
        } else {
            AsyncImageView(
                url: target.avatarUrl,
                placeholder: "person.crop.circle.fill",
                size: 100,
                targetId: target.id
            )
        }
    }

    // MARK: - Save
    private func saveChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                var updatedProfileData = target.profileData
                var personality = updatedProfileData.personality ?? [:]
                personality["gender"] = selectedGender.rawValue
                updatedProfileData.personality = personality

                var avatarUrl: String? = selectedAvatarUrl
                if customAvatarData != nil {
                    avatarUrl = nil
                }

                let updateRequest = TargetUpdateRequest(
                    name: trimmedName,
                    avatarUrl: avatarUrl,
                    currentStatus: selectedStatus.rawValue,
                    profileData: updatedProfileData
                )

                let updatedTarget = try await TargetService.shared.updateTarget(
                    id: target.id,
                    update: updateRequest
                )

                if let avatarData = customAvatarData {
                    AvatarCache.shared.saveAvatar(data: avatarData, for: target.id)
                } else if selectedAvatarUrl != nil {
                    AvatarCache.shared.deleteAvatar(for: target.id)
                }

                await MainActor.run {
                    target = updatedTarget
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Avatar Picker Sheet

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAvatarUrl: String?
    @Binding var customAvatarData: Data?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let presetAvatars: [String]

    var body: some View {
        VStack(spacing: 20) {
            Text("选择头像")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 28)

            // Preset avatars grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                // Photo picker option (plus icon, same as CreateTargetSheet)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 64, height: 64)
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(presetAvatars, id: \.self) { url in
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color(.systemGray5))
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(selectedAvatarUrl == url && customAvatarData == nil ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        customAvatarData = nil
                        selectedAvatarUrl = url
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Gender Picker Sheet

struct GenderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedGender: EditTargetSheet.Gender

    var body: some View {
        VStack(spacing: 20) {
            Text("选择性别")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 28)

            HStack(spacing: 20) {
                ForEach(EditTargetSheet.Gender.allCases, id: \.self) { gender in
                    GenderOptionView(
                        gender: gender,
                        isSelected: selectedGender == gender
                    )
                    .onTapGesture {
                        selectedGender = gender
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }
}

// Gender option view (matches CreateTargetSheet.GenderOption)
private struct GenderOptionView: View {
    let gender: EditTargetSheet.Gender
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? gender.color.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 72, height: 72)

                Image(systemName: gender.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? gender.color : .secondary)
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? gender.color : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)

            Text(gender.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? gender.color : .secondary)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Status Picker Sheet

struct StatusPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: Constants.RelationshipStatus

    var body: some View {
        VStack(spacing: 20) {
            Text("选择关系类型")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 28)

            // Horizontal scroll sticker picker (same as CreateTargetSheet)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Constants.RelationshipStatus.allCases, id: \.self) { status in
                        StatusStickerView(
                            status: status,
                            isSelected: selectedStatus == status
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedStatus = status
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }
}

// Status sticker view (matches CreateTargetSheet.StatusStickerItem)
private struct StatusStickerView: View {
    let status: Constants.RelationshipStatus
    let isSelected: Bool

    private var stickerImage: String {
        switch status {
        case .pursuing: return "heart.circle.fill"
        case .dating: return "heart.fill"
        case .friend: return "face.smiling.fill"
        case .complicated: return "questionmark.circle.fill"
        case .ended: return "heart.slash.fill"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(isSelected ? 0.2 : 0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: stickerImage)
                    .font(.system(size: 28))
                    .foregroundColor(status.color)
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? status.color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)

            Text(status.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? status.color : .secondary)
        }
        .frame(width: 72)
    }
}

#Preview {
    EditTargetSheet(target: .constant(Target(
        id: UUID(),
        name: "Test Person",
        avatarUrl: nil,
        currentStatus: "dating",
        profileData: ProfileData(tags: ["可爱", "聪明"]),
        preferences: Preferences(),
        memoryCount: 0,
        createdAt: Date(),
        updatedAt: Date()
    )))
}
