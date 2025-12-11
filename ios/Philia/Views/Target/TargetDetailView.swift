//
//  TargetDetailView.swift
//  Philia
//
//  Target detail page with 3 tabs
//

import SwiftUI

struct TargetDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State var target: Target
    @State private var selectedTab = 0
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showEditSheet = false

    var onDeleted: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tab", selection: $selectedTab) {
                Text("资料").tag(0)
                Text("咨询").tag(1)
                Text("分析").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Tab Content
            TabView(selection: $selectedTab) {
                ProfileTab(targetId: target.id)
                    .tag(0)

                ConsultTab(target: target)
                    .tag(1)

                AnalysisTab(target: $target)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showEditSheet = true
                } label: {
                    HStack(spacing: 10) {
                        AsyncImageView(url: target.avatarUrl, placeholder: "person.crop.circle.fill", size: 32, targetId: target.id)

                        Text(target.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        StatusBadge(status: target.currentStatus)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除对象", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditTargetSheet(target: $target)
        }
        .alert("删除对象", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteTarget()
            }
        } message: {
            Text("确定要删除「\(target.name)」吗？\n\n删除后可在设置 > 已删除中恢复（30天内）")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("正在删除...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
            }
        }
    }

    private func deleteTarget() {
        isDeleting = true

        Task {
            do {
                // Save to deleted cache first (for recovery)
                DeletedTargetCache.shared.addDeletedTarget(target)

                // Delete from server
                try await TargetService.shared.deleteTarget(id: target.id)

                await MainActor.run {
                    isDeleting = false
                    onDeleted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // If server delete fails, remove from deleted cache
                    DeletedTargetCache.shared.removeFromCache(targetId: target.id)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TargetDetailView(target: Target(
            id: UUID(),
            name: "Test Person",
            avatarUrl: nil,
            currentStatus: "dating",
            profileData: ProfileData(tags: ["cute", "smart"]),
            preferences: Preferences(likes: ["coffee"], dislikes: ["loud noise"]),
            memoryCount: 5,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
