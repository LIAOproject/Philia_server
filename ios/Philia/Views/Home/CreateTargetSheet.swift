//
//  CreateTargetSheet.swift
//  Philia
//
//  Sheet for creating a new target
//

import SwiftUI
import PhotosUI

struct CreateTargetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 1
    @State private var name = ""
    @State private var selectedGender: Gender = .male
    @State private var selectedStatus: Constants.RelationshipStatus? = nil
    @State private var selectedAvatarUrl: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var customAvatarData: Data? = nil
    @State private var imageToCrop: UIImage? = nil
    @State private var showImageCropper = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var onCreated: ((Target) -> Void)?

    // Gender options
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

    // Micah style flat cartoon avatars using DiceBear (PNG format for iOS compatibility)
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

    private var sheetHeight: CGFloat {
        switch currentStep {
        case 1: return 300  // Gender selection
        case 2: return 300  // Relationship type
        default: return 400 // Avatar & name
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Large title
            Text("新建一个对象")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 28)

            switch currentStep {
            case 1:
                step1GenderContent
            case 2:
                step2RelationshipContent
            default:
                step3AvatarContent
            }
        }
        .padding()
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem = newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    imageToCrop = image
                    showImageCropper = true
                }
                selectedPhotoItem = nil  // Reset to allow re-selection
            }
        }
        .fullScreenCover(isPresented: $showImageCropper) {
            if let image = imageToCrop {
                ImageCropperSheet(image: image) { croppedData in
                    customAvatarData = croppedData
                    selectedAvatarUrl = nil
                }
            }
        }
    }

    // MARK: - Step 1: Gender Selection
    private var step1GenderContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                Text("选择ta的性别")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 20) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        GenderOption(
                            gender: gender,
                            isSelected: selectedGender == gender
                        )
                        .onTapGesture {
                            selectedGender = gender
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()

            // Next button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep = 2
                }
            }) {
                Text("下一步")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Step 2: Relationship Type
    private var step2RelationshipContent: some View {
        Group {
            // Relationship status picker
            VStack(alignment: .leading, spacing: 10) {
                Text("选择你们的关系类型")
                    .font(.headline)
                    .foregroundColor(.primary)

                RelationshipStatusPicker(selectedStatus: $selectedStatus)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = 1
                    }
                }) {
                    Text("上一步")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = 3
                    }
                }) {
                    Text("下一步")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedStatus != nil ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedStatus == nil)
            }
        }
    }

    // Check if name is valid (2-6 Chinese chars or equivalent English, no special symbols)
    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Check for special symbols (only allow Chinese, letters, numbers)
        let allowedPattern = "^[\\u4e00-\\u9fa5a-zA-Z0-9]+$"
        guard trimmed.range(of: allowedPattern, options: .regularExpression) != nil else { return false }

        // Count character length (Chinese = 2, others = 1)
        var length = 0
        for char in trimmed {
            if char.isASCII {
                length += 1
            } else {
                length += 2  // Chinese characters count as 2
            }
        }

        return length >= 2 && length <= 12  // 2-6 Chinese chars = 4-12 length units
    }

    // Check if avatar is selected
    private var isAvatarSelected: Bool {
        selectedAvatarUrl != nil || customAvatarData != nil
    }

    // Can create target
    private var canCreate: Bool {
        isNameValid && isAvatarSelected && selectedStatus != nil && !isCreating
    }

    // MARK: - Step 3: Avatar & Name
    private var step3AvatarContent: some View {
        Group {
            // Subtitle
            Text("设置ta的头像和名称")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Avatar selection - horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Custom photo picker (first position)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack {
                            if let data = customAvatarData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor, lineWidth: 3)
                                    )
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    )
                            }
                        }
                    }

                    // Preset avatars
                    ForEach(presetAvatars, id: \.self) { url in
                        AvatarOption(
                            url: url,
                            isSelected: selectedAvatarUrl == url && customAvatarData == nil
                        )
                        .onTapGesture {
                            customAvatarData = nil
                            selectedAvatarUrl = url
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            // Name input
            VStack(alignment: .leading, spacing: 6) {
                TextField("给Ta取一个名字", text: $name)
                    .font(.title3)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: name) { newValue in
                        // Filter out special characters as user types
                        let filtered = newValue.filter { char in
                            char.isLetter || char.isNumber || char.isWhitespace
                        }
                        if filtered != newValue {
                            name = filtered
                        }
                    }

                Text("2~6个汉字或等长英文")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = 2
                    }
                }) {
                    Text("上一步")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }

                Button(action: {
                    Task { await createTarget() }
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isCreating ? "创建中..." : "创建")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canCreate ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canCreate)
            }
        }
    }

    private func createTarget() async {
        guard let status = selectedStatus else { return }

        isCreating = true
        errorMessage = nil

        do {
            let target = try await TargetService.shared.createTarget(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status.rawValue,
                avatarUrl: selectedAvatarUrl
            )

            // Save custom avatar locally if selected
            if let avatarData = customAvatarData {
                AvatarCache.shared.saveAvatar(data: avatarData, for: target.id)
            }

            onCreated?(target)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}

// MARK: - Gender Option (性别选项)

struct GenderOption: View {
    let gender: CreateTargetSheet.Gender
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

// MARK: - Avatar Option (头像选项)

struct AvatarOption: View {
    let url: String
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                    )
            default:
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(ProgressView())
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Relationship Status Picker (贴纸风格横向滚动)

struct RelationshipStatusPicker: View {
    @Binding var selectedStatus: Constants.RelationshipStatus?

    private let itemWidth: CGFloat = 80

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Constants.RelationshipStatus.allCases, id: \.self) { status in
                        StatusStickerItem(
                            status: status,
                            isSelected: selectedStatus == status
                        )
                        .id(status)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedStatus = status
                            }
                            // 触感反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedStatus) { newValue in
                if let status = newValue {
                    withAnimation {
                        proxy.scrollTo(status, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Status Sticker Item (贴纸风格)

struct StatusStickerItem: View {
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
            // Sticker icon
            ZStack {
                // Background circle
                Circle()
                    .fill(status.color.opacity(isSelected ? 0.2 : 0.1))
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: stickerImage)
                    .font(.system(size: 28))
                    .foregroundColor(status.color)
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? status.color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)

            // Label
            Text(status.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? status.color : .secondary)
        }
        .frame(width: 72)
    }
}

#Preview {
    CreateTargetSheet()
}
