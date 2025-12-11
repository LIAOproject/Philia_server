//
//  ConsultTab.swift
//  Philia
//
//  Consult tab - chatbot list and chat interface
//

import SwiftUI

struct ConsultTab: View {
    let target: Target

    @State private var chatbots: [Chatbot] = []
    @State private var mentors: [Mentor] = []
    @State private var isLoading = true
    @State private var isRefreshing = false  // Background refresh (no loading spinner)
    @State private var errorMessage: String?
    @State private var showMentorSelector = false
    @State private var selectedChatbot: Chatbot?

    private let cache = TargetDataCache.shared

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "加载对话中...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await loadData() }
                    }
                }
            } else if chatbots.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "还没有对话",
                    message: "开始与AI导师的对话"
                )
            } else {
                List {
                    ForEach(chatbots) { chatbot in
                        ChatbotRow(chatbot: chatbot)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedChatbot = chatbot
                            }
                    }
                    .onDelete(perform: deleteChatbot)
                }
                .listStyle(.plain)
                .padding(.bottom, 80)
            }

            // Floating bottom button
            VStack {
                Spacer()
                Button(action: { showMentorSelector = true }) {
                    Text("开启咨询")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showMentorSelector) {
            MentorSelectorSheet(
                mentors: mentors,
                onSelect: { mentor in
                    Task { await createChatbot(mentorId: mentor.id) }
                }
            )
        }
        .fullScreenCover(item: $selectedChatbot) { chatbot in
            NavigationStack {
                ChatView(chatbot: chatbot)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData(forceRefresh: Bool = false) async {
        // 1. Try to show cached data first (instant, no loading)
        var hasCachedData = false
        var needMentorRefresh = false

        if !forceRefresh {
            if let cachedChatbots = cache.getChatbots(targetId: target.id) {
                chatbots = cachedChatbots
                hasCachedData = true
            }
            if let cachedMentors = cache.getMentors() {
                mentors = cachedMentors
                hasCachedData = true
                // Force refresh if any mentor is missing icon_url
                if cachedMentors.contains(where: { $0.iconUrl == nil }) {
                    needMentorRefresh = true
                    cache.invalidateMentors()
                }
            }
        }

        if hasCachedData && !needMentorRefresh {
            isLoading = false

            // If both caches are fresh, skip network request
            if cache.isChatbotsFresh(targetId: target.id) && cache.isMentorsFresh() {
                return
            }

            // Otherwise, refresh in background
            isRefreshing = true
        } else {
            isLoading = chatbots.isEmpty
        }

        errorMessage = nil

        // 2. Fetch fresh data from API
        do {
            async let chatbotsResponse = ChatService.shared.listChatbots(targetId: target.id)
            async let mentorsResponse = ChatService.shared.listMentors()

            let (chatbotsResult, mentorsResult) = try await (chatbotsResponse, mentorsResponse)

            // Update UI and cache
            chatbots = chatbotsResult.items
            mentors = mentorsResult.items
            cache.saveChatbots(chatbotsResult.items, targetId: target.id)
            cache.saveMentors(mentorsResult.items)
        } catch {
            // Only show error if we have no cached data
            if chatbots.isEmpty && mentors.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
        isRefreshing = false
    }

    private func createChatbot(mentorId: UUID) async {
        do {
            let chatbot = try await ChatService.shared.createChatbot(
                targetId: target.id,
                mentorId: mentorId
            )
            chatbots.insert(chatbot, at: 0)
            selectedChatbot = chatbot

            // Update cache with new chatbot
            cache.saveChatbots(chatbots, targetId: target.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteChatbot(at offsets: IndexSet) {
        for index in offsets {
            let chatbot = chatbots[index]
            Task {
                do {
                    try await ChatService.shared.deleteChatbot(id: chatbot.id)
                    await MainActor.run {
                        _ = chatbots.remove(at: index)
                        // Update cache after deletion
                        cache.saveChatbots(chatbots, targetId: target.id)
                    }
                } catch {
                    print("Delete failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Chatbot Row

struct ChatbotRow: View {
    let chatbot: Chatbot

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: chatbot.updatedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(url: chatbot.mentorIconUrl, placeholder: "person.crop.circle.fill", size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(chatbot.mentorName ?? "Mentor")
                    .font(.headline)

                HStack {
                    if let count = chatbot.messageCount, count > 0 {
                        Label("\(count) 条消息", systemImage: "message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Mentor Selector Sheet

struct MentorSelectorSheet: View {
    let mentors: [Mentor]
    let onSelect: (Mentor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMentor: Mentor?

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(mentors) { mentor in
                            MentorCard(
                                mentor: mentor,
                                isSelected: selectedMentor?.id == mentor.id
                            )
                            .onTapGesture {
                                selectedMentor = mentor
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for bottom button
                }

                // Bottom button
                VStack {
                    Spacer()
                    Button {
                        if let mentor = selectedMentor {
                            onSelect(mentor)
                            dismiss()
                        }
                    } label: {
                        Text("开始")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedMentor != nil ? Color.accentColor : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(selectedMentor == nil)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false)
                    )
                }
            }
            .navigationTitle("选择导师")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mentor Card

struct MentorCard: View {
    let mentor: Mentor
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(url: mentor.iconUrl, placeholder: "person.crop.circle.fill", size: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mentor.name)
                        .font(.headline)

                    if let styleTag = mentor.styleTag {
                        Text(styleTag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                    }
                }

                Text(mentor.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    ConsultTab(target: Target(
        id: UUID(),
        name: "Test",
        avatarUrl: nil,
        currentStatus: "dating",
        profileData: ProfileData(),
        preferences: Preferences(),
        createdAt: Date(),
        updatedAt: Date()
    ))
}
