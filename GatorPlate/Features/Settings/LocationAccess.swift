import Foundation
import Observation

/// Location as the student sees it, handled like notifications: Settings > Location is a switch that follows iOS's
/// answer, and the map's location button asks the same way. iOS shows its own prompt only once, so after
/// "Don't Allow" both show one alert that opens iOS Settings; coming back with location allowed shows a toast.
/// Each screen keeps its own `LocationPrompt` state (two tabs are loaded at once, so a shared one would present twice).
@MainActor
@Observable
final class LocationAccess {
    @ObservationIgnored private let location: any LocationProviding
    /// The student went to iOS Settings to allow location (in memory only).
    @ObservationIgnored private var pendingSystemOptIn = false

    init(location: any LocationProviding) {
        self.location = location
    }

    var authorization: LocationAuthorization { location.authorization }
    var isOn: Bool { authorization.isAuthorized }
    var isApproximate: Bool { authorization == .authorized(precise: false) }

    /// The Settings switch. Not asked yet: the system prompt; otherwise the alert to show, if any.
    func setOn(_ on: Bool) async -> LocationPrompt? {
        switch (on, authorization) {
        case (true, .notDetermined):
            _ = await location.requestAuthorization()
            return nil
        case (true, .denied): return .turnOn
        case (true, .restricted): return .restricted
        case (false, .authorized): return .turnOff
        default: return nil
        }
    }

    /// The map's location button while location is off or restricted.
    func promptFromMap() async -> LocationPrompt? {
        switch authorization {
        case .notDetermined:
            _ = await location.requestAuthorization()
            return nil
        case .denied: return .turnOn
        case .restricted: return .restricted
        case .authorized: return nil
        }
    }

    func requestPreciseLocation() {
        location.requestTemporaryPreciseAccuracy()
    }

    /// "Open Settings" in the `.turnOn` alert.
    func willOpenSystemSettings() {
        pendingSystemOptIn = true
    }

    /// Call when iOS reports a new authorization. True once, when location came on after "Open Settings".
    func authorizationDidChange() -> Bool {
        guard pendingSystemOptIn, isOn else { return false }
        pendingSystemOptIn = false
        return true
    }
}

/// The one alert for location, shared by Settings and the map.
enum LocationPrompt: Identifiable {
    case turnOn, turnOff, restricted

    var id: Self { self }

    var title: String {
        switch self {
        case .turnOn: "Turn on location in Settings"
        case .turnOff: "Turn off location in Settings"
        case .restricted: "Location is restricted"
        }
    }

    var message: String {
        switch self {
        case .turnOn:
            "Open Settings, tap Location, then choose While Using the App. GatorPlate uses it only to show how far food is."
        case .turnOff:
            "iOS controls location for GatorPlate. Open Settings, tap Location, then choose Never."
        case .restricted:
            "Location is limited on this iPhone, for example by Screen Time. The map still works without it."
        }
    }
}
