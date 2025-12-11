//
//  ChatBubble.swift
//  Philia
//
//  Chat message bubble component
//

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    if !message.isUser {
                        // Show streaming indicator
                        if isStreaming {
                            TypingIndicator()
                        }
                    }

                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(18)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.content
                            }) {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                        }
                }

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatBubble(message: ChatMessage(
            id: UUID(),
            chatbotId: UUID(),
            role: "user",
            content: "Hello, how are you?",
            createdAt: Date()
        ))

        ChatBubble(message: ChatMessage(
            id: UUID(),
            chatbotId: UUID(),
            role: "assistant",
            content: "I'm doing great! How can I help you today?",
            createdAt: Date()
        ))

        ChatBubble(message: ChatMessage(
            id: UUID(),
            chatbotId: UUID(),
            role: "assistant",
            content: "Typing...",
            createdAt: Date()
        ), isStreaming: true)
    }
    .padding()
}
