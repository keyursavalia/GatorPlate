import Foundation

/// What a Firebase AI Logic backend error means for the analyzer. Pure (no Firebase import) so the harness can test
/// it: the SDK's internal `BackendError` bridges to an `NSError` whose domain ends in "BackendError", whose code is
/// the HTTP status, and whose description is "<message> (… - HTTP <code> <STATUS>)".
nonisolated enum GeminiBackendError: Equatable, Sendable {
    /// 404 / NOT_FOUND, or a 400 naming the model as not found, unsupported, deprecated or retired: try the next
    /// model in the chain.
    case modelUnavailable(category: String)
    /// A 400 about the thinking config: retry once without one.
    case thinkingRejected
    case rateLimited
    /// 401: usually a stale App Check token.
    case unauthenticated
    case forbidden
    case server(code: Int)
    case other(code: Int)
    /// Not a backend error at all.
    case notBackend

    static func classify(_ error: NSError) -> GeminiBackendError {
        guard error.domain.hasSuffix("BackendError") else { return .notBackend }
        let code = error.code
        let description = error.localizedDescription
        let message = description.lowercased()
        if code == 404 || description.contains("NOT_FOUND") {
            return .modelUnavailable(category: "model_unavailable_\(code)")
        }
        if code == 400 {
            // Checked before the model rule: "thinking level is not supported by this model" isn't a dead model.
            if message.contains("thinking") { return .thinkingRejected }
            let modelGone = ["not found", "not supported", "deprecated", "retired"].contains(where: message.contains)
            if message.contains("model"), modelGone { return .modelUnavailable(category: "model_unavailable_400") }
        }
        switch code {
        case 429: return .rateLimited
        case 401: return .unauthenticated
        case 403: return .forbidden
        case 500...599: return .server(code: code)
        default: return .other(code: code)
        }
    }
}
