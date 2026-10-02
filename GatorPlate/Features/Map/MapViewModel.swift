import MapKit
import Observation
import OSLog
import SwiftUI

/// The single banner shown above the map, highest priority first.
enum MapBanner: Equatable {
    case permissionPrompt
    case locationDenied
    case reducedAccuracy
    case offCampus
}

@Observable
final class MapViewModel {
    /// Closer than the overview, still shows the surroundings.
    static let userCameraDistance: Double = 450

    var cameraPosition: MapCameraPosition = .camera(SFSUCampus.overviewCamera)
    var selectedPostID: String?
    private(set) var posts: [FoodPost]
    private(set) var status: LocationStatus = .notDetermined
    private(set) var userLocation: Coordinate?

    private let location: any LocationProviding
    private var trackingTask: Task<Void, Never>?

    init(location: any LocationProviding, posts: [FoodPost] = SampleData.mapPosts()) {
        self.location = location
        self.posts = posts
    }

    // MARK: Derived state

    var isOnCampus: Bool {
        guard let userLocation else { return false }
        return SFSUCampus.contains(userLocation)
    }

    var banner: MapBanner? {
        switch status.authorization {
        case .notDetermined: .permissionPrompt
        case .denied: .locationDenied
        case .authorized:
            if status.accuracy == .reduced {
                .reducedAccuracy
            } else if userLocation != nil && !isOnCampus {
                .offCampus
            } else {
                nil
            }
        }
    }

    var activePosts: [FoodPost] {
        posts.filter { $0.isActive() }
    }

    var selectedPost: FoodPost? {
        guard let selectedPostID else { return nil }
        return posts.first { $0.id == selectedPostID && $0.isActive() }
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

    func accessibilityLabel(for post: FoodPost, now: Date = Date()) -> String {
        let minutes = max(0, Int((post.expiresAt.timeIntervalSince(now) / 60).rounded(.up)))
        var label = "Free food: \(post.title), \(minutes) minutes left"
        if let distance = distanceText(to: post) {
            label += ", \(distance) away"
        }
        return label
    }

    // MARK: Lifecycle (call from `.task` on the map screen: it starts on appear and is cancelled on disappear)

    func run() async {
        let statuses = await location.statusUpdates()
        for await newStatus in statuses {
            apply(status: newStatus)
        }
        // The loop ends when this task is cancelled (the map is no longer visible): stop tracking too.
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
        trackingTask = Task { [location] in
            let updates = await location.locationUpdates()
            for await coordinate in updates {
                self.apply(location: coordinate)
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

    /// On campus: fly to the user. Otherwise (off campus, no fix, no permission): the campus overview.
    func recenter() {
        if let userLocation, SFSUCampus.contains(userLocation) {
            cameraPosition = .camera(
                MapCamera(centerCoordinate: userLocation.clCoordinate, distance: Self.userCameraDistance, heading: 0, pitch: 0)
            )
        } else {
            cameraPosition = .camera(SFSUCampus.overviewCamera)
        }
    }
}
