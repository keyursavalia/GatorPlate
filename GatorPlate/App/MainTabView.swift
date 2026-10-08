import SwiftUI

/// Main tabs. Owns the session (live posts listener, navigation, alerts) for as long as the user is signed in.
struct MainTabView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: MainSession?
    @State private var isPostFlowPresented = false
    @State private var isSigningOut = false
    /// Set by "View on map"; opened once the post flow cover has finished dismissing.
    @State private var postToShowAfterFlow: String?

    var body: some View {
        Group {
            if let session {
                tabs(session)
            } else {
                Color.clear
            }
        }
        .fullScreenCover(isPresented: $isPostFlowPresented, onDismiss: showPostAfterFlow) {
            PostFlowCoordinator(camera: environment.camera, analyzer: environment.analyzer,
                                posts: environment.posts, location: environment.location,
                                author: PostAuthor(profile: profile)) { postId in
                postToShowAfterFlow = postId
            }
        }
        .task {
            // Runs on every appear: the post flow cover can make this view disappear and come back.
            let session = session ?? MainSession(environment: environment, profile: profile)
            self.session = session
            session.start()
            openTappedAlert()
        }
        .onDisappear { session?.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                session?.repository.didBecomeActive()
                Task { await environment.notifications.refreshAuthorization() }
            case .background: session?.repository.didEnterBackground()
            case .inactive: break
            @unknown default: break
            }
        }
        .onChange(of: environment.notifications.pendingOpenPostId) {
            openTappedAlert()
        }
    }

    private func tabs(_ session: MainSession) -> some View {
        @Bindable var navigation = session.navigation
        return TabView(selection: $navigation.selectedTab) {
            Tab("Map", systemImage: "map", value: AppNavigation.TabID.map) {
                MapScreen(viewModel: session.map) { isPostFlowPresented = true }
            }
            Tab("Feed", systemImage: "list.bullet", value: AppNavigation.TabID.feed) {
                FeedScreen(viewModel: session.feed, alerts: session.settings) { isPostFlowPresented = true }
            }
            Tab("Settings", systemImage: "gearshape", value: AppNavigation.TabID.settings) {
                SettingsView(viewModel: session.settings, profile: profile, isSigningOut: isSigningOut,
                             onSignOut: signOut)
            }
        }
        .onChange(of: session.repository.activePosts) {
            session.navigation.postsDidChange()
        }
        .onChange(of: session.repository.phase) {
            session.navigation.postsDidChange()
        }
    }

    /// Opens the post from a tapped alert. Waits while the post flow is open so a draft is never discarded.
    private func openTappedAlert() {
        guard let session, !isPostFlowPresented,
              let postId = environment.notifications.consumePendingOpen() else { return }
        session.navigation.selectPost(id: postId, missingNotice: AppNavigation.alertPostUnavailableNotice)
    }

    private func showPostAfterFlow() {
        if let postId = postToShowAfterFlow {
            postToShowAfterFlow = nil
            session?.navigation.selectPost(id: postId)
        }
        openTappedAlert()
    }

    /// Stops the listener and removes the alert registration first: rules deny both once signed out.
    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            await session?.prepareSignOut()
            isSigningOut = false
            onSignOut()
        }
    }
}
