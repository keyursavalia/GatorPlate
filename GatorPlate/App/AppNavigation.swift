import Foundation
import Observation
import OSLog

/// Tab and post selection for the main UI. `selectPost(id:)` is the entry point for "View on map" and the feed;
/// `openAlert(_:)` for tapped free food alerts.
@MainActor
@Observable
final class AppNavigation {
    enum TabID: Hashable {
        case map, feed, settings
    }

    /// Screens pushed inside the Settings tab.
    enum SettingsRoute: Hashable {
        case alertFilters, account
    }

    static let postEndedNotice = "That food post has ended."
    static let alertPostUnavailableNotice = "That food is no longer available."
    static let blockedPosterNotice = "You blocked this poster."

    var selectedTab = TabID.map
    var selectedPostId: String?
    /// The Settings tab's navigation path.
    var settingsPath: [SettingsRoute] = []
    /// The tab whose filter sheet is open. An alert closes it before opening its post.
    var filterSheetTab: TabID?
    /// Set when an alert opens a post: the map moves its camera to the pin once, then clears it.
    private(set) var cameraFocusPostId: String?
    /// Shown on the map when an opened or selected post is no longer active.
    private(set) var notice: String?
    /// A post opened by ID that hasn't arrived yet.
    private(set) var pendingPostId: String?
    /// A tapped alert's post is being looked up ("Opening post…" on the map).
    private(set) var isOpeningAlert = false
    /// The tapped alert's post is gone, expired or missing: the map shows the "no longer available" card.
    private(set) var showsAlertUnavailable = false

    @ObservationIgnored private let posts: PostsRepository
    /// Whether this user blocked a post's author (set by `MainSession`). Such posts never open by ID.
    @ObservationIgnored var isAuthorBlocked: (String) -> Bool = { _ in false }
    @ObservationIgnored private let pendingWait: Duration
    @ObservationIgnored private let alertMaxWait: Duration
    /// Tells the notification service an alert was opened (or shown as missing).
    @ObservationIgnored private let alertResolved: (AlertOpenRequest) -> Void
    /// One server read of a post by ID (`PostService.fetchPost`), so a missing alert post is known at once.
    @ObservationIgnored private let lookup: ((String) async throws -> FoodPost?)?
    @ObservationIgnored private var lookupTask: Task<Void, Never>?
    @ObservationIgnored private var pendingNotice = AppNavigation.postEndedNotice
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    @ObservationIgnored private var capTask: Task<Void, Never>?
    /// The alert behind `pendingPostId`, and the server snapshot count when it was tapped.
    @ObservationIgnored private var pendingAlert: AlertOpenRequest?
    @ObservationIgnored private var pendingSnapshotMark = 0
    /// Waiting for the filter sheet to finish closing.
    @ObservationIgnored private var alertAfterSheet: AlertOpenRequest?
    /// The last alert handed to this navigation, so a repeated hand-off is ignored.
    @ObservationIgnored private var lastAlert: AlertOpenRequest?
    /// Posts this user is removing (Mark as gone): they close without the "ended" notice.
    @ObservationIgnored private var expectedRemovals: Set<String> = []

    init(posts: PostsRepository, pendingWait: Duration = .seconds(AppConfig.postSelectionPendingSeconds),
         alertMaxWait: Duration = .seconds(AppConfig.alertOpenMaxWaitSeconds),
         alertResolved: @escaping (AlertOpenRequest) -> Void = { _ in },
         lookup: ((String) async throws -> FoodPost?)? = nil) {
        self.posts = posts
        self.pendingWait = pendingWait
        self.alertMaxWait = alertMaxWait
        self.alertResolved = alertResolved
        self.lookup = lookup
    }

    var hasPendingSelection: Bool {
        pendingPostId != nil || alertAfterSheet != nil
    }

    /// Opens the post on the map. A post that hasn't arrived yet waits until posts have loaded plus a short
    /// grace, then shows `missingNotice`.
    func selectPost(id: String, missingNotice: String = AppNavigation.postEndedNotice) {
        select(id: id, missingNotice: missingNotice, alert: nil)
    }

    /// A tapped alert: closes what's in the way (a pushed Settings screen, a filter sheet), then opens the post.
    /// It counts as missing only after a server result newer than the tap, or after `alertMaxWait`.
    func openAlert(_ request: AlertOpenRequest) {
        guard request != lastAlert else { return }
        lastAlert = request
        settingsPath = []
        if filterSheetTab != nil {
            alertAfterSheet = request
            filterSheetTab = nil
            return
        }
        select(id: request.postId, missingNotice: Self.alertPostUnavailableNotice, alert: request)
    }

