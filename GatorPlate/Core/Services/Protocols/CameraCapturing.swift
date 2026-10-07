import CoreGraphics
import Foundation

nonisolated enum CameraFlashMode: CaseIterable, Sendable {
    case off
    case auto
    case on
}

/// Why the session paused. The session resumes on its own when the interruption ends.
nonisolated enum CameraInterruption: Equatable, Sendable {
    case background
    case inUseByAnotherApp
    case multitasking
    case systemPressure
    case other
}

nonisolated enum CameraEvent: Equatable, Sendable {
    /// The shutter fired; drives the haptic and the flash animation.
    case willCapture
    case interrupted(CameraInterruption)
    case resumed
    case failed
}

/// In-app photo camera. The live implementation is an actor that owns the `AVCaptureSession`.
nonisolated protocol CameraCapturing: AnyObject, Sendable {
    /// Hands the session to the on-screen preview layer.
    var previewSource: CameraPreviewSource { get }
    /// False on the Simulator or a device without a back camera.
    var isCameraAvailable: Bool { get }
    var canSwitchCamera: Bool { get }

    func authorization() async -> CameraAuthorization
    /// Shows the system prompt. Call only after the in-app explanation.
    func requestAccess() async -> CameraAuthorization
    /// A fresh stream for the current screen; finishes the previous one.
    func events() async -> AsyncStream<CameraEvent>
    /// Configures on first use, then starts the session. Off the main thread.
    func start() async throws(AppError)
    func stop() async
    func supportedFlashModes() async -> [CameraFlashMode]
    /// Encoded photo data (HEIC or JPEG) at reduced resolution; run it through `ImagePreprocessor`.
    func capturePhoto(flash: CameraFlashMode) async throws(AppError) -> Data
    /// `devicePoint` is in the capture device's normalized (0...1) space.
    func focus(at devicePoint: CGPoint) async
    /// Flips front/back and returns the new camera's flash modes.
    func switchCamera() async throws(AppError) -> [CameraFlashMode]
}
