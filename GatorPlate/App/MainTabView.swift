import SwiftUI

/// Main tabs. Owns the session (live posts listener, navigation) for as long as the user is signed in.
struct MainTabView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: MainSession?
    @State private var isPostFlowPresented = false
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
            let session = session ?? MainSession(environment: environment, currentUid: profile.uid)
            self.session = session
            session.start()
        }
        .onDisappear { session?.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: session?.repository.didBecomeActive()
            case .background: session?.repository.didEnterBackground()
            case .inactive: break
            @unknown default: break
            }
        }
    }

    private func tabs(_ session: MainSession) -> some View {
        @Bindable var navigation = session.navigation
        return TabView(selection: $navigation.selectedTab) {
            Tab("Map", systemImage: "map", value: AppNavigation.TabID.map) {
                MapScreen(viewModel: session.map) { isPostFlowPresented = true }
            }
            Tab("Feed", systemImage: "list.bullet", value: AppNavigation.TabID.feed) {
                FeedScreen(viewModel: session.feed) { isPostFlowPresented = true }
            }
            Tab("Settings", systemImage: "gearshape", value: AppNavigation.TabID.settings) {
                SettingsView(profile: profile, onSignOut: signOut)
            }
        }
        .onChange(of: session.repository.activePosts) {
            session.navigation.postsDidChange()
        }
    }

    private func showPostAfterFlow() {
        guard let postId = postToShowAfterFlow else { return }
        postToShowAfterFlow = nil
        session?.navigation.selectPost(id: postId)
    }

    /// Stops the listener first: rules deny reads once the user is signed out.
    private func signOut() {
        session?.stop()
        onSignOut()
    }
}
