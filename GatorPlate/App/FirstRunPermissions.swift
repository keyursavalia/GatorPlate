import Foundation
import Observation
import OSLog

/// Decides when the location and notification prompts fire. It's the only place that asks for either on its
/// own. On the first Map appearance (app active, no cover or sheet, no tapped alert waiting):
/// settle 0.6 s so the map renders, ask for location if undecided, wait 1 s, ask for notifications if
/// undecided. Live system status is the source of truth; nothing is persisted. "Allow Once" location
/// returns to undecided on the next launch, so the next session asks again, which is correct iOS behavior.
@MainActor
@Observable
final class FirstRunPermissions {
    enum Phase: Equatable {
        case idle, settling, askingLocation, gap, askingNotifications, done, cancelled
    }

    /// When the prompts may fire.
    struct Conditions: Equatable {
        var mapVisible = false
        var sceneActive = false
        var coverOrSheetOpen = false
        var alertPending = false

        var isReady: Bool { mapVisible && sceneActive && !coverOrSheetOpen && !alertPending }
    }

    private(set) var phase = Phase.idle
    /// "Alerts on for all free food. Customize": shown once on the map after the chain opted the user in.
    private(set) var showsAlertsToast = false
    /// Spoken after a decision that changed the UI; the map posts it to VoiceOver.
    private(set) var announcement: String?

    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let notifications: any NotificationService
    /// Opts the user in after "Allow"; true when it was saved.
    @ObservationIgnored private let optIn: () async -> Bool
    @ObservationIgnored private let sleep: (Duration) async -> Void
    @ObservationIgnored private var conditions = Conditions()
    @ObservationIgnored private var readyWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var task: Task<Void, Never>?

    init(location: any LocationProviding, notifications: any NotificationService,
         optIn: @escaping () async -> Bool,
         sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.location = location
        self.notifications = notifications
        self.optIn = optIn
        self.sleep = sleep
    }

    /// Call whenever a condition changes. Starts the sequence the first time they all hold.
    func update(_ conditions: Conditions) {
        self.conditions = conditions
        if conditions.isReady { resumeReadyWaiters() }
        guard phase == .idle, conditions.isReady else { return }
        phase = .settling
        task = Task { [weak self] in await self?.run() }
    }

    /// Sign-out or account deletion: stop where it is. An alert already on screen stays (iOS owns it).
    func cancel() {
        task?.cancel()
        task = nil
        phase = .cancelled
        showsAlertsToast = false
        resumeReadyWaiters()
    }

    func dismissAlertsToast() {
        showsAlertsToast = false
    }

    func clearAnnouncement() {
        announcement = nil
    }

    // MARK: Sequence

    private func run() async {
        await sleep(.seconds(AppConfig.permissionSettleSeconds))
        guard await waitUntilReady() else { return }

        if location.authorization == .notDetermined {
            phase = .askingLocation
            let answer = await location.requestAuthorization()
            guard !Task.isCancelled else { return }
            Logger.ui.info("First-run location answered, authorized: \(answer.isAuthorized, privacy: .public)")
            if answer.isAuthorized { announcement = "Location on. Distances shown." }
            phase = .gap
            await sleep(.seconds(AppConfig.permissionGapSeconds))
            guard await waitUntilReady() else { return }
        } else {
            phase = .gap
        }

        await notifications.refreshAuthorization()
        guard !Task.isCancelled else { return }
        if notifications.authorization == .notDetermined {
            phase = .askingNotifications
            let answer = await notifications.requestAuthorization()
            guard !Task.isCancelled else { return }
            if answer.isAuthorized, await optIn(), !Task.isCancelled {
                showsAlertsToast = true
            }
        }
        if phase != .cancelled { phase = .done }
    }

    /// Waits for the conditions (for example, a sheet closing). False when cancelled.
    private func waitUntilReady() async -> Bool {
        while !conditions.isReady {
            guard !Task.isCancelled, phase != .cancelled else { return false }
            await withCheckedContinuation { readyWaiters.append($0) }
        }
        return !Task.isCancelled && phase != .cancelled
    }

    private func resumeReadyWaiters() {
        let waiters = readyWaiters
        readyWaiters = []
        for waiter in waiters { waiter.resume() }
    }
}
