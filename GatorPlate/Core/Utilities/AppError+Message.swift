import Foundation

nonisolated extension AppError {
    /// Friendly copy for the UI. Never show raw error strings.
    var userMessage: String {
        switch self {
        case .network: "No connection. Check your internet and try again."
        case .unauthorized: "Email or password is incorrect."
        case .validation(let message): message
        case .permissionDenied: "You don't have permission to do that."
        case .aiUnavailable, .unknown: "Something went wrong. Please try again."
        }
    }
}
