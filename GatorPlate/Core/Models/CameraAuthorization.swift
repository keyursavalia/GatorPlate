import Foundation

/// App-level view of camera permission, free of AVFoundation types.
nonisolated enum CameraAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    /// Blocked by parental controls or device management; the user can't change it in Settings.
    case restricted
}
