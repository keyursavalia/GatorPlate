import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct NotificationsModelTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "NotificationsModelTests-\(UUID().uuidString)") ?? .standard
    }

    private func profile(enabled: Bool = false) -> UserProfile {
        var profile = SampleData.profile
        profile.uid = "me"
        profile.notificationsEnabled = enabled
        return profile
    }

    private func newPost(id: String = "a", author: String = "other") -> FoodPost {
        var post = SampleData.post(now: start, id: id)
        post.authorUid = author
        post.createdAt = start.addingTimeInterval(60)
        post.expiresAt = start.addingTimeInterval(1800)
        return post
    }

    private func makeModel(
        service: MockNotificationService,
        enabled: Bool = true
    ) -> NotificationsModel {
        NotificationsModel(profile: profile(enabled: enabled), service: service, defaults: defaults(), sessionStart: start)
    }

    /// Seeds with an empty first snapshot, then delivers `posts`.
    private func deliver(_ posts: [FoodPost], to model: NotificationsModel, foreground: Bool = true) async {
        await model.postsChanged(posts: [], hasLoaded: true, isForeground: foreground, now: start)
        await model.postsChanged(posts: posts, hasLoaded: true, isForeground: foreground, now: start)
    }

    @Test func foregroundPostShowsABanner() async {
        let model = makeModel(service: MockNotificationService(permission: .granted))
        await model.start()
        await deliver([newPost()], to: model)
        #expect(model.banner?.postID == "a")
    }

    @Test func backgroundPostSchedulesALocalNotification() async {
        let service = MockNotificationService(permission: .granted)
        let model = makeModel(service: service)
        await model.start()
        await deliver([newPost()], to: model, foreground: false)
        #expect(await service.scheduled.map(\.postID) == ["a"])
        #expect(model.banner == nil)
    }

    @Test func backgroundPostSkipsLocalWhenRemotePushDelivers() async {
        let service = MockNotificationService(permission: .granted, deliversRemotePush: true)
        let model = makeModel(service: service)
        await model.start()
        await deliver([newPost()], to: model, foreground: false)
        #expect(await service.scheduled.isEmpty)
    }

    @Test func switchOffStopsAlertsImmediately() async {
        let service = MockNotificationService(permission: .granted)
        let model = makeModel(service: service)
        await model.start()
        await model.setEnabled(false)
        await deliver([newPost()], to: model)
        #expect(model.banner == nil)
        #expect(await service.disabledUIDs == ["me"])
    }

    @Test func postsArrivingWhileOffNeverAlertAfterTurningOn() async {
        let model = makeModel(service: MockNotificationService(permission: .granted), enabled: false)
        await model.start()
        await deliver([newPost()], to: model)
        await model.setEnabled(true)
        await model.postsChanged(posts: [newPost()], hasLoaded: true, isForeground: true, now: start)
        #expect(model.banner == nil)
    }

    @Test func ownPostsNeverAlert() async {
        let model = makeModel(service: MockNotificationService(permission: .granted))
        await model.start()
        await deliver([newPost(author: "me")], to: model)
        #expect(model.banner == nil)
    }

    @Test func enablingBeforeAnyPermissionShowsTheExplainerFirst() async {
        let service = MockNotificationService(permission: .notDetermined)
        let model = makeModel(service: service, enabled: false)
        await model.setEnabled(true)
        #expect(model.showsExplainer)
        #expect(!model.isEnabled)
        #expect(await service.enabledUIDs.isEmpty)
    }

    @Test func confirmingTheExplainerRequestsPermissionAndEnables() async {
        let service = MockNotificationService(permission: .notDetermined, permissionAfterRequest: .granted)
        let model = makeModel(service: service, enabled: false)
        await model.setEnabled(true)
        await model.confirmExplainer()
        #expect(model.isEnabled)
        #expect(!model.showsExplainer)
        #expect(await service.enabledUIDs == ["me"])
    }

    @Test func deniedPermissionExplainsAndStaysOff() async {
        let service = MockNotificationService(permission: .denied)
        let model = makeModel(service: service, enabled: false)
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(model.errorMessage == NotificationsModel.deniedMessage)
        #expect(model.permission == .denied)
    }

    @Test func deniedAtTheSystemPromptStaysOff() async {
        let service = MockNotificationService(permission: .notDetermined, permissionAfterRequest: .denied)
        let model = makeModel(service: service, enabled: false)
        await model.setEnabled(true)
        await model.confirmExplainer()
        #expect(!model.isEnabled)
        #expect(model.errorMessage == NotificationsModel.deniedMessage)
    }

    @Test func failedSaveRevertsTheSwitch() async {
        let service = MockNotificationService(permission: .granted, enableError: .network)
        let model = makeModel(service: service, enabled: false)
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(model.errorMessage == NotificationsModel.saveFailedMessage)
    }

    @Test func startRegistersTheDeviceWhenAlertsAreOn() async {
        let service = MockNotificationService(permission: .granted)
        let model = makeModel(service: service)
        await model.start()
        #expect(await service.activatedUIDs == ["me"])
    }

    @Test func startTurnsAlertsOffWhenPermissionWasRevoked() async {
        let model = makeModel(service: MockNotificationService(permission: .denied))
        await model.start()
        #expect(!model.isEnabled)
    }

    @Test func switchIsRememberedLocally() async {
        let store = defaults()
        let service = MockNotificationService(permission: .granted)
        let first = NotificationsModel(profile: profile(enabled: false), service: service, defaults: store, sessionStart: start)
        await first.setEnabled(true)
        let second = NotificationsModel(profile: profile(enabled: false), service: service, defaults: store, sessionStart: start)
        #expect(second.isEnabled)
    }

    @Test func detachRemovesTheDeviceToken() async {
        let service = MockNotificationService(permission: .granted)
        let model = makeModel(service: service)
        await model.detachDevice()
        #expect(await service.detachedUIDs == ["me"])
    }

    // MARK: Taps

    @Test func tapOpensAnActivePost() {
        let model = makeModel(service: MockNotificationService())
        let relay = NotificationTapRelay()
        let navigation = NavigationModel()
        relay.receive(postID: "a")
        model.ingestTap(from: relay)
        model.resolveTap(activePostIDs: ["a"], hasLoaded: true, navigation: navigation)
        #expect(navigation.selectedPostID == "a")
        #expect(model.unavailableNotice == nil)
        #expect(relay.pendingPostID == nil)
    }

    @Test func tapOnAnExpiredPostSaysItIsGone() {
        let model = makeModel(service: MockNotificationService())
        let relay = NotificationTapRelay()
        let navigation = NavigationModel()
        relay.receive(postID: "a")
        model.ingestTap(from: relay)
        model.resolveTap(activePostIDs: ["b"], hasLoaded: true, navigation: navigation)
        #expect(navigation.selectedPostID == nil)
        #expect(model.unavailableNotice == NotificationsModel.unavailableMessage)
    }

    @Test func tapWaitsForTheFirstSnapshot() {
        let model = makeModel(service: MockNotificationService())
        let relay = NotificationTapRelay()
        let navigation = NavigationModel()
        relay.receive(postID: "a")
        model.ingestTap(from: relay)
        model.resolveTap(activePostIDs: [], hasLoaded: false, navigation: navigation)
        #expect(model.unavailableNotice == nil)
        model.resolveTap(activePostIDs: ["a"], hasLoaded: true, navigation: navigation)
        #expect(navigation.selectedPostID == "a")
    }
}
