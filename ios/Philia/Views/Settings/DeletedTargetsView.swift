//
//  DeletedTargetsView.swift
//  Philia
//
//  View for managing deleted targets (restore or permanent delete)
//

import SwiftUI

struct DeletedTargetsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var deletedTargets: [DeletedTarget] = []
    @State private var targetToRestore: DeletedTarget?
    @State private var targetToDelete: DeletedTarget?
    @State private var showRestoreAlert = false
    @State private var showDeleteAlert = false
    @State private var isRestoring = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var onTargetRestored: (() -> Void)?

    var body: some View {
        List {
            if deletedTargets.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("没有已删除的对象")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("删除的对象会在这里保留30天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    ForEach(deletedTargets) { deletedTarget in
                        DeletedTargetRow(
                            deletedTarget: deletedTarget,
                            onRestore: {
                                targetToRestore = deletedTarget
                                showRestoreAlert = true
                            },
                            onDelete: {
                                targetToDelete = deletedTarget
                                showDeleteAlert = true
                            }
                        )
                    }
                } header: {
                    Text("已删除的对象")
                } footer: {
                    Text("已删除的对象将在30天后自动永久删除")
                }
            }
        }
        .navigationTitle("已删除")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDeletedTargets()
        }
        .alert("恢复对象", isPresented: $showRestoreAlert) {
            Button("取消", role: .cancel) {
                targetToRestore = nil
            }
            Button("恢复") {
                if let target = targetToRestore {
                    restoreTarget(target)
                }
            }
        } message: {
            if let target = targetToRestore {
                Text("确定要恢复「\(target.target.name)」吗？")
            }
        }
        .alert("永久删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                targetToDelete = nil
            }
            Button("永久删除", role: .destructive) {
                if let target = targetToDelete {
                    permanentlyDeleteTarget(target)
                }
            }
        } message: {
            if let target = targetToDelete {
                Text("确定要永久删除「\(target.target.name)」吗？此操作无法撤销。")
            }
        }
        .overlay {
            if isRestoring || isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
            }
        }
    }

    private func loadDeletedTargets() {
        deletedTargets = DeletedTargetCache.shared.getRecoverableTargets()
    }

    private func restoreTarget(_ deletedTarget: DeletedTarget) {
        isRestoring = true

        Task {
            do {
                // Re-create the target on the server
                let restoredTarget = try await TargetService.shared.createTarget(
                    name: deletedTarget.target.name,
                    status: deletedTarget.target.currentStatus,
                    avatarUrl: deletedTarget.target.avatarUrl
                )

                // If there's a local avatar, migrate it to the new target ID
                if AvatarCache.shared.hasLocalAvatar(for: deletedTarget.target.id),
                   let avatarData = AvatarCache.shared.loadAvatar(for: deletedTarget.target.id) {
                    AvatarCache.shared.saveAvatar(data: avatarData, for: restoredTarget.id)
                }

                // Remove from deleted cache
                DeletedTargetCache.shared.removeFromCache(targetId: deletedTarget.target.id)

                await MainActor.run {
                    isRestoring = false
                    loadDeletedTargets()
                    onTargetRestored?()
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func permanentlyDeleteTarget(_ deletedTarget: DeletedTarget) {
        // Remove from local cache (no server call needed since it's already deleted there)
        DeletedTargetCache.shared.removeFromCache(targetId: deletedTarget.target.id)
        loadDeletedTargets()
    }
}

// MARK: - Deleted Target Row

struct DeletedTargetRow: View {
    let deletedTarget: DeletedTarget
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImageView(
                url: deletedTarget.target.avatarUrl,
                placeholder: "person.crop.circle.fill",
                size: 48,
                targetId: deletedTarget.target.id
            )
            .opacity(0.6)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(deletedTarget.target.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    StatusBadge(status: deletedTarget.target.currentStatus)

                    Text("剩余 \(deletedTarget.daysRemaining) 天")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DeletedTargetsView()
    }
}
