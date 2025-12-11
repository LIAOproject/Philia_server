//
//  StatusBadge.swift
//  Philia
//
//  Relationship status badge component
//

import SwiftUI

struct StatusBadge: View {
    let status: String

    private var relationshipStatus: Constants.RelationshipStatus {
        Constants.RelationshipStatus(rawValue: status) ?? .pursuing
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(relationshipStatus.emoji)
                .font(.caption2)
            Text(relationshipStatus.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(relationshipStatus.color.opacity(0.15))
        .foregroundColor(relationshipStatus.color)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 10) {
        StatusBadge(status: "pursuing")
        StatusBadge(status: "dating")
        StatusBadge(status: "friend")
        StatusBadge(status: "complicated")
        StatusBadge(status: "ended")
    }
    .padding()
}
