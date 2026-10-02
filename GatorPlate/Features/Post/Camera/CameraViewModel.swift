import Observation
import OSLog
import SwiftUI

enum CameraPhase: Equatable {
    case checking
    /// Not asked yet: explain first, then show the system prompt.
    case needsExplanation
    case ready
    case denied
    /// No camera (simulator) or it could not start. The library picker still works.
    case unavailable
}

@Observable
final class CameraViewModel {
    private(set) var phase: CameraPhase = .checking
    private(set) var isCapturing = false
    private(set) var isProcessing = false
    /// An interruption (phone call, another app using the camera) is in progress.
    private(set) var isPaused = false
    private(set) var errorMessage: String?
    /// Increments on every shutter press; drives the haptic and the flash animation.
    private(set) var shutterCount = 0
    private(set) var supportsFlash = false
    var flash: FlashMode = .auto

    private let camera: any CameraProviding
    private let onPhoto: (CapturedPhoto) -> Void

    init(camera: any CameraProviding, onPhoto: @escaping (CapturedPhoto) -> Void) {
        self.camera = camera
        self.onPhoto = onPhoto
    }

    var canCapture: Bool {
        phase == .ready && !isCapturing && !isProcessing && !isPaused
    }

    // MARK: Permission and session

    /// Maps the current authorization to a phase and starts the session when allowed. Safe to call repeatedly.
    func refresh() async {
        switch await camera.authorizationStatus() {
        case .notDetermined:
            phase = .needsExplanation
        case .denied:
            await camera.stop()
            phase = .denied
        case .authorized:
            await startCamera()
        }
    }

    /// Called from the explanation screen, after our own copy.
    func requestAccess() async {
        _ = await camera.requestAccess()
        await refresh()
    }

    func stop() async {
        await camera.stop()
    }

    func observeEvents() async {
        for await event in camera.events {
            switch event {
            case .interrupted:
                isPaused = true
            case .interruptionEnded:
                isPaused = false
                await startCamera()
            case .runtimeError:
                isPaused = true
                await startCamera()
                isPaused = false
            }
        }
    }

    private func startCamera() async {
        do {
            try await camera.start()
            supportsFlash = camera.previewSession?.supportsFlash ?? false
            phase = .ready
        } catch CameraError.notAuthorized {
            phase = .denied
        } catch {
            Logger.camera.error("Camera did not start")
            phase = .unavailable
        }
    }

    // MARK: Capture

    func capture(rotationAngle: CGFloat) async {
        guard canCapture else { return }
        isCapturing = true
        errorMessage = nil
        shutterCount += 1
        defer { isCapturing = false }
        do {
            let data = try await camera.capturePhoto(flash: flash, rotationAngle: rotationAngle)
            await deliver(data)
        } catch {
            errorMessage = "Couldn't take the photo. Try again."
        }
    }

    /// Library photos go through the same pipeline as camera photos.
    func handlePickedData(_ data: Data) async {
        errorMessage = nil
        await deliver(data)
    }

    func libraryLoadFailed() {
        errorMessage = "Couldn't open that photo. Try another one."
    }

    func cycleFlash() {
        flash = flash.next
    }

    func focus(at devicePoint: CGPoint) async {
        await camera.focus(at: devicePoint)
    }

#if DEBUG
    private var sampleIndex = 0

    /// Simulator helper: feeds a generated food photo through the real pipeline.
    func useSamplePhoto() async {
        let data = PlaceholderImage.jpegData(variant: sampleIndex)
        sampleIndex += 1
        await handlePickedData(data)
    }
#endif

    private func deliver(_ data: Data) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let photo = try await ImagePreprocessor.processInBackground(data: data)
            onPhoto(photo)
        } catch {
            errorMessage = "Couldn't read that photo. Try again."
        }
    }
}
