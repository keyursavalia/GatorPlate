import Foundation
import Observation

/// The user's permission status and position, shared by the Map and Feed. Location stays on the device (R7).
@MainActor
@Observable
final class UserLocationModel {
    private(set) var status: LocationStatus = .notDetermined
    private(set) var userLocation: Coordinate?

    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private var trackingTask: Task<Void, Never>?

    init(location: any LocationProviding) {
        self.location = location
    }

    var isOnCampus: Bool {
        guard let userLocation else { return false }
        return SFSUCampus.contains(userLocation)
    }

    /// Meters from the user to a post, if the user's location is known.
    func distance(to post: FoodPost) -> Double? {
        userLocation?.distance(to: Coordinate(latitude: post.latitude, longitude: post.longitude))
    }

    func distanceText(to post: FoodPost) -> String? {
        guard let meters = distance(to: post) else { return nil }
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    // MARK: Lifecycle (call from a `.task`: it starts when the screen appears and stops when it is cancelled)

    func run() async {
        let statuses = await location.statusUpdates()
        for await newStatus in statuses {
            apply(status: newStatus)
        }
        // The loop ends when this task is cancelled: stop tracking too.
        stopTracking()
    }

    func apply(status newStatus: LocationStatus) {
        status = newStatus
        if newStatus.authorization == .authorized {
            startTrackingIfNeeded()
        } else {
            stopTracking()
            userLocation = nil
        }
    }

    func apply(location coordinate: Coordinate) {
        userLocation = coordinate
    }

    private func startTrackingIfNeeded() {
        guard trackingTask == nil else { return }
        trackingTask = Task { [location, weak self] in
            let updates = await location.locationUpdates()
            for await coordinate in updates {
                self?.apply(location: coordinate)
            }
        }
    }

    private func stopTracking() {
        trackingTask?.cancel()
        trackingTask = nil
    }

    // MARK: Actions

    func requestPermission() {
        Task { await location.requestWhenInUseAuthorization() }
    }

    func requestFullAccuracy() {
        Task { await location.requestTemporaryFullAccuracy() }
    }
}
