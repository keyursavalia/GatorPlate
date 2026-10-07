import Foundation
import Observation

/// Runs one AI analysis for a photo, with rotating status text, a slow-response hint and cancellation.
@MainActor
@Observable
final class AnalysisViewModel {
    enum State: Equatable {
        case idle
        case analyzing(statusIndex: Int)
        case success(FoodAnalysisResult)
        case rejected(FoodAnalysisRejection)
        case failed(AppError)
    }

    static let statusMessages = ["Identifying food…", "Checking allergens…", "Writing your post…"]

    private(set) var state: State = .idle
    /// True after `AppConfig.aiSlowThresholdSeconds`; the status line becomes "Still working…".
    private(set) var isSlow = false
    /// DEBUG only: content-free CSV line for the evaluation report.
    private(set) var evalLine: String?

    let photo: CapturedPhoto
    private let analyzer: any FoodAnalyzing
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    init(photo: CapturedPhoto, analyzer: any FoodAnalyzing) {
        self.photo = photo
        self.analyzer = analyzer
    }

    var statusMessage: String {
        guard !isSlow else { return "Still working…" }
        if case .analyzing(let index) = state { return Self.statusMessages[index % Self.statusMessages.count] }
        return Self.statusMessages[0]
    }

    func start() {
        guard analysisTask == nil else { return }
        state = .analyzing(statusIndex: 0)
        isSlow = false
        evalLine = nil
        analysisTask = Task { [weak self] in
            await self?.run()
        }
    }

    func retry() {
        guard case .failed = state else { return }
        start()
    }

    func cancel() {
        analysisTask?.cancel()
    }

    private func run() async {
        let ticker = Task { [weak self] in await self?.rotateStatus() }
        defer {
            ticker.cancel()
            analysisTask = nil
        }
        do {
            switch try await analyzer.analyze(jpegData: photo.jpegData) {
            case .accepted(let result): state = .success(result)
            case .rejected(let reason): state = .rejected(reason)
            }
        } catch {
            state = error == .cancelled ? .idle : .failed(error)
        }
        #if DEBUG
        evalLine = AnalysisEvalLine.make(state: state, diagnostics: analyzer.lastDiagnostics)
        #endif
    }

    private func rotateStatus() async {
        let start = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(AppConfig.aiStatusRotationSeconds))
            guard !Task.isCancelled, case .analyzing(let index) = state else { return }
            state = .analyzing(statusIndex: index + 1)
            if start.duration(to: .now) >= .seconds(AppConfig.aiSlowThresholdSeconds) { isSlow = true }
        }
    }
}
