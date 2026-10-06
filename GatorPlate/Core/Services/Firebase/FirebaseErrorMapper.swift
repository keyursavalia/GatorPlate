import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Maps Firebase Auth / Firestore errors to `AppError`. Raw Firebase strings never reach the UI.
nonisolated enum FirebaseErrorMapper {
    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .emailAlreadyInUse:
                return .validation("That email already has an account. Try logging in.")
            case .weakPassword:
                return .validation("Use at least \(AppConfig.minPasswordLength) characters.")
            case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail, .userDisabled:
                return .unauthorized
            case .tooManyRequests:
                return .validation("Too many attempts. Try again in a few minutes.")
            case .networkError:
                return .network
            default:
                return .unknown
            }
        }

        if nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable, .deadlineExceeded: return .network
            case .permissionDenied, .unauthenticated: return .permissionDenied
            default: return .unknown
            }
        }

        if nsError.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}
