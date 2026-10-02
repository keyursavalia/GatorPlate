import Foundation

/// Typed error thrown by every service method. View models map these to friendly messages.
nonisolated enum AppError: Error, Equatable, Sendable {
    case network
    case permissionDenied
    case aiUnavailable
    /// Quota or rate limit (HTTP 429).
    case aiBusy
    case aiTimeout
    case validation(String)
    case unauthorized
    case emailInUse
    case invalidCredentials
    case weakPassword
    case unknown
}