    /// The filter sheet's `onDismiss`: an alert that arrived while it was open opens now.
    func filterSheetDidDismiss() {
        guard let request = alertAfterSheet else { return }
        alertAfterSheet = nil
        select(id: request.postId, missingNotice: Self.alertPostUnavailableNotice, alert: request)
    }

    func clearCameraFocus() {
        cameraFocusPostId = nil
    }

    /// Call on every change to the active posts, the load phase or the server snapshot count.
    func postsDidChange() {
        if let pendingPostId {
            if posts.post(id: pendingPostId) != nil {
                let alert = pendingAlert
                cancelPending()
                show(pendingPostId, alert: alert)
            } else {
                startPendingTimerIfReady()
            }
        }
        if let selectedPostId, posts.post(id: selectedPostId) == nil {
            self.selectedPostId = nil
            if expectedRemovals.remove(selectedPostId) == nil { notice = Self.postEndedNotice }
        }
    }

    /// The user is marking this post as gone; when it leaves the feed, don't call it "ended".
    func expectRemoval(of postId: String) {
        expectedRemovals.insert(postId)
    }

    func cancelExpectedRemoval(of postId: String) {
        expectedRemovals.remove(postId)
    }

    func dismissNotice() {
        notice = nil
    }

    /// A short info notice on the map (e.g. after blocking someone).
    func showNotice(_ text: String) {
        notice = text
    }

    func dismissAlertUnavailable() {
        showsAlertUnavailable = false
    }

    /// "See what's available" on the card: the Feed lists everything that's still out.
    func showAvailableFood() {
        showsAlertUnavailable = false
        selectedTab = .feed
    }

    /// Settings > Notifications > Custom notifications (the "Customize" toast action).
    func openAlertFilters() {
        selectedPostId = nil
        selectedTab = .settings
        settingsPath = [.alertFilters]
    }

    // MARK: Selection

    private func select(id: String, missingNotice: String, alert: AlertOpenRequest?) {
        selectedTab = .map
        showsAlertUnavailable = false
        // A newer selection replaces a waiting alert; it counts as handled so nothing waits on it forever.
        if let waiting = pendingAlert, waiting != alert { alertResolved(waiting) }
        cancelPending()
        if posts.post(id: id) != nil {
            show(id, alert: alert)
            return
        }
        selectedPostId = nil
        pendingPostId = id
        pendingNotice = missingNotice
        pendingAlert = alert
        pendingSnapshotMark = posts.serverSnapshotCount
        if alert != nil {
            isOpeningAlert = true
            startCapTimer(for: id)
            startLookup(for: id)
        }
        startPendingTimerIfReady()
    }

    /// Asks the server once: a missing, gone or expired post shows the card right away; an active one waits for
    /// the listener (it opens from there). A failed read falls back to the listener wait and the cap.
    private func startLookup(for id: String) {
        guard let lookup else { return }
        lookupTask = Task { [weak self] in
            let found: FoodPost?
            do {
                found = try await lookup(id)
            } catch {
                return
            }
            guard !Task.isCancelled, let self, self.pendingPostId == id else { return }
            if found?.isActive() != true { self.showMissing() }
        }
    }

    private func show(_ id: String, alert: AlertOpenRequest?) {
        if let post = posts.post(id: id), isAuthorBlocked(post.authorUid) {
            selectedPostId = nil
            notice = Self.blockedPosterNotice
            if let alert { alertResolved(alert) }
            return
        }
        selectedPostId = id
        guard let alert else { return }
        cameraFocusPostId = id
        Logger.ui.info("Alert post opened")
        alertResolved(alert)
    }

    private func showMissing() {
        let alert = pendingAlert
        let missingNotice = pendingNotice
        cancelPending()
        guard let alert else {
            notice = missingNotice
            return
        }
        showsAlertUnavailable = true
        Logger.ui.info("Alert post missing")
        alertResolved(alert)
    }

    /// Selections wait for loaded posts; alerts also wait for a server result that came in after the tap.
    private func startPendingTimerIfReady() {
        guard let id = pendingPostId, pendingTask == nil, posts.phase == .loaded else { return }
        if pendingAlert != nil, posts.serverSnapshotCount <= pendingSnapshotMark { return }
        let wait = pendingWait
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.pendingPostId == id else { return }
            self.showMissing()
        }
    }

    /// An alert never waits forever (offline, or a listener that never reports back).
    private func startCapTimer(for id: String) {
        let wait = alertMaxWait
        capTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, self.pendingPostId == id else { return }
            self.showMissing()
        }
    }

    private func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        capTask?.cancel()
        capTask = nil
        lookupTask?.cancel()
        lookupTask = nil
        pendingPostId = nil
        pendingAlert = nil
        isOpeningAlert = false
    }
}
