@preconcurrency import AVFoundation
import OSLog

/// Owns the `AVCaptureSession`. Everything that touches the session runs on this actor's executor, never the
/// main thread, so the blocking `startRunning()` / `stopRunning()` calls cannot hang the UI.
actor CameraService: CameraProviding {
    nonisolated let previewSession: CameraSessionBox?
    nonisolated let events: AsyncStream<CameraEvent>

    private let session = AVCaptureSession()
    private let device: AVCaptureDevice?
    private let photoOutput = AVCapturePhotoOutput()
    private let eventContinuation: AsyncStream<CameraEvent>.Continuation
    private var isConfigured = false
    private var observers: [Task<Void, Never>] = []

    init() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        self.device = device
        previewSession = CameraSessionBox(session: session, device: device)
        (events, eventContinuation) = AsyncStream.makeStream(of: CameraEvent.self)
    }

    // MARK: Authorization

    func authorizationStatus() async -> CameraAuthorization {
        CameraAuthorization(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func requestAccess() async -> CameraAuthorization {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return CameraAuthorization(AVCaptureDevice.authorizationStatus(for: .video))
    }

    // MARK: Lifecycle

    func start() async throws {
        guard CameraAuthorization(AVCaptureDevice.authorizationStatus(for: .video)) == .authorized else {
            throw CameraError.notAuthorized
        }
        try configureIfNeeded()
        startObserving()
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() async {
        for observer in observers { observer.cancel() }
        observers = []
        if session.isRunning { session.stopRunning() }
    }

    // MARK: Capture

    func capturePhoto(flash: FlashMode, rotationAngle: CGFloat) async throws -> Data {
        guard session.isRunning else { throw CameraError.captureFailed }

        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }

        let settings = makeSettings(flash: flash)
        let delegate = PhotoCaptureDelegate()
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
        // The output only keeps a weak reference to the delegate; hold it until the photo has arrived.
        withExtendedLifetime(delegate) {}
        return data
    }

    func focus(at devicePoint: CGPoint) async {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
        } catch {
            Logger.camera.error("Focus failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Private

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device else { throw CameraError.unavailable }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            Logger.camera.error("Could not open the camera: \(error.localizedDescription, privacy: .public)")
            throw CameraError.unavailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        isConfigured = true
    }

    private func makeSettings(flash: FlashMode) -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.photoQualityPrioritization = .balanced
        let requested: AVCaptureDevice.FlashMode = switch flash {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
        if photoOutput.supportedFlashModes.contains(requested) {
            settings.flashMode = requested
        }
        return settings
    }

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            Task { [weak self] in
                for await _ in center.notifications(named: AVCaptureSession.wasInterruptedNotification) {
                    self?.emit(.interrupted)
                }
            },
            Task { [weak self] in
                for await _ in center.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                    self?.emit(.interruptionEnded)
                }
            },
            Task { [weak self] in
                for await _ in center.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                    self?.handleRuntimeError()
                }
            }
        ]
    }

    private func emit(_ event: CameraEvent) {
        eventContinuation.yield(event)
    }

    private func handleRuntimeError() {
        Logger.camera.error("Capture session runtime error")
        emit(.runtimeError)
        if !session.isRunning { session.startRunning() }
    }
}

/// Bridges the photo output's callback to async/await. One instance per capture.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    var continuation: CheckedContinuation<Data, any Error>?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        defer { continuation = nil }
        if let error {
            Logger.camera.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            continuation?.resume(throwing: CameraError.captureFailed)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CameraError.captureFailed)
        }
    }
}
