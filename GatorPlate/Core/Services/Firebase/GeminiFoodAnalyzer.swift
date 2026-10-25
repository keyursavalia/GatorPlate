import FirebaseAILogic
import FirebaseAppCheck
import Foundation
import ImageIO
import OSLog

/// Live food analysis: Gemini through Firebase AI Logic (Gemini Developer API backend, App Check enforced).
/// The request carries only the stripped JPEGs (each labeled "Photo N:") and fixed instruction text, never user identity.
/// Model name, fallbacks, thinking level and limits come from Remote Config (`RuntimeConfig`), read once per analysis.
/// A retired model moves to the next one in the chain (`GeminiModelChain`); when all fail, the user fills the post in.
@MainActor
final class GeminiFoodAnalyzer: FoodAnalyzing {
    private let runtime: any RuntimeConfigProviding
    private let modelMemory = GeminiModelMemory()
    /// Created on first use (after `FirebaseApp.configure()`) and rebuilt when its settings change.
    private var model: GenerativeModel?
    private var modelKey: ModelKey?
    private var isAnalyzing = false

    private static let maxAttempts = 2

    /// The settings a `GenerativeModel` is built with.
    private struct ModelKey: Equatable {
        let name: String
        let thinking: AIThinkingLevel
        let temperature: Double
        let maxOutputTokens: Int
        let timeoutSeconds: Int
    }

    private enum AttemptResult {
        case decoded(RawFoodAnalysis)
        /// Safety filters: treated as "not food" (AI spec section 6).
        case blocked
        case retryable(category: String)
        /// The backend rejected the request's credentials (401). Usually a stale or placeholder App Check
        /// token after a failed refresh; a forced refresh and one retry fixes it.
        case unauthenticated(category: String)
        case fatal(AppError, category: String)
        /// The model is retired or unknown: try the next model in the chain.
        case modelUnavailable(category: String)
        /// The model rejected the thinking config: retry once without one.
        case thinkingRejected
        case cancelled
    }

    init(runtime: any RuntimeConfigProviding) {
        self.runtime = runtime
    }

    private struct AnalysisTimeout: Error {}

    func prepare() {
        // Fire and forget: if the token is fresh this returns at once, otherwise it refreshes now,
        // seconds before the request needs it (a token expired overnight is the common case).
        Task { _ = await Self.refreshAppCheckToken(forcingRefresh: false) }
    }

