import Foundation

/// Typed error thrown by every service method. View models map these to friendly messages.
nonisolated enum AppError: Error, Equatable, Sendable {
    case network
    case permissionDenied
    case aiUnavailable
    /// Rate limit or quota.
    case aiBusy
    case cameraUnavailable
    case captureFailed
    case validation(String)
    case unauthorized
    /// The user cancelled; never shown.
    case cancelled
    case unknown
}
