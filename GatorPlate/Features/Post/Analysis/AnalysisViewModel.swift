import Foundation
import Observation

/// Runs one AI analysis for the post's 1-4 photos, with a step checklist that advances on a timer (all checked on
/// success), a slow-response hint and cancellation.
@MainActor
@Observable
final class AnalysisViewModel {
    enum State: Equatable {
        case idle
        case analyzing
        case success(FoodAnalysisResult)
        case rejected(FoodAnalysisRejection)
        case failed(AppError)
    }

    private(set) var state: State = .idle
    /// Checklist steps done so far. The last one is checked only when the draft is ready.
    private(set) var completedSteps = 0
    /// True after `AppConfig.aiSlowThresholdSeconds`; a "Still working…" line appears.
    private(set) var isSlow = false
    /// DEBUG only: content-free CSV line for the evaluation report.
    private(set) var evalLine: String?

    let photos: [CapturedPhoto]
    private let analyzer: any FoodAnalyzing
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    init(photos: [CapturedPhoto], analyzer: any FoodAnalyzing) {
        self.photos = photos
        self.analyzer = analyzer
    }

    var steps: [String] {
        [photos.count == 1 ? "Looking at your photo" : "Looking at \(photos.count) photos",
         "Checking allergens",
         "Writing the description"]
    }

    func start() {
        guard analysisTask == nil else { return }
        state = .analyzing
        completedSteps = 0
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
        let ticker = Task { [weak self] in await self?.advanceSteps() }
        defer {
            ticker.cancel()
            analysisTask = nil
        }
        do {
            let data = try await requestData()
            switch try await analyzer.analyze(photos: data) {
            case .accepted(let result):
                completedSteps = steps.count
                state = .success(result)
            case .rejected(let reason):
                state = .rejected(reason)
            }
        } catch {
            state = error == .cancelled ? .idle : .failed(error)
        }
        #if DEBUG
        evalLine = AnalysisEvalLine.make(state: state, diagnostics: analyzer.lastDiagnostics)
        #endif
    }

    /// With 3+ photos each is shrunk to `aiMultiPhotoLongEdge` (fewer image tokens, faster).
    private func requestData() async throws(AppError) -> [Data] {
        guard photos.count >= AppConfig.aiMultiPhotoDownscaleThreshold else { return photos.map(\.jpegData) }
        let preprocessor = ImagePreprocessor(maxLongEdge: AppConfig.aiMultiPhotoLongEdge)
        var data: [Data] = []
        for photo in photos {
            if Task.isCancelled { throw .cancelled }
            data.append(try await preprocessor.downscaledJPEG(photo.jpegData))
        }
        return data
    }

    private func advanceSteps() async {
        let start = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(AppConfig.aiChecklistStepSeconds))
            guard !Task.isCancelled, state == .analyzing else { return }
            if completedSteps < steps.count - 1 { completedSteps += 1 }
            if start.duration(to: .now) >= .seconds(AppConfig.aiSlowThresholdSeconds) { isSlow = true }
        }
    }
}
