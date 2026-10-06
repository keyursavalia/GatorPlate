import Foundation

/// Typed error thrown by every service method. View models map these to friendly messages.
nonisolated enum AppError: Error, Equatable, Sendable {
    case network
    case permissionDenied
    case aiUnavailable
    case validation(String)
    case unauthorized
    case unknown
}
