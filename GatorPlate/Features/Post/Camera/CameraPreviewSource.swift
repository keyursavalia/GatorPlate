import AVFoundation

/// Bridges the actor-owned capture session to the main-actor preview layer.
///
/// `@unchecked Sendable`: `session` is only handed to the layer (Apple allows setting
/// `AVCaptureVideoPreviewLayer.session` from any thread), and `layer` is only touched on the main actor.
nonisolated final class CameraPreviewSource: @unchecked Sendable {
    private let session: AVCaptureSession?
    @MainActor private weak var layer: AVCaptureVideoPreviewLayer?

    /// `nil` for mocks: the preview stays black.
    init(session: AVCaptureSession?) {
        self.session = session
    }

    @MainActor
    func connect(to layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
        self.layer = layer
    }

    /// Keeps the preview level as the device rotates. Callable from any thread.
    func setPreviewRotation(_ angle: CGFloat) {
        Task { @MainActor in
            guard let connection = layer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}
