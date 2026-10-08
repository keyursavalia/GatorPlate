import Foundation

nonisolated extension RouteFailure {
    /// Friendly copy for the bottom card. Every case is followed by "Open in Apple Maps".
    var userMessage: String {
        switch self {
        case .locationOff:
            "Turn on location to see a walking route here. You can still get directions in Apple Maps."
        case .locationUnavailable:
            "Couldn't find your location yet. Try again, or get directions in Apple Maps."
        case .offCampus:
            "You're off campus, so the route won't fit this map. Apple Maps can guide you there."
        case .noRoute:
            "No walking route found to this spot. Apple Maps may know a way."
        case .network:
            "No connection for directions. Check your internet, or try Apple Maps."
        case .throttled:
            "Directions are busy right now. Try again in a moment, or use Apple Maps."
        case .cancelled:
            ""
        case .unknown:
            "Couldn't get a route. Try again, or use Apple Maps."
        }
    }

    /// Whether "Try again" makes sense.
    var isRetryable: Bool {
        switch self {
        case .locationUnavailable, .network, .throttled, .unknown: true
        case .locationOff, .offCampus, .noRoute, .cancelled: false
        }
    }
}
