import Foundation

nonisolated extension AppError {
    /// Friendly copy for the UI. Never show raw error strings.
    var userMessage: String {
        switch self {
        case .network: "No connection. Check your internet and try again."
        case .unauthorized: "Email or password is incorrect."
        case .validation(let message): message
        case .permissionDenied: "You don't have permission to do that."
        case .cameraUnavailable: "The camera isn't available right now. You can pick a photo from your library."
        case .captureFailed: "Couldn't take the photo. Please try again."
        case .aiUnavailable: "AI isn't available right now. You can fill it in yourself."
        case .aiBusy: "AI is busy. Try again or fill it in yourself."
        case .cancelled: ""
        case .unknown: "Something went wrong. Please try again."
        }
    }
}
