//
//  TargetCard.swift
//  Philia
//
//  Target card component for list display
//

import SwiftUI

struct TargetCard: View {
    let target: Target
    var isPinned: Bool = false  // Reserved for future use

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: target.updatedAt, relativeTo: Date())
    }

    private let cardPadding: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar (top-aligned with name)
            AsyncImageView(url: target.avatarUrl, placeholder: "person.crop.circle.fill", size: 56, targetId: target.id)

            // Info content
            VStack(alignment: .leading, spacing: 6) {
                // Name and status badge (same line as avatar top)
                HStack {
                    Text(target.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    StatusBadge(status: target.currentStatus)

                    Spacer()
                }

                // Tags
                if let tags = target.profileData.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags.prefix(4), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Memory count
                if let memoryCount = target.memoryCount, memoryCount > 0 {
                    Label("\(memoryCount) 条记忆", systemImage: "photo.stack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(cardPadding)
        .frame(minHeight: 88)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(alignment: .bottomTrailing) {
            // Timestamp fixed at bottom right corner
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, cardPadding)
                .padding(.bottom, cardPadding)
        }
        .overlay(alignment: .topTrailing) {
            // Pin icon for pinned cards
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
                    .padding(.trailing, cardPadding - 4)
                    .padding(.top, cardPadding - 4)
            }
        }
    }
}

#Preview {
    TargetCard(target: Target(
        id: UUID(),
        name: "Test Person",
        avatarUrl: nil,
        currentStatus: "dating",
        profileData: ProfileData(tags: ["cute", "smart", "funny"]),
        preferences: Preferences(),
        memoryCount: 5,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .padding()
}
