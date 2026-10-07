import Foundation
import Observation

/// Post flow steps: camera -> preview -> AI analysis -> results (read-only until Sprint 05), or manual entry.
@MainActor
@Observable
final class PostFlowModel {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        /// Analyzing, then results, rejection or failure; see `analysis.state`.
        case analysis(CapturedPhoto)
        /// "Fill it in myself". Nil photo when none was kept.
        case manual(CapturedPhoto?)
    }

    private(set) var step: Step = .camera
    /// Kept across retakes so the camera keeps its flash setting and configured session.
    let camera: CameraViewModel
    private(set) var analysis: AnalysisViewModel?
    private let analyzer: any FoodAnalyzing

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing) {
        self.camera = CameraViewModel(camera: camera)
        self.analyzer = analyzer
    }

    func didTake(_ photo: CapturedPhoto) {
        step = .preview(photo)
    }

    /// Drops the photo (and any analysis) and returns to the camera.
    func retake() {
        endAnalysis()
        step = .camera
    }

    /// Switches to the Analyzing screen immediately, then starts the request.
    func usePhoto() {
        guard case .preview(let photo) = step else { return }
        let analysis = AnalysisViewModel(photo: photo, analyzer: analyzer)
        self.analysis = analysis
        step = .analysis(photo)
        analysis.start()
    }

    /// Cancel on the Analyzing screen: back to the photo, nothing lost.
    func cancelAnalysis() {
        guard case .analysis(let photo) = step else { return }
        endAnalysis()
        step = .preview(photo)
    }

    /// Manual entry is always available. A photo rejected for showing people is not carried over.
    func fillManually() {
        var photo: CapturedPhoto?
        switch step {
        case .preview(let current), .analysis(let current): photo = current
        case .camera, .manual: photo = nil
        }
        if analysis?.state == .rejected(.containsPeople) { photo = nil }
        endAnalysis()
        step = .manual(photo)
    }

    func close() {
        endAnalysis()
    }

    private func endAnalysis() {
        analysis?.cancel()
        analysis = nil
    }
}
