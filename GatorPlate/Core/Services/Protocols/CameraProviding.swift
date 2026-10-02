import AVFoundation
import Foundation

nonisolated enum CameraAuthorization: Equatable, Sendable {
    case notDetermined
    /// Denied by the user or restricted on the device. Both are fixed in Settings.
    case denied
    case authorized

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied, .restricted: self = .denied
        @unknown default: self = .denied
        }
    }
}

nonisolated enum CameraEvent: Equatable, Sendable {
    case interrupted
    case interruptionEnded
    case runtimeError
}

nonisolated enum FlashMode: CaseIterable, Equatable, Sendable {
    case off, auto, on

    var next: FlashMode {
        switch self {
        case .off: .auto
        case .auto: .on
        case .on: .off
        }
    }

    var title: String {
        switch self {
        case .off: "Off"
        case .auto: "Auto"
        case .on: "On"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "bolt.slash.fill"
        case .auto: "bolt.badge.automatic.fill"
        case .on: "bolt.fill"
        }
    }
}

nonisolated enum CameraError: Error, Equatable, Sendable {
    /// No camera on this device (the simulator) or it could not be configured.
    case unavailable
    case notAuthorized
    case captureFailed
    case invalidImage
}

/// Carries the capture session to the preview layer. The session is only ever configured and started
/// inside `CameraService`; the preview layer just displays it, which is Apple's documented pattern.
nonisolated struct CameraSessionBox: @unchecked Sendable {
    let session: AVCaptureSession
    let device: AVCaptureDevice?

    var supportsFlash: Bool { device?.hasFlash ?? false }
}

nonisolated protocol CameraProviding: Sendable {
    /// Nil for mocks, which have nothing to preview.
    var previewSession: CameraSessionBox? { get }

    /// Interruption and error events. Single consumer.
    var events: AsyncStream<CameraEvent> { get }

    func authorizationStatus() async -> CameraAuthorization

    /// Shows the system camera prompt. Call only after our own explanation.
    func requestAccess() async -> CameraAuthorization

    /// Starts the session off the main thread. Idempotent. Throws `CameraError`.
    func start() async throws

    /// Stops the session so the camera-in-use indicator goes away. Idempotent.
    func stop() async

    /// Returns the encoded full-size photo. The caller must downscale it right away.
    /// - Parameter rotationAngle: degrees from `AVCaptureDevice.RotationCoordinator`.
    func capturePhoto(flash: FlashMode, rotationAngle: CGFloat) async throws -> Data

    /// Focus and expose at a point in capture-device coordinates (0...1).
    func focus(at devicePoint: CGPoint) async
}
