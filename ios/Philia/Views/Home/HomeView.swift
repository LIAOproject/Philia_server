//
//  HomeView.swift
//  Philia
//
//  Main home screen with target list - iOS Fitness app style
//

import SwiftUI

// PreferenceKey to collect card positions
struct CardPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// PreferenceKey for scroll offset
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HomeView: View {
    @State private var targets: [Target] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var showSettings = false
    @State private var pinnedIds: Set<UUID> = []

    // Animation state
    @State private var flyingTarget: Target? = nil
    @State private var flyingCardSourceRect: CGRect = .zero
    @State private var flyingCardDestRect: CGRect = .zero
    @State private var isAnimatingFly = false
    @State private var cardPositions: [UUID: CGRect] = [:]
    @State private var listTopY: CGFloat = 0

    // Scroll tracking
    @State private var scrollOffset: CGFloat = 0

    // Title animation thresholds
    private let titleCollapseStart: CGFloat = 0
    private let titleCollapseEnd: CGFloat = 50

    // Calculate title animation progress (0 = expanded, 1 = collapsed)
    private var titleProgress: CGFloat {
        let progress = (scrollOffset - titleCollapseStart) / (titleCollapseEnd - titleCollapseStart)
        return min(max(progress, 0), 1)
    }

    // Sorted targets: pinned first (sorted by time), then non-pinned (sorted by time)
    private var sortedTargets: [Target] {
        targets.sorted { t1, t2 in
            let isPinned1 = pinnedIds.contains(t1.id)
            let isPinned2 = pinnedIds.contains(t2.id)
            if isPinned1 != isPinned2 {
                return isPinned1  // Pinned ones come first
            }
            // Both pinned or both not pinned: sort by update time
            return t1.updatedAt > t2.updatedAt
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1 (lowest): Background with gradient
                backgroundGradient
                    .ignoresSafeArea()

                // Layer 2: Content (cards can scroll to top)
                if isLoading {
                    VStack {
                        Spacer()
                        LoadingView(message: "加载中...")
                        Spacer()
                    }
                } else if let error = errorMessage {
                    VStack {
                        Spacer()
                        errorView(error: error)
                        Spacer()
                    }
                } else if targets.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "还没有对象",
                        message: "点击下方按钮添加你想了解的人",
                        actionTitle: "添加对象",
                        action: { showCreateSheet = true }
                    )
                } else {
                    targetListView(geometry: geometry)
                }

                // Layer 3: Top gradient overlay (symmetric to bottom, fade in on scroll)
                VStack {
                    LinearGradient(
                        colors: [
                            Color(.systemBackground).opacity(0.95),
                            Color(.systemBackground).opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)

                    Spacer()
                }
                .ignoresSafeArea()
                .opacity(min(Double(titleProgress) * 2.0, 1.0))

                // Layer 3: Bottom gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(.systemBackground).opacity(0),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()

                // Layer 4: Navigation bar (Philia + avatar) - highest
                VStack {
                    navBar(geometry: geometry)
                    Spacer()
                }

                // Layer 5: Floating add button at bottom center
                floatingAddButton

                // Layer 6 (highest): Flying card overlay
                if let target = flyingTarget, isAnimatingFly {
                    TargetCard(target: target, isPinned: true)
                        .frame(width: flyingCardSourceRect.width)
                        .position(
                            x: flyingCardDestRect.midX,
                            y: flyingCardDestRect.midY
                        )
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                        .zIndex(1000)
                        .transition(.identity)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreateSheet) {
            CreateTargetSheet(onCreated: { newTarget in
                targets.insert(newTarget, at: 0)
            })
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(onTargetRestored: {
                    // Reload targets when a target is restored
                    Task { await loadTargets() }
                })
            }
        }
        .task {
            await loadTargets()
        }
        .onAppear {
            pinnedIds = PinnedTargetCache.shared.getPinnedIds()
        }
    }

    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            // Base dark background
            Color(.systemBackground)

            // Top gradient (pink/purple like Fitness app)
            VStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 0.2, blue: 0.4).opacity(0.6),
                        Color(red: 0.6, green: 0.2, blue: 0.5).opacity(0.4),
                        Color(.systemBackground).opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)

                Spacer()
            }
        }
    }

    // MARK: - Navigation Bar with Collapsing Title
    @ViewBuilder
    private func navBar(geometry: GeometryProxy) -> some View {
        ZStack {
            // Collapsed title (centered, smaller)
            Text("Philia")
                .font(.brand(size: 20))
                .opacity(Double(titleProgress))
                .frame(maxWidth: .infinity)

            // Expanded title (left-aligned, larger)
            HStack(alignment: .center) {
                Text("Philia")
                    .font(.brand(size: 34))
                    .opacity(Double(1.0 - titleProgress))

                Spacer()
            }

            // Single avatar button - always visible, fixed size (same as add button), topmost layer
            HStack {
                Spacer()
                Button(action: { showSettings = true }) {
                    AppLogoView(size: 56, isCircle: true)
                }
                .zIndex(100)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("出错了")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await loadTargets() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Target List View
    @ViewBuilder
    private func targetListView(geometry: GeometryProxy) -> some View {
        ScrollView {
            // Scroll offset tracker
            Color.clear
                .frame(height: 0)
                .background(
                    GeometryReader { scrollGeometry in
                        let minY = scrollGeometry.frame(in: .named("scroll")).minY
                        return Color.clear
                            .preference(key: ScrollOffsetKey.self, value: minY)
                    }
                )
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    let offset = 0.0 - value
                    scrollOffset = offset > 0 ? offset : 0
                }

            LazyVStack(spacing: 12) {
                ForEach(sortedTargets) { target in
                    let isPinned = pinnedIds.contains(target.id)
                    let isFlying = flyingTarget?.id == target.id && isAnimatingFly

                    NavigationLink(destination: TargetDetailView(
                        target: target,
                        onDeleted: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                targets.removeAll { $0.id == target.id }
                                pinnedIds.remove(target.id)
                                PinnedTargetCache.shared.unpin(target.id)
                            }
                        }
                    )) {
                        TargetCard(target: target, isPinned: isPinned)
                            .opacity(isFlying ? 0 : 1)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: CardPositionPreferenceKey.self,
                                            value: [target.id: geo.frame(in: .global)]
                                        )
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button {
                            handlePinAction(target: target)
                        } label: {
                            Label(
                                isPinned ? "取消置顶" : "置顶",
                                systemImage: isPinned ? "pin.slash.fill" : "pin.fill"
                            )
                        }
                    }
                    .id(target.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 80) // Space for navbar (Philia + avatar)
            .padding(.bottom, 120) // Space for floating button + bottom gradient
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(CardPositionPreferenceKey.self) { positions in
            cardPositions = positions
        }
        .refreshable {
            await refreshTargets()
        }
    }

    // MARK: - Floating Add Button
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Pin Action
    private func handlePinAction(target: Target) {
        let isPinned = pinnedIds.contains(target.id)

        if isPinned {
            // Unpin: simple animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                pinnedIds.remove(target.id)
                PinnedTargetCache.shared.unpin(target.id)
            }
        } else {
            // Pin: fly animation
            guard let sourceRect = cardPositions[target.id] else {
                // Fallback: simple animation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    pinnedIds.insert(target.id)
                    PinnedTargetCache.shared.pin(target.id)
                }
                return
            }

            // Calculate destination (first card position)
            let destRect = CGRect(
                x: sourceRect.minX,
                y: listTopY + 6,  // 6 is the top inset
                width: sourceRect.width,
                height: sourceRect.height
            )

            // Setup flying card at source position
            flyingTarget = target
            flyingCardSourceRect = sourceRect
            flyingCardDestRect = sourceRect  // Start at source
            isAnimatingFly = true

            // Simultaneously: animate flying card AND reorder list
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                flyingCardDestRect = destRect
                pinnedIds.insert(target.id)
                PinnedTargetCache.shared.pin(target.id)
            }

            // Cleanup after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isAnimatingFly = false
                flyingTarget = nil
            }
        }
    }

    private func togglePin(_ targetId: UUID) {
        if pinnedIds.contains(targetId) {
            pinnedIds.remove(targetId)
            PinnedTargetCache.shared.unpin(targetId)
        } else {
            pinnedIds.insert(targetId)
            PinnedTargetCache.shared.pin(targetId)
        }
    }

    private func loadTargets(isRefresh: Bool = false) async {
        // Only show loading indicator on initial load (when targets is empty)
        let isInitialLoad = targets.isEmpty && !isRefresh
        if isInitialLoad {
            isLoading = true
        }
        errorMessage = nil

        do {
            let response = try await TargetService.shared.listTargets()
            targets = response.items

            // Preload data for first few targets in background
            // This ensures instant loading when user taps a card
            TargetDataCache.shared.preloadTargets(sortedTargets, limit: 5)
        } catch is CancellationError {
            // Ignore cancellation errors - these can happen during pull-to-refresh
            // when the view updates, but the request should have completed
        } catch {
            // Only show error on initial load, not during refresh
            if isInitialLoad {
                errorMessage = error.localizedDescription
            }
        }

        if isInitialLoad {
            isLoading = false
        }
    }

    /// Refresh targets - wraps the network call to handle cancellation gracefully
    @MainActor
    private func refreshTargets() async {
        // Use withTaskCancellationHandler to ensure we still process results
        // even if the task gets a cancellation signal
        do {
            let response = try await withTaskCancellationHandler {
                try await TargetService.shared.listTargets()
            } onCancel: {
                // Task was cancelled, but we'll let the request complete
                // The result will still be processed if it arrives
            }
            targets = response.items
            TargetDataCache.shared.preloadTargets(sortedTargets, limit: 5)
        } catch is CancellationError {
            // If truly cancelled before completion, just ignore
            // User can pull to refresh again
        } catch {
            // Silently fail on refresh - user can try again
            print("Refresh failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
