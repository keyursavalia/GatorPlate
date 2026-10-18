import OSLog
import SwiftUI

/// Main tabs for guests and accounts. Owns the session (live posts listener, navigation, alerts) for the current
/// uid and asks for an account only when a guest wants to post (or taps Join / Sign in in Settings).
struct MainTabView: View {
    let authSession: AuthSession
    let auth: AuthViewModel

    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: MainSession?
    @State private var isPostFlowPresented = false
    @State private var isSigningOut = false
    /// Set by "View on map"; opened once the post flow cover has finished dismissing.
    @State private var postToShowAfterFlow: String?
    @State private var accountFlow: AccountFlowView.Start?
    /// The account flow was opened from the post button: continue to the post flow once it closes.
    @State private var opensPostAfterAccountFlow = false
    @State private var notice: String?

    private var profile: UserProfile { authSession.profile }

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
        .fullScreenCover(item: $accountFlow, onDismiss: continueAfterAccountFlow) { start in
            AccountFlowView(start: start, viewModel: auth,
                            prepareSwitch: { await session?.prepareSignOut() },
                            restore: { session?.start() },
                            onClose: { accountFlow = nil })
        }
        .overlay(alignment: .top) {
            if let notice {
                Toast(message: notice, systemImage: "info.circle.fill") { self.notice = nil }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: profile.uid) {
            // Runs on every appear (the post flow cover can make this view disappear and come back) and when a
            // guest signs in to an account (a new uid gets a new session).
            if let current = session, current.uid != profile.uid {
                current.stop()
                session = nil
            }
            let session = session ?? MainSession(environment: environment, profile: profile)
            self.session = session
            session.start()
            openTappedAlert()
            if let message = auth.consumeNotice() { notice = message }
        }
        .onDisappear { session?.stop() }
        .onChange(of: authSession.canPost) { _, canPost in
            guard canPost, let start = accountFlow else { return }
            opensPostAfterAccountFlow = start == .post
            accountFlow = nil
        }
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
        .onChange(of: environment.notifications.pendingAlert) {
            openTappedAlert()
        }
    }

    private func tabs(_ session: MainSession) -> some View {
        @Bindable var navigation = session.navigation
        return TabView(selection: $navigation.selectedTab) {
            Tab("Map", systemImage: "map", value: AppNavigation.TabID.map) {
                MapScreen(viewModel: session.map, permissions: session.permissions, onPostFood: requestPost)
            }
            Tab("Feed", systemImage: "list.bullet", value: AppNavigation.TabID.feed) {
                FeedScreen(viewModel: session.feed, onPostFood: requestPost)
            }
            Tab("Settings", systemImage: "gearshape", value: AppNavigation.TabID.settings) {
                SettingsView(session: session, authSession: authSession, isSigningOut: isSigningOut,
                             passwordReset: auth.passwordReset,
                             onRequestAccount: { accountFlow = $0 }, onSignOut: signOut,
                             onDeleteAccount: deleteAccount)
            }
        }
        .onChange(of: session.repository.activePosts) {
            session.navigation.postsDidChange()
        }
        .onChange(of: session.repository.phase) {
            session.navigation.postsDidChange()
        }
        .onChange(of: session.repository.serverSnapshotCount) {
            session.navigation.postsDidChange()
        }
        .onChange(of: permissionConditions(session), initial: true) { _, conditions in
            session.permissions.update(conditions)
        }
    }

    /// The first-run prompts wait for the Map on screen, the app active, nothing covering it and no tapped alert.
    private func permissionConditions(_ session: MainSession) -> FirstRunPermissions.Conditions {
        FirstRunPermissions.Conditions(
            mapVisible: session.map.isVisible && session.navigation.selectedTab == .map,
            sceneActive: scenePhase == .active,
            coverOrSheetOpen: isPostFlowPresented || accountFlow != nil || session.map.selectedPost != nil,
            alertPending: environment.notifications.pendingAlert != nil || session.navigation.hasPendingSelection)
    }

    /// Posting needs an account: guests (and unverified accounts) go through the account flow first.
    private func requestPost() {
        if authSession.canPost {
            isPostFlowPresented = true
        } else {
            accountFlow = .post
        }
    }

    private func continueAfterAccountFlow() {
        guard opensPostAfterAccountFlow else {
            openTappedAlert()
            return
        }
        opensPostAfterAccountFlow = false
        // A tapped alert waits for the post flow too; it opens when that closes.
        if authSession.canPost { isPostFlowPresented = true } else { openTappedAlert() }
    }

    /// Opens the post from a tapped alert. Waits while the post flow or the account flow is open, so a draft or a
    /// half-typed sign-in is never discarded; their `onDismiss` calls this again. The request stays with the
    /// notification service until navigation opens the post, so a new session (guest -> account) still gets it.
    private func openTappedAlert() {
        guard let session, let request = environment.notifications.pendingAlert else { return }
        guard !isPostFlowPresented, accountFlow == nil else {
            Logger.ui.info("Alert open deferred (\(isPostFlowPresented ? "post flow" : "account flow", privacy: .public) open)")
            return
        }
        session.navigation.openAlert(request)
    }

    private func showPostAfterFlow() {
        if let postId = postToShowAfterFlow {
            postToShowAfterFlow = nil
            session?.navigation.selectPost(id: postId)
        }
        openTappedAlert()
    }

    /// Reauthenticates, stops the session, deletes everything on the server, then signs out locally.
    /// On failure the user stays signed in and the session restarts.
    private func deleteAccount(password: String) async throws {
        do {
            try await environment.account.deleteAccount(password: password) {
                session?.stopForDeletion()
            }
        } catch {
            session?.start()
            throw error
        }
        AccountCleanup.clearPerUserDefaults()
        auth.accountWasDeleted()
    }

    /// Stops the listener and removes the alert registration first: rules deny both once signed out.
    /// The app then continues as a new guest.
    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            await session?.prepareSignOut()
            isSigningOut = false
            auth.signOut()
        }
    }
}
