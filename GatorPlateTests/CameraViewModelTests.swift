import AVFoundation
import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct CameraAuthorizationTests {
    @Test func mapsEveryAVStatus() {
        #expect(CameraAuthorization(.notDetermined) == .notDetermined)
        #expect(CameraAuthorization(.authorized) == .authorized)
        #expect(CameraAuthorization(.denied) == .denied)
        #expect(CameraAuthorization(.restricted) == .denied)
    }

    @Test func flashCyclesThroughEveryMode() {
        #expect(FlashMode.off.next == .auto)
        #expect(FlashMode.auto.next == .on)
        #expect(FlashMode.on.next == .off)
    }
}

@MainActor
struct CameraViewModelTests {
    private final class PhotoSink {
        var photos: [CapturedPhoto] = []
    }

    private func makeModel(_ camera: MockCameraService, sink: PhotoSink = PhotoSink()) -> CameraViewModel {
        CameraViewModel(camera: camera, onPhoto: { sink.photos.append($0) })
    }

    // MARK: Permission flow

    @Test func startsInCheckingState() {
        #expect(makeModel(MockCameraService()).phase == .checking)
    }

    @Test func notDeterminedShowsTheExplanationAndDoesNotStart() async {
        let camera = MockCameraService(authorization: .notDetermined)
        let model = makeModel(camera)
        await model.refresh()
        #expect(model.phase == .needsExplanation)
        #expect(await camera.startCount == 0)
    }

    @Test func grantingAccessStartsTheCamera() async {
        let camera = MockCameraService(authorization: .notDetermined, grantsAccess: true)
        let model = makeModel(camera)
        await model.refresh()
        await model.requestAccess()
        #expect(model.phase == .ready)
        #expect(await camera.startCount == 1)
    }

    @Test func decliningAccessShowsDenied() async {
        let camera = MockCameraService(authorization: .notDetermined, grantsAccess: false)
        let model = makeModel(camera)
        await model.refresh()
        await model.requestAccess()
        #expect(model.phase == .denied)
    }

    @Test func deniedOrRestrictedShowsDeniedAndStopsTheCamera() async {
        let camera = MockCameraService(authorization: .denied)
        let model = makeModel(camera)
        await model.refresh()
        #expect(model.phase == .denied)
        #expect(await camera.startCount == 0)
        #expect(await camera.stopCount == 1)
    }

    @Test func returningFromSettingsWithAccessGoesToReady() async {
        let camera = MockCameraService(authorization: .denied)
        let model = makeModel(camera)
        await model.refresh()
        await camera.setAuthorization(.authorized)
        await model.refresh()
        #expect(model.phase == .ready)
    }

    @Test func noCameraShowsUnavailable() async {
        let model = makeModel(MockCameraService(hasCamera: false))
        await model.refresh()
        #expect(model.phase == .unavailable)
    }

    @Test func stopStopsTheCamera() async {
        let camera = MockCameraService()
        let model = makeModel(camera)
        await model.refresh()
        await model.stop()
        #expect(await camera.stopCount == 1)
    }

    // MARK: Capture

    @Test func captureDeliversAProcessedPhoto() async throws {
        let camera = MockCameraService()
        let sink = PhotoSink()
        let model = makeModel(camera, sink: sink)
        await model.refresh()
        model.flash = .on

        await model.capture(rotationAngle: 90)

        #expect(sink.photos.count == 1)
        let photo = try #require(sink.photos.first)
        #expect(max(photo.pixelSize.width, photo.pixelSize.height) <= CGFloat(AppConfig.aiMaxImageLongEdge))
        #expect(await camera.lastFlash == .on)
        #expect(await camera.lastRotationAngle == 90)
        #expect(model.errorMessage == nil)
        #expect(model.shutterCount == 1)
        #expect(model.canCapture)
    }

    @Test func captureFailureShowsAnErrorAndReEnablesTheShutter() async {
        let camera = MockCameraService(captureResult: .failure(.captureFailed))
        let sink = PhotoSink()
        let model = makeModel(camera, sink: sink)
        await model.refresh()

        await model.capture(rotationAngle: 90)

        #expect(sink.photos.isEmpty)
        #expect(model.errorMessage != nil)
        #expect(model.canCapture)
    }

    @Test func undecodableCaptureShowsAnError() async {
        let camera = MockCameraService(captureResult: .success(Data("junk".utf8)))
        let sink = PhotoSink()
        let model = makeModel(camera, sink: sink)
        await model.refresh()

        await model.capture(rotationAngle: 90)

        #expect(sink.photos.isEmpty)
        #expect(model.errorMessage != nil)
    }

