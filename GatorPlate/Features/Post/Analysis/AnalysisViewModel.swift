import Foundation
import Observation

/// Drives the Analyzing step: one analysis in flight, cancellable, with rotating status text.
@Observable
final class AnalysisViewModel {
    enum State: Equatable {
        case idle
        case analyzing(statusIndex: Int)
        case success(FoodAnalysisResult)
        case rejected(RejectionReason)
        case failed(AppError)
    }

    static let statusMessages = ["Identifying food...", "Checking allergens...", "Writing your post..."]

    private(set) var state: State = .idle
    /// True after `slowThreshold`, so the screen can say "Still working...".
    private(set) var isTakingLong = false

    private let analyzer: any FoodAnalyzing
    private let jpeg: Data
    private let statusInterval: Duration
    private let slowThreshold: Duration
    private var analysisTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var generation = 0

    init(
        analyzer: any FoodAnalyzing,
        jpeg: Data,
        statusInterval: Duration = .milliseconds(1500),
        slowThreshold: Duration = .seconds(10)
    ) {
        self.analyzer = analyzer
        self.jpeg = jpeg
        self.statusInterval = statusInterval
        self.slowThreshold = slowThreshold
    }

    var statusMessage: String {
        guard case .analyzing(let index) = state else { return "" }
        return Self.statusMessages[index % Self.statusMessages.count]
    }

    /// Starts an analysis from idle. Calling it while one is running does nothing.
    func start() {
        guard state == .idle else { return }
        begin()
    }

    /// Runs a fresh analysis after a failure or rejection.
    func retry() {
        if case .analyzing = state { return }
        begin()
    }

    /// Stops immediately. Nothing the analyzer returns afterward is applied.
    func cancel() {
        generation += 1
        analysisTask?.cancel()
        tickerTask?.cancel()
        analysisTask = nil
        tickerTask = nil
        isTakingLong = false
        if case .analyzing = state { state = .idle }
    }

    private func begin() {
        generation += 1
        let current = generation
        state = .analyzing(statusIndex: 0)
        isTakingLong = false

        let analyzer = analyzer
        let jpeg = jpeg
        analysisTask = Task { [weak self] in
            do {
                let outcome = try await analyzer.analyze(imageJPEG: jpeg)
                self?.finish(outcome, generation: current)
            } catch is CancellationError {
                return
            } catch let error as AppError {
                self?.finish(failure: error, generation: current)
            } catch {
                self?.finish(failure: .unknown, generation: current)
            }
        }
        let statusInterval = statusInterval
        let slowThreshold = slowThreshold
        tickerTask = Task { [weak self] in
            var elapsed = Duration.zero
            var index = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: statusInterval)
                if Task.isCancelled { return }
                elapsed += statusInterval
                index += 1
                self?.tick(index: index, slow: elapsed >= slowThreshold, generation: current)
            }
        }
    }

    private func tick(index: Int, slow: Bool, generation current: Int) {
        guard current == generation, case .analyzing = state else { return }
        state = .analyzing(statusIndex: index)
        isTakingLong = slow
    }

    private func finish(_ outcome: FoodAnalysisOutcome, generation current: Int) {
        guard current == generation else { return }
        tickerTask?.cancel()
        isTakingLong = false
        switch outcome {
        case .accepted(let result): state = .success(result)
        case .rejected(let reason): state = .rejected(reason)
        }
    }

    private func finish(failure error: AppError, generation current: Int) {
        guard current == generation else { return }
        tickerTask?.cancel()
        isTakingLong = false
        state = .failed(error)
    }
}

extension AppError {
    /// Friendly copy for the analyzing step. Never exposes SDK or HTTP details.
    var analysisMessage: String {
        switch self {
        case .network: "You're offline. You can still fill the post in yourself."
        case .aiBusy: "AI is busy. Try again, or fill the post in yourself."
        case .aiTimeout: "The AI took too long. Try again, or fill the post in yourself."
        default: "The AI couldn't analyze that photo. Try again, or fill the post in yourself."
        }
    }
}

extension RejectionReason {
    var title: String {
        switch self {
        case .notFood, .lowConfidence: "That doesn't look like food"
        case .containsPeople: "Please avoid photographing people"
        case .blocked: "That photo couldn't be analyzed"
        }
    }

    var detail: String {
        switch self {
        case .notFood, .lowConfidence: "Try a closer, brighter photo of the food, or fill the post in yourself."
        case .containsPeople: "Retake the photo with only the food in frame. This photo was not kept."
        case .blocked: "Try a different photo, or fill the post in yourself."
        }
    }
}
