//
//  ChatView.swift
//  Philia
//
//  Full-screen chat interface with streaming support
//

import SwiftUI

struct ChatView: View {
    let chatbot: Chatbot

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var streamingContent = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        // Streaming message
                        if !streamingContent.isEmpty {
                            ChatBubble(
                                message: ChatMessage(
                                    id: UUID(),
                                    chatbotId: chatbot.id,
                                    role: "assistant",
                                    content: streamingContent,
                                    createdAt: Date()
                                ),
                                isStreaming: true
                            )
                            .id("streaming")
                        }

                        if isLoading && messages.isEmpty {
                            LoadingView(message: "加载消息中...")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: streamingContent) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("输入消息...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .disabled(isSending)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty || isSending ? .secondary : .accentColor)
                }
                .disabled(inputText.isEmpty || isSending)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(chatbot.mentorName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AsyncImageView(url: chatbot.mentorIconUrl, size: 28)
                    Text(chatbot.mentorName ?? "Chat")
                        .font(.headline)
                }
            }
        }
        .alert("错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadMessages()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if !streamingContent.isEmpty {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func loadMessages() async {
        isLoading = true

        do {
            let response = try await ChatService.shared.listMessages(chatbotId: chatbot.id)
            messages = response.items
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sendMessage() {
        guard !inputText.isEmpty, !isSending else { return }

        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        isSending = true

        // Add user message immediately
        let userMessage = ChatMessage(
            id: UUID(),
            chatbotId: chatbot.id,
            role: "user",
            content: messageText,
            createdAt: Date()
        )
        messages.append(userMessage)

        // Start streaming
        Task {
            await ChatService.shared.sendMessageStream(
                chatbotId: chatbot.id,
                message: messageText,
                onChunk: { chunk in
                    Task { @MainActor in
                        streamingContent += chunk
                    }
                },
                onComplete: {
                    Task { @MainActor in
                        // Convert streaming content to message
                        if !streamingContent.isEmpty {
                            let assistantMessage = ChatMessage(
                                id: UUID(),
                                chatbotId: chatbot.id,
                                role: "assistant",
                                content: streamingContent,
                                createdAt: Date()
                            )
                            messages.append(assistantMessage)
                        }
                        streamingContent = ""
                        isSending = false
                    }
                },
                onError: { error in
                    Task { @MainActor in
                        errorMessage = error.localizedDescription
                        streamingContent = ""
                        isSending = false
                    }
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(chatbot: Chatbot(
            id: UUID(),
            targetId: UUID(),
            mentorId: UUID(),
            title: "Test Chat",
            status: "active",
            createdAt: Date(),
            updatedAt: Date(),
            mentorName: "Test Mentor"
        ))
    }
}
