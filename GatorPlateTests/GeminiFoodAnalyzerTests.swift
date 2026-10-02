import Foundation
import Testing
@testable import GatorPlate

private actor ScriptedTransport: GeminiTransport {
    private var script: [Result<String, any Error>]
    private(set) var callCount = 0
    private let hangs: Bool

    init(_ script: [Result<String, any Error>], hangs: Bool = false) {
        self.script = script
        self.hangs = hangs
    }

    func responseText(forJPEG jpeg: Data) async throws -> String {
        callCount += 1
        if hangs { try await Task.sleep(for: .seconds(60)) }
        guard !script.isEmpty else { throw AppError.aiUnavailable }
        return try script.removeFirst().get()
    }
}

private let goodJSON = #"{"isFood":true,"containsPeople":false,"confidence":0.9,"items":[{"name":"Pizza","dietary":"vegetarian","caloriesLow":250,"caloriesHigh":320}],"allergens":["milk","wheat"],"title":"FREE: Pizza","description":"Cheese pizza slices. May contain milk and wheat."}"#

struct GeminiFoodAnalyzerTests {
    private func analyzer(_ transport: ScriptedTransport, timeout: Duration = .seconds(5)) -> GeminiFoodAnalyzer {
        GeminiFoodAnalyzer(transport: transport, timeout: timeout, maxAttempts: 2)
    }

    @Test func successReturnsASanitizedOutcome() async throws {
        let transport = ScriptedTransport([.success(goodJSON)])
        let outcome = try await analyzer(transport).analyze(imageJPEG: Data([1]))
        guard case .accepted(let result) = outcome else { Issue.record("expected accepted"); return }
        #expect(result.title == "FREE: Pizza")
        #expect(result.overallDietary == .vegetarian)
        #expect(await transport.callCount == 1)
    }

    @Test func rejectionIsAValueNotAnError() async throws {
        let json = #"{"isFood":false,"containsPeople":false,"confidence":0.9}"#
        let outcome = try await analyzer(ScriptedTransport([.success(json)])).analyze(imageJPEG: Data([1]))
        #expect(outcome == .rejected(.notFood))
    }

    @Test func malformedJSONRetriesOnceThenSucceeds() async throws {
        let transport = ScriptedTransport([.success("not json"), .success(goodJSON)])
        let outcome = try await analyzer(transport).analyze(imageJPEG: Data([1]))
        #expect(outcome != .rejected(.notFood))
        #expect(await transport.callCount == 2)
    }

    @Test func malformedJSONTwiceThrowsUnavailable() async {
        let transport = ScriptedTransport([.success("{"), .success("[]")])
        await #expect(throws: AppError.aiUnavailable) { try await analyzer(transport).analyze(imageJPEG: Data([1])) }
        #expect(await transport.callCount == 2)
    }

    @Test func offlineIsNotRetried() async {
        let transport = ScriptedTransport([.failure(URLError(.notConnectedToInternet))])
        await #expect(throws: AppError.network) { try await analyzer(transport).analyze(imageJPEG: Data([1])) }
        #expect(await transport.callCount == 1)
    }

    @Test func quotaErrorsAreBusyAndNotRetried() async {
        let quota = NSError(domain: "FirebaseAILogic.BackendError", code: 429)
        let transport = ScriptedTransport([.failure(quota)])
        await #expect(throws: AppError.aiBusy) { try await analyzer(transport).analyze(imageJPEG: Data([1])) }
        #expect(await transport.callCount == 1)
    }

    @Test func appCheckRejectionIsNotRetried() async {
        let denied = NSError(domain: "FirebaseAILogic.BackendError", code: 403)
        let transport = ScriptedTransport([.failure(denied)])
        await #expect(throws: AppError.aiUnavailable) { try await analyzer(transport).analyze(imageJPEG: Data([1])) }
        #expect(await transport.callCount == 1)
    }

    @Test func serverErrorRetriesOnce() async throws {
        let server = NSError(domain: "FirebaseAILogic.BackendError", code: 503)
        let transport = ScriptedTransport([.failure(server), .success(goodJSON)])
        _ = try await analyzer(transport).analyze(imageJPEG: Data([1]))
        #expect(await transport.callCount == 2)
    }

    @Test func slowResponsesTimeOutAfterOneRetry() async {
        let transport = ScriptedTransport([], hangs: true)
        let fast = GeminiFoodAnalyzer(transport: transport, timeout: .milliseconds(50), maxAttempts: 2)
        await #expect(throws: AppError.aiTimeout) { try await fast.analyze(imageJPEG: Data([1])) }
        #expect(await transport.callCount == 2)
    }

    @Test func cancellingTheCallerThrowsCancellationWithoutRetry() async {
        let transport = ScriptedTransport([], hangs: true)
        let task = Task { try await analyzer(transport).analyze(imageJPEG: Data([1])) }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await transport.callCount == 1)
    }

    @Test func classifyMapsKnownErrors() {
        #expect(GeminiFoodAnalyzer.classify(CancellationError()) == .cancelled)
        #expect(GeminiFoodAnalyzer.classify(URLError(.cancelled)) == .cancelled)
        #expect(GeminiFoodAnalyzer.classify(URLError(.timedOut)) == .failed(.aiTimeout, retryable: true))
        #expect(GeminiFoodAnalyzer.classify(URLError(.networkConnectionLost)) == .failed(.network, retryable: false))
        #expect(GeminiFoodAnalyzer.classify(NSError(domain: "x", code: 429)) == .failed(.aiBusy, retryable: false))
        #expect(GeminiFoodAnalyzer.classify(NSError(domain: "x", code: 1)) == .failed(.aiUnavailable, retryable: true))
    }
}

struct FoodAnalysisSchemaTests {
    @Test func promptVersionAndModelAreSet() {
        #expect(!FoodAnalysisPrompt.promptVersion.isEmpty)
        #expect(AppConfig.geminiModelName.hasPrefix("gemini-"))
        #expect(!FoodAnalysisPrompt.systemInstruction.contains("overallDietary"))
    }

    @Test func noSecretsInThePrompt() {
        let text = FoodAnalysisPrompt.systemInstruction.lowercased()
        #expect(!text.contains("aiza") && !text.contains("api key"))
    }
}