    @Test func captureIsIgnoredUntilTheCameraIsReady() async {
        let camera = MockCameraService(authorization: .denied)
        let model = makeModel(camera)
        await model.refresh()
        await model.capture(rotationAngle: 90)
        #expect(await camera.captureCount == 0)
    }

    // MARK: Library fallback

    @Test func libraryPhotoProducesTheSameKindOfPhoto() async {
        let camera = MockCameraService(authorization: .denied)
        let sink = PhotoSink()
        let model = makeModel(camera, sink: sink)
        await model.refresh()

        await model.handlePickedData(PlaceholderImage.jpegData(variant: 1))

        #expect(sink.photos.count == 1)
        #expect(Array(sink.photos[0].jpegData.prefix(2)) == [0xFF, 0xD8])
    }

    @Test func badLibraryDataShowsAnError() async {
        let sink = PhotoSink()
        let model = makeModel(MockCameraService(authorization: .denied), sink: sink)
        await model.handlePickedData(Data("junk".utf8))
        #expect(sink.photos.isEmpty)
        #expect(model.errorMessage != nil)
    }

#if DEBUG
    @Test func samplePhotoGoesThroughThePipeline() async {
        let sink = PhotoSink()
        let model = makeModel(MockCameraService(hasCamera: false), sink: sink)
        await model.useSamplePhoto()
        await model.useSamplePhoto()
        #expect(sink.photos.count == 2)
        #expect(sink.photos[0] != sink.photos[1])
    }
#endif

    // MARK: Interruptions

    @Test func interruptionPausesAndEndingItRestarts() async {
        let camera = MockCameraService()
        let model = makeModel(camera)
        await model.refresh()
        let listener = Task { await model.observeEvents() }
        defer { listener.cancel() }

        await camera.send(.interrupted)
        #expect(await waitUntil { model.isPaused })
        #expect(!model.canCapture)

        await camera.send(.interruptionEnded)
        #expect(await waitUntil { !model.isPaused })
        #expect(await camera.startCount == 2)
        #expect(model.canCapture)
    }
}

@MainActor
struct PostFlowCoordinatorTests {
    private func photo() throws -> CapturedPhoto {
        try ImagePreprocessor.process(data: PlaceholderImage.jpegData())
    }

    @Test func startsOnTheCamera() {
        #expect(PostFlowCoordinator().step == .camera)
    }

    @Test func cameraToPreviewToAnalysis() throws {
        let coordinator = PostFlowCoordinator()
        let taken = try photo()
        coordinator.captured(taken)
        #expect(coordinator.step == .preview(taken))
        coordinator.usePhoto()
        #expect(coordinator.step == .analysis(taken))
    }

    @Test func retakeReturnsToTheCamera() throws {
        let coordinator = PostFlowCoordinator()
        coordinator.captured(try photo())
        coordinator.retake()
        #expect(coordinator.step == .camera)
    }

    @Test func fillManuallyLeavesAnalysisForManualEntry() throws {
        let coordinator = PostFlowCoordinator()
        let taken = try photo()
        coordinator.captured(taken)
        coordinator.usePhoto()
        coordinator.fillManually()
        #expect(coordinator.step == .review(photo: taken, analysis: nil))
    }

    @Test func fillManuallyFromTheCameraSkipsThePhoto() {
        let coordinator = PostFlowCoordinator()
        coordinator.fillManually()
        #expect(coordinator.step == .review(photo: nil, analysis: nil))
    }

    @Test func fillManuallyFromThePreviewKeepsThePhoto() throws {
        let coordinator = PostFlowCoordinator()
        let taken = try photo()
        coordinator.captured(taken)
        coordinator.fillManually()
        #expect(coordinator.step == .review(photo: taken, analysis: nil))
    }

    @Test func acceptedAnalysisOpensTheReviewForm() throws {
        let coordinator = PostFlowCoordinator()
        let taken = try photo()
        coordinator.captured(taken)
        coordinator.usePhoto()
        coordinator.analysisAccepted(SampleData.analysis)
        #expect(coordinator.step == .review(photo: taken, analysis: SampleData.analysis))
    }

    @Test func acceptedAnalysisIsIgnoredOutsideAnalysis() {
        let coordinator = PostFlowCoordinator()
        coordinator.analysisAccepted(SampleData.analysis)
        #expect(coordinator.step == .camera)
    }

    @Test func retakeFromReviewReturnsToTheCamera() {
        let coordinator = PostFlowCoordinator()
        coordinator.fillManually()
        coordinator.retake()
        #expect(coordinator.step == .camera)
    }

    @Test func usePhotoDoesNothingWithoutAPreview() {
        let coordinator = PostFlowCoordinator()
        coordinator.usePhoto()
        #expect(coordinator.step == .camera)
    }
}
