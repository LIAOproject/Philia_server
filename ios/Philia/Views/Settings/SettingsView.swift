//
//  SettingsView.swift
//  Philia
//
//  Settings and account page
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    @AppStorage(StorageKeys.apiBaseURL) private var apiBaseURL = Constants.defaultAPIBaseURL

    @State private var showAPIURLEditor = false
    @State private var editedAPIURL = ""
    @State private var deletedCount = 0
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showLoginSheet = false

    var onTargetRestored: (() -> Void)?

    var body: some View {
        List {
            // Brand Header - no background, align with avatar in cards below
            Section {
                HStack(spacing: 16) {
                    AppLogoView(size: 64, showGloss: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Philia")
                            .font(.brand(size: 26))
                        Text("情感困惑 · 人际关系 · 女性成长")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            }

            // Account Section
            Section("账号") {
                if let user = authService.currentUser, user.isAppleLinked {
                    // Apple linked user
                    HStack(spacing: 12) {
                        // Avatar
                        if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.headline)

                            HStack(spacing: 4) {
                                Image(systemName: "apple.logo")
                                    .font(.caption)
                                Text("Apple 账号")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Sign out (only for Apple linked users)
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退出登录")
                        }
                    }
                } else {
                    // Guest user - show as "未登录"
                    Button {
                        showLoginSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("未登录")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("点击登录以同步数据")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if authService.isLoading {
                    HStack {
                        ProgressView()
                        Text("处理中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Data Management
            Section("数据管理") {
                NavigationLink {
                    DeletedTargetsView(onTargetRestored: onTargetRestored)
                } label: {
                    HStack {
                        Label("已删除的对象", systemImage: "trash")
                        Spacer()
                        if deletedCount > 0 {
                            Text("\(deletedCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Server Configuration
            Section("服务器") {
                HStack {
                    Text("API 服务器")
                    Spacer()
                    Text(apiBaseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editedAPIURL = apiBaseURL
                    showAPIURLEditor = true
                }

                Button("测试连接") {
                    testConnection()
                }
            }

            // About
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("构建号")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com/LIAOproject/Philia_server")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Debug
            Section("调试") {
                Button("重置 API 地址") {
                    apiBaseURL = Constants.defaultAPIBaseURL
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .alert("API 服务器地址", isPresented: $showAPIURLEditor) {
            TextField("地址", text: $editedAPIURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("取消", role: .cancel) {}
            Button("保存") {
                if !editedAPIURL.isEmpty {
                    apiBaseURL = editedAPIURL
                }
            }
        } message: {
            Text("请输入API服务器地址")
        }
        .onAppear {
            loadDeletedCount()
            autoSignInIfNeeded()
        }
        .confirmationDialog("退出登录", isPresented: $showSignOutConfirm) {
            Button("退出登录", role: .destructive) {
                authService.signOut()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后需要重新登录才能同步数据")
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginSheet()
        }
    }

    // MARK: - Auth Methods

    private func autoSignInIfNeeded() {
        // Auto sign in as guest if not authenticated
        if !authService.isAuthenticated {
            Task {
                try? await authService.signInWithDevice()
            }
        }
    }

    private func loadDeletedCount() {
        deletedCount = DeletedTargetCache.shared.getRecoverableTargets().count
    }

    private func testConnection() {
        Task {
            do {
                let _: TargetListResponse = try await APIClient.shared.request("targets", queryItems: [
                    URLQueryItem(name: "limit", value: "1")
                ])
                showSuccessAlert()
            } catch {
                showErrorAlert(error.localizedDescription)
            }
        }
    }

    private func showSuccessAlert() {
        // Simple alert using UIKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(title: "成功", message: "连接成功！", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
        }
    }

    private func showErrorAlert(_ message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            viewController.present(alert, animated: true)
        }
    }
}

// MARK: - Login Sheet

struct LoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    AppLogoView(size: 80, showGloss: true)

                    Text("登录 Philia")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("登录后可同步数据到云端")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Apple Sign In Button
                VStack(spacing: 16) {
                    Button {
                        linkAppleId()
                    } label: {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                            Text("通过 Apple 登录")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(10)
                    }
                    .disabled(authService.isLoading)

                    if authService.isLoading {
                        HStack {
                            ProgressView()
                            Text("登录中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func linkAppleId() {
        Task {
            do {
                _ = try await authService.linkAppleId()
                dismiss()
            } catch {
                // Error is handled by authService.error
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
