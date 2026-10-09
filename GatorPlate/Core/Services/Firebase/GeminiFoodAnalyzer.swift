import FirebaseAILogic
import FirebaseAppCheck
import Foundation
import ImageIO
import OSLog

/// Live food analysis: Gemini through Firebase AI Logic (Gemini Developer API backend, App Check enforced).
/// The request carries only the stripped JPEG and fixed instruction text, never user identity.
@MainActor
final class GeminiFoodAnalyzer: FoodAnalyzing {
    private(set) var lastDiagnostics: FoodAnalysisDiagnostics?
    /// Created on first use, after `FirebaseApp.configure()`.
    private var model: GenerativeModel?
    private var isAnalyzing = false

    private static let maxAttempts = 2

    private enum AttemptResult {
        case decoded(RawFoodAnalysis)
        /// Safety filters: treated as "not food" (AI spec section 6).
        case blocked
        case retryable(category: String)
        /// The backend rejected the request's credentials (401). Usually a stale or placeholder App Check
        /// token after a failed refresh; a forced refresh and one retry fixes it.
        case unauthenticated(category: String)
        case fatal(AppError, category: String)
        case cancelled
    }

    private struct AnalysisTimeout: Error {}

    func prepare() {
        // Fire and forget: if the token is fresh this returns at once, otherwise it refreshes now,
        // seconds before the request needs it (a token expired overnight is the common case).
        Task { _ = await Self.refreshAppCheckToken(forcingRefresh: false) }
    }

