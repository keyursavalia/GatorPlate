import Foundation

/// App-level view of location permission, free of CoreLocation types.
nonisolated enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    /// `precise == false` means the user chose approximate location.
    case authorized(precise: Bool)

    var isAuthorized: Bool {
        if case .authorized = self { true } else { false }
    }
}