    func analyze(photos: [Data]) async throws(AppError) -> FoodAnalysisOutcome {
        guard !photos.isEmpty else { throw .validation("Add a photo first.") }
        guard !isAnalyzing else { throw .aiBusy }
        isAnalyzing = true
        defer { isAnalyzing = false }

        #if DEBUG
        let clean = photos.allSatisfy(Self.isMetadataClean)
        Logger.services.debug("AI request images metadata clean: \(clean, privacy: .public), count: \(photos.count, privacy: .public)")
        #endif

        // One snapshot per analysis; a publish mid-request applies to the next one.
        let config = runtime.current
        var chain = modelMemory.chain(for: config)
        var thinking = config.aiThinkingLevel
        let deadlineSeconds = FoodAnalysisDeadline.seconds(photoCount: photos.count, base: config.aiTimeoutSeconds,
                                                           max: config.aiMaxTimeoutSeconds)
        let start = ContinuousClock.now
        /// Requests sent (logged); `attempt` is the retry budget, which model fallbacks don't use up.
        var requests = 0
        var attempt = 0
        while true {
            attempt += 1
            requests += 1
            let key = ModelKey(name: chain.current, thinking: thinking, temperature: config.aiTemperature,
                               maxOutputTokens: config.aiMaxOutputTokens, timeoutSeconds: config.aiMaxTimeoutSeconds)
            let result = await runAttempt(photos, model: generativeModel(for: key), deadlineSeconds: deadlineSeconds)
            let modelName = chain.current
            switch result {
            case .decoded(let raw):
                modelMemory.markWorking(chain)
                let outcome = FoodAnalysisSanitizer.sanitize(raw, photoCount: photos.count,
                                                             promptVersion: FoodAnalysisPrompt.promptVersion,
                                                             modelName: modelName, minConfidence: config.aiMinConfidence)
                finish(start: start, attempts: requests, category: Self.category(for: outcome), model: modelName)
                logDietaryOverride(outcome: outcome, raw: raw)
                return outcome
            case .blocked:
                modelMemory.markWorking(chain)
                finish(start: start, attempts: requests, category: "safety_blocked", model: modelName)
                return .rejected(.notFood)
            case .cancelled:
                finish(start: start, attempts: requests, category: "cancelled", model: modelName)
                throw .cancelled
            case .fatal(let error, let category):
                finish(start: start, attempts: requests, category: category, model: modelName)
                throw error
            case .modelUnavailable(let category):
                // Doesn't use up the retry budget, but stays inside one deadline's worth of time.
                let withinDeadline = start.duration(to: .now) < .seconds(deadlineSeconds)
                guard withinDeadline, chain.advance() else {
                    finish(start: start, attempts: requests, category: category, model: modelName)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI model fallback: \(modelName, privacy: .public) -> \(chain.current, privacy: .public)")
                attempt -= 1
            case .thinkingRejected:
                guard thinking != .off, attempt < Self.maxAttempts else {
                    finish(start: start, attempts: requests, category: "thinking_rejected", model: modelName)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI thinking config rejected by \(modelName, privacy: .public); retrying without it")
                thinking = .off
            case .unauthenticated(let category):
                guard attempt < Self.maxAttempts else {
                    finish(start: start, attempts: requests, category: category, model: modelName)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI attempt \(attempt, privacy: .public) failed: \(category, privacy: .public); refreshing App Check and retrying")
                let refreshed = await Self.refreshAppCheckToken(forcingRefresh: true)
                Logger.services.notice("App Check refresh before retry: \(refreshed ? "ok" : "failed", privacy: .public)")
            case .retryable(let category):
                guard attempt < Self.maxAttempts else {
                    finish(start: start, attempts: requests, category: category, model: modelName)
                    throw .aiUnavailable
                }
                Logger.services.notice("AI attempt \(attempt, privacy: .public) failed: \(category, privacy: .public); retrying")
                do {
                    try await Task.sleep(for: .seconds(AppConfig.aiRetryDelaySeconds))
                } catch {
                    finish(start: start, attempts: requests, category: "cancelled", model: modelName)
                    throw .cancelled
                }
            }
        }
    }

    // MARK: Request

    /// One user turn: "Photo 1:", image, "Photo 2:", image, ..., then the instruction.
    private func runAttempt(_ photos: [Data], model: GenerativeModel, deadlineSeconds: Int) async -> AttemptResult {
        let text: String?
        do {
            text = try await Self.withTimeout(seconds: deadlineSeconds) {
                var parts: [any Part] = []
                for (offset, jpeg) in photos.enumerated() {
                    parts.append(TextPart(FoodAnalysisPrompt.photoLabel(offset + 1)))
                    parts.append(InlineDataPart(data: jpeg, mimeType: "image/jpeg"))
                }
                parts.append(TextPart(FoodAnalysisPrompt.userText))
                return try await model.generateContent([ModelContent(role: "user", parts: parts)]).text
            }
        } catch {
            return Task.isCancelled ? .cancelled : Self.classify(error)
        }
        guard let text, let raw = FoodAnalysisSanitizer.decode(text) else {
            return .retryable(category: "malformed_json")
        }
        return .decoded(raw)
    }

    /// The cached model, rebuilt only when its settings change.
    private func generativeModel(for key: ModelKey) -> GenerativeModel {
        if let model, modelKey == key { return model }
        let config = GenerationConfig(
            temperature: Float(key.temperature),
            maxOutputTokens: key.maxOutputTokens,
            responseMIMEType: "application/json",
            responseSchema: FoodAnalysisSchema.response,
            thinkingConfig: Self.thinkingConfig(key.thinking))
        let newModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: key.name,
            generationConfig: config,
            systemInstruction: ModelContent(role: "system", parts: FoodAnalysisPrompt.systemInstruction),
            requestOptions: RequestOptions(timeout: TimeInterval(key.timeoutSeconds)))
        model = newModel
        modelKey = key
        return newModel
    }

    private static func thinkingConfig(_ level: AIThinkingLevel) -> ThinkingConfig? {
        switch level {
        case .minimal: ThinkingConfig(thinkingLevel: .minimal)
        case .low: ThinkingConfig(thinkingLevel: .low)
        case .medium: ThinkingConfig(thinkingLevel: .medium)
        case .high: ThinkingConfig(thinkingLevel: .high)
        case .off: nil
        }
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

    /// Backend errors surface as `NSError` whose code is the HTTP status (`GeminiBackendError`).
    private static func classifyUnderlying(_ error: any Error) -> AttemptResult {
        if let urlError = error as? URLError { return classify(urlError) }
        let nsError = error as NSError
        let kind = GeminiBackendError.classify(nsError)
        if kind != .notBackend, (400...499).contains(nsError.code) {
            // The backend's explanation (e.g. App Check, API key or model problems); never contains the photo or prompt.
            let reason = String(nsError.localizedDescription.prefix(300))
            Logger.services.error("AI backend \(nsError.code, privacy: .public): \(reason, privacy: .public)")
        }
        switch kind {
        case .notBackend: return .fatal(.aiUnavailable, category: "unexpected_error")
        case .modelUnavailable(let category): return .modelUnavailable(category: category)
        case .thinkingRejected: return .thinkingRejected
        case .rateLimited: return .fatal(.aiBusy, category: "rate_limited")
        case .unauthenticated: return .unauthenticated(category: "forbidden_401")
        case .forbidden: return .fatal(.aiUnavailable, category: "forbidden_403")
        case .server(let code): return .retryable(category: "server_\(code)")
        case .other(let code): return .fatal(.aiUnavailable, category: "http_\(code)")
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

    // MARK: Logs (no content ever)

    /// One log line per analysis: outcome or error category, latency, requests sent and model.
    private func finish(start: ContinuousClock.Instant, attempts: Int, category: String, model: String) {
        let latencyMs = Int(start.duration(to: .now) / .milliseconds(1))
        Logger.services.info("""
            AI analysis: \(category, privacy: .public) latencyMs=\(latencyMs, privacy: .public) \
            attempts=\(attempts, privacy: .public) model=\(model, privacy: .public) \
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