    func analyze(jpegData: Data) async throws(AppError) -> FoodAnalysisOutcome {
        guard !isAnalyzing else { throw .aiBusy }
        isAnalyzing = true
        defer { isAnalyzing = false }

        #if DEBUG
        Logger.services.debug("AI request image metadata clean: \(Self.isMetadataClean(jpegData), privacy: .public)")
        #endif

        let start = ContinuousClock.now
        var attempt = 0
        while true {
            attempt += 1
            let result = await runAttempt(jpegData)
            switch result {
            case .decoded(let raw):
                let outcome = FoodAnalysisSanitizer.sanitize(raw, promptVersion: FoodAnalysisPrompt.promptVersion,
                                                             modelName: AppConfig.geminiModelName)
                finish(start: start, attempts: attempt, category: Self.category(for: outcome), raw: raw)
                logDietaryOverride(outcome: outcome, raw: raw)
                return outcome
            case .blocked:
                finish(start: start, attempts: attempt, category: "safety_blocked")
                return .rejected(.notFood)
            case .cancelled:
                finish(start: start, attempts: attempt, category: "cancelled")
                throw .cancelled
            case .fatal(let error, let category):
                finish(start: start, attempts: attempt, category: category)
                throw error
            case .unauthenticated(let category):
                guard attempt < Self.maxAttempts else {
                    finish(start: start, attempts: attempt, category: category)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI attempt \(attempt, privacy: .public) failed: \(category, privacy: .public); refreshing App Check and retrying")
                let refreshed = await Self.refreshAppCheckToken(forcingRefresh: true)
                Logger.services.notice("App Check refresh before retry: \(refreshed ? "ok" : "failed", privacy: .public)")
            case .retryable(let category):
                guard attempt < Self.maxAttempts else {
                    finish(start: start, attempts: attempt, category: category)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI attempt \(attempt, privacy: .public) failed: \(category, privacy: .public); retrying")
                do {
                    try await Task.sleep(for: .seconds(AppConfig.aiRetryDelaySeconds))
                } catch {
                    finish(start: start, attempts: attempt, category: "cancelled")
                    throw .cancelled
                }
            }
        }
    }

    // MARK: Request

    private func runAttempt(_ jpegData: Data) async -> AttemptResult {
        let model = generativeModel()
        let text: String?
        do {
            text = try await Self.withTimeout(seconds: AppConfig.aiTimeoutSeconds) {
                try await model.generateContent(InlineDataPart(data: jpegData, mimeType: "image/jpeg"),
                                                FoodAnalysisPrompt.userText).text
            }
        } catch {
            return Task.isCancelled ? .cancelled : Self.classify(error)
        }
        guard let text, let raw = FoodAnalysisSanitizer.decode(text) else {
            return .retryable(category: "malformed_json")
        }
        return .decoded(raw)
    }

    private func generativeModel() -> GenerativeModel {
        if let model { return model }
        let config = GenerationConfig(
            temperature: AppConfig.aiTemperature,
            maxOutputTokens: AppConfig.aiMaxOutputTokens,
            responseMIMEType: "application/json",
            responseSchema: FoodAnalysisSchema.response,
            thinkingConfig: ThinkingConfig(thinkingLevel: AppConfig.aiThinkingMinimal ? .minimal : .low))
        let newModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: AppConfig.geminiModelName,
            generationConfig: config,
            systemInstruction: ModelContent(role: "system", parts: FoodAnalysisPrompt.systemInstruction),
            requestOptions: RequestOptions(timeout: TimeInterval(AppConfig.aiTimeoutSeconds)))
        model = newModel
        return newModel
    }

    /// Races the request against a total deadline; `RequestOptions.timeout` alone is an idle timeout.
    private static func withTimeout<T: Sendable>(seconds: Int,
                                                 _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AnalysisTimeout()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw AnalysisTimeout() }
            return result
        }
    }

    // MARK: Errors

    private static func classify(_ error: any Error) -> AttemptResult {
        switch error {
        case is CancellationError:
            return .cancelled
        case is AnalysisTimeout:
            return .retryable(category: "timeout")
        case let urlError as URLError:
            return classify(urlError)
        case let generateError as GenerateContentError:
            switch generateError {
            case .promptBlocked:
                return .blocked
            case .responseStoppedEarly(let reason, _):
                return reason == .maxTokens ? .retryable(category: "max_tokens") : .blocked
            case .promptImageContentError:
                return .fatal(ImagePreprocessor.unreadable, category: "image_content")
            case .internalError(let underlying):
                return classifyUnderlying(underlying)
            }
        default:
            return classifyUnderlying(error)
        }
    }

    private static func classify(_ urlError: URLError) -> AttemptResult {
        switch urlError.code {
        case .cancelled:
            .cancelled
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            .fatal(.network, category: "offline")
        default:
            .retryable(category: "network_\(urlError.code.rawValue)")
        }
    }

    /// Backend errors surface as `NSError` whose code is the HTTP status.
    private static func classifyUnderlying(_ error: any Error) -> AttemptResult {
        if let urlError = error as? URLError { return classify(urlError) }
        let nsError = error as NSError
        guard nsError.domain.hasSuffix("BackendError") else {
            return .fatal(.aiUnavailable, category: "unexpected_error")
        }
        if (400...499).contains(nsError.code) {
            // The backend's explanation (e.g. App Check or API key problems); never contains the photo or prompt.
            let reason = String(nsError.localizedDescription.prefix(300))
            Logger.services.error("AI backend \(nsError.code, privacy: .public): \(reason, privacy: .public)")
        }
        switch nsError.code {
        case 429: return .fatal(.aiBusy, category: "rate_limited")
        case 401: return .unauthenticated(category: "forbidden_401")
        case 403: return .fatal(.aiUnavailable, category: "forbidden_403")
        case 500...599: return .retryable(category: "server_\(nsError.code)")
        default: return .fatal(.aiUnavailable, category: "http_\(nsError.code)")
        }
    }

    // MARK: App Check

    /// True when App Check produced a real token. On failure the AI SDK would send a placeholder (rejected
    /// with 401 while App Check is enforced). Logs the error type only.
    private static func refreshAppCheckToken(forcingRefresh: Bool) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AppCheck.appCheck().token(forcingRefresh: forcingRefresh) { token, error in
                if let error {
                    let nsError = error as NSError
                    Logger.services.error("App Check token refresh failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
                }
                continuation.resume(returning: token != nil && error == nil)
            }
        }
    }

    // MARK: Diagnostics (no content ever)

    private func finish(start: ContinuousClock.Instant, attempts: Int, category: String, raw: RawFoodAnalysis? = nil) {
        let latencyMs = Int(start.duration(to: .now) / .milliseconds(1))
        lastDiagnostics = FoodAnalysisDiagnostics(latencyMs: latencyMs, attempts: attempts, category: category,
                                                  modelDietary: raw?.overallDietary, modelConfidence: raw?.confidence)
        Logger.services.info("""
            AI analysis: \(category, privacy: .public) latencyMs=\(latencyMs, privacy: .public) \
            attempts=\(attempts, privacy: .public) model=\(AppConfig.geminiModelName, privacy: .public) \
            prompt=\(FoodAnalysisPrompt.promptVersion, privacy: .public)
            """)
    }

    private func logDietaryOverride(outcome: FoodAnalysisOutcome, raw: RawFoodAnalysis) {
        guard case .accepted(let result) = outcome,
              FoodAnalysisSanitizer.dietary(fromOverall: raw.overallDietary) != result.overallDietary else { return }
        Logger.services.info("AI analysis: dietary_override")
    }

    private static func category(for outcome: FoodAnalysisOutcome) -> String {
        switch outcome {
        case .accepted: "accepted"
        case .rejected(let reason): reason.rawValue
        }
    }

    #if DEBUG
    /// True when the outgoing JPEG has no GPS block and no camera or capture-time EXIF/TIFF fields.
    private static func isMetadataClean(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return false
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        return properties[kCGImagePropertyGPSDictionary] == nil
            && exif[kCGImagePropertyExifDateTimeOriginal] == nil
            && exif[kCGImagePropertyExifMakerNote] == nil
            && tiff[kCGImagePropertyTIFFMake] == nil
            && tiff[kCGImagePropertyTIFFModel] == nil
    }
    #endif
}
