import Foundation
import Observation
import OSLog

/// Alert state for the signed-in user: the opt-in switch, the permission, the in-app banner and tap routing.
///
/// The switch is stored locally (per uid) and on `users/{uid}.notificationsEnabled`. Turning it off takes effect
/// immediately: `postsChanged` checks it before every alert.
@MainActor
@Observable
final class NotificationsModel {
    nonisolated static let deniedMessage = "Notifications are off for GatorPlate in iOS Settings. Turn them on there to get free food alerts."
    nonisolated static let saveFailedMessage = "Couldn't update your alert setting. Check your connection and try again."
    nonisolated static let unavailableMessage = "That food is no longer available."
    nonisolated static let inAppOnlyNote = "Alerts work while the app is open or recently used. Full push is the production plan."
    nonisolated static let pushNote = "You'll get an alert when someone posts free food. You never get alerts for your own posts."

    private(set) var isEnabled: Bool
    private(set) var permission: NotificationPermission = .notDetermined
    private(set) var banner: AlertContent?
    private(set) var errorMessage: String?
    private(set) var unavailableNotice: String?
    var showsExplainer = false

    @ObservationIgnored private var filter: NewPostFilter
    @ObservationIgnored private var pendingTapID: String?
    @ObservationIgnored private let uid: String
    @ObservationIgnored private let service: any NotificationService
    @ObservationIgnored private let defaults: UserDefaults

    var footnote: String { service.deliversRemotePush ? Self.pushNote : Self.inAppOnlyNote }

    init(
        profile: UserProfile,
        service: any NotificationService,
        defaults: UserDefaults = .standard,
        sessionStart: Date = Date()
    ) {
        self.uid = profile.uid
        self.service = service
        self.defaults = defaults
        self.filter = NewPostFilter(currentUserID: profile.uid, sessionStart: sessionStart)
        let key = Self.storageKey(uid: profile.uid)
        self.isEnabled = defaults.object(forKey: key) as? Bool ?? profile.notificationsEnabled
    }

    nonisolated static func storageKey(uid: String) -> String { "notificationsEnabled.\(uid)" }

    // MARK: Lifecycle

    /// Reads the permission and, when alerts are on, registers this device.
    func start() async {
        permission = await service.permission()
        guard isEnabled else { return }
        if permission == .granted {
            await service.activate(uid: uid)
        } else if permission == .denied {
            // The user revoked permission in iOS Settings: reflect that instead of pretending alerts work.
            store(enabled: false)
        }
    }

    func refreshPermission() async {
        permission = await service.permission()
    }

    // MARK: Switch

    func setEnabled(_ on: Bool) async {
        errorMessage = nil
        if !on {
            store(enabled: false)
            banner = nil
            do { try await service.disable(uid: uid) } catch { Logger.app.error("Disabling alerts failed") }
            return
        }
        permission = await service.permission()
        switch permission {
        case .granted: await turnOn()
        case .notDetermined: showsExplainer = true
        case .denied: errorMessage = Self.deniedMessage
        }
    }

    /// The user agreed on the explainer: show the system prompt.
    func confirmExplainer() async {
        showsExplainer = false
        permission = await service.requestPermission()
        if permission == .granted {
            await turnOn()
        } else {
            errorMessage = Self.deniedMessage
        }
    }

    func declineExplainer() {
        showsExplainer = false
    }

    private func turnOn() async {
        store(enabled: true)
        do {
            try await service.enable(uid: uid)
        } catch {
            store(enabled: false)
            errorMessage = Self.saveFailedMessage
        }
    }

    private func store(enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.storageKey(uid: uid))
    }

    /// Removes this device's token before sign-out. The preference is kept.
    func detachDevice() async {
        await service.detachDevice(uid: uid)
    }

    // MARK: New posts

    /// Call on every posts change. The first loaded snapshot seeds the "seen" set; later new posts alert.
    func postsChanged(posts: [FoodPost], hasLoaded: Bool, isForeground: Bool, now: Date = Date()) async {
        guard hasLoaded else { return }
        filter.seed(with: posts)
        // Always evaluated so posts that arrive while alerts are off are marked seen and never alert later.
        let fresh = filter.newPosts(in: posts, now: now)
        guard isEnabled, permission == .granted else { return }
        for post in fresh {
            let content = AlertContentFormatter.content(for: post)
            if isForeground {
                banner = content
            } else if !service.deliversRemotePush {
                await service.scheduleLocal(content)
            }
        }
    }

    func dismissBanner() { banner = nil }
    func dismissUnavailableNotice() { unavailableNotice = nil }

    // MARK: Taps

    /// Takes a tap from the relay. Resolved by `resolveTap` once posts have loaded.
    func ingestTap(from relay: NotificationTapRelay) {
        if let id = relay.consume() { pendingTapID = id }
    }

    /// Opens the tapped post, or says it is gone. Waits for the first snapshot so a cold launch is not misjudged.
    func resolveTap(activePostIDs: Set<String>, hasLoaded: Bool, navigation: NavigationModel) {
        guard hasLoaded, let id = pendingTapID else { return }
        pendingTapID = nil
        banner = nil
        if activePostIDs.contains(id) {
            navigation.selectPost(id: id)
        } else {
            unavailableNotice = Self.unavailableMessage
        }
    }
}
