import FirebaseAILogic
import Foundation
import OSLog

/// Raw model call, separated so retry, timeout, and decoding logic can be tested without a network.
nonisolated protocol GeminiTransport: Sendable {
    /// Returns the model's JSON text for one JPEG.
    func responseText(forJPEG jpeg: Data) async throws -> String
}

/// Firebase AI Logic (Gemini Developer API) transport. App Check protects the call; there is no API key in the app.
nonisolated struct LiveGeminiTransport: GeminiTransport {
    func responseText(forJPEG jpeg: Data) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: AppConfig.geminiModelName,
            generationConfig: FoodAnalysisSchema.generationConfig,
            systemInstruction: ModelContent(role: "system", parts: FoodAnalysisPrompt.systemInstruction),
            requestOptions: RequestOptions(timeout: TimeInterval(AppConfig.aiTimeoutSeconds))
        )
        // Only the image bytes and the instruction go out: no user identity, no metadata.
        let response = try await model.generateContent(
            InlineDataPart(data: jpeg, mimeType: "image/jpeg"),
            FoodAnalysisPrompt.userInstruction
        )
        guard let text = response.text, !text.isEmpty else { throw AppError.aiUnavailable }
        return text
    }
}

nonisolated struct GeminiFoodAnalyzer: FoodAnalyzing {
    let transport: any GeminiTransport
    let timeout: Duration
    let maxAttempts: Int

    init(
        transport: any GeminiTransport = LiveGeminiTransport(),
        timeout: Duration = .seconds(AppConfig.aiTimeoutSeconds),
        maxAttempts: Int = 2
    ) {
        self.transport = transport
        self.timeout = timeout
        self.maxAttempts = max(1, maxAttempts)
    }

    func analyze(imageJPEG: Data) async throws -> FoodAnalysisOutcome {
        let started = ContinuousClock.now
        var lastError = AppError.aiUnavailable

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                let transport = transport
                let text = try await Self.withTimeout(timeout) { try await transport.responseText(forJPEG: imageJPEG) }
                let outcome = FoodAnalysisSanitizer.sanitize(try RawFoodAnalysis.decode(text))
                Logger.ai.info("analysis ok attempt=\(attempt) ms=\(Self.milliseconds(since: started)) outcome=\(Self.label(outcome), privacy: .public)")
                return outcome
            } catch {
                let failure = Self.classify(error)
                switch failure {
                case .cancelled:
                    throw CancellationError()
                case .rejected(let reason):
                    Logger.ai.info("analysis blocked attempt=\(attempt)")
                    return .rejected(reason)
                case .failed(let appError, let retryable):
                    Logger.ai.error("analysis failed attempt=\(attempt) category=\(String(describing: appError), privacy: .public) ms=\(Self.milliseconds(since: started))")
                    lastError = appError
                    if !retryable { throw appError }
                }
            }
        }
        throw lastError
    }

    // MARK: Error classification

    enum Failure: Equatable {
        case cancelled
        case rejected(RejectionReason)
        case failed(AppError, retryable: Bool)
    }

    /// Maps SDK, URL, and app errors to a user-facing category. Retries only transient failures.
    static func classify(_ error: any Error) -> Failure {
        if error is CancellationError { return .cancelled }
        if let appError = error as? AppError {
            switch appError {
            case .aiTimeout, .aiUnavailable: return .failed(appError, retryable: true)
            default: return .failed(appError, retryable: false)
            }
        }
        if let contentError = error as? GenerateContentError {
            switch contentError {
            case .promptBlocked:
                return .rejected(.blocked)
            case .responseStoppedEarly(let reason, _):
                let blocking: [FinishReason] = [.safety, .prohibitedContent, .blocklist, .spii, .imageSafety, .imageProhibitedContent]
                return blocking.contains(reason) ? .rejected(.blocked) : .failed(.aiUnavailable, retryable: true)
            case .internalError(let underlying):
                return classify(underlying)
            case .promptImageContentError:
                return .failed(.aiUnavailable, retryable: false)
            @unknown default:
                return .failed(.aiUnavailable, retryable: true)
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled: return .cancelled
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return .failed(.network, retryable: false)
            case .timedOut: return .failed(.aiTimeout, retryable: true)
            default: return .failed(.network, retryable: true)
            }
        }
        // Backend errors are internal to the SDK but expose the HTTP status as the NSError code.
        let nsError = error as NSError
        switch nsError.code {
        case 429: return .failed(.aiBusy, retryable: false)
        case 401, 403: return .failed(.aiUnavailable, retryable: false)
        case 500...599: return .failed(.aiUnavailable, retryable: true)
        default: return .failed(.aiUnavailable, retryable: true)
        }
    }

    // MARK: Helpers

    /// Races the operation against a timer. Cancelling the caller cancels both.
    static func withTimeout<T: Sendable>(
        _ timeout: Duration,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AppError.aiTimeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw AppError.aiTimeout }
            return first
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let parts = (ContinuousClock.now - start).components
        return Int(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)
    }

    /// Category only; never the content.
    private static func label(_ outcome: FoodAnalysisOutcome) -> String {
        switch outcome {
        case .accepted: "accepted"
        case .rejected(let reason): "rejected-\(reason)"
        }
    }
}
