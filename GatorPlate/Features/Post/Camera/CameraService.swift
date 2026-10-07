import AVFoundation
import OSLog

/// Live camera. The actor runs on `sessionQueue`, so every session call, including the blocking
/// `startRunning()`, stays off the main thread and is serialized without locks.
actor CameraService: CameraCapturing {
    private let sessionQueue = DispatchSerialQueue(label: "GatorPlate.camera.session")
    nonisolated var unownedExecutor: UnownedSerialExecutor { sessionQueue.asUnownedSerialExecutor() }

    nonisolated let previewSource: CameraPreviewSource
    private let session: AVCaptureSession
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var notificationTokens: [any NSObjectProtocol] = []
    /// Delegates are retained here until their capture finishes.
    private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]
    private var eventContinuation: AsyncStream<CameraEvent>.Continuation?
    private var isConfigured = false
    private var wantsRunning = false

    init() {
        let session = AVCaptureSession()
        self.session = session
        previewSource = CameraPreviewSource(session: session)
    }

    isolated deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: Availability and permission

    nonisolated var isCameraAvailable: Bool {
        Self.device(at: .back) != nil
    }

    nonisolated var canSwitchCamera: Bool {
        Self.device(at: .back) != nil && Self.device(at: .front) != nil
    }

    nonisolated func authorization() async -> CameraAuthorization {
        CameraAuthorization(AVCaptureDevice.authorizationStatus(for: .video))
    }

    nonisolated func requestAccess() async -> CameraAuthorization {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return await authorization()
    }

    func events() -> AsyncStream<CameraEvent> {
        eventContinuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: CameraEvent.self, bufferingPolicy: .bufferingNewest(8))
        eventContinuation = continuation
        return stream
    }

    // MARK: Session

    func start() throws(AppError) {
        wantsRunning = true
        try configureIfNeeded()
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        wantsRunning = false
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func supportedFlashModes() -> [CameraFlashMode] {
        let modes = photoOutput.supportedFlashModes
        return CameraFlashMode.allCases.filter { modes.contains($0.avFlashMode) }
    }

    private func configureIfNeeded() throws(AppError) {
        guard !isConfigured else { return }
        guard let device = Self.device(at: .back) else { throw .cameraUnavailable }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            Logger.services.error("Camera input failed: \(error.localizedDescription, privacy: .public)")
            throw .cameraUnavailable
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw .cameraUnavailable
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        videoInput = input
        photoOutput.maxPhotoQualityPrioritization = .quality
        configurePhotoOutput(for: device)
        session.commitConfiguration()

        makeRotationCoordinator(for: device)
        observeSession()
        isConfigured = true
    }

    /// Smallest photo size that still covers the AI long edge: we downscale right after capture anyway,
    /// so a smaller capture is faster and keeps less in memory.
    private func configurePhotoOutput(for device: AVCaptureDevice) {
        let minLongEdge = Int32(AppConfig.aiMaxImageLongEdge)
        let candidates = device.activeFormat.supportedMaxPhotoDimensions
        let large = candidates.filter { max($0.width, $0.height) >= minLongEdge }
        let area = { (dimensions: CMVideoDimensions) in Int(dimensions.width) * Int(dimensions.height) }
        if let smallest = (large.isEmpty ? candidates : large).min(by: { area($0) < area($1) }) {
            photoOutput.maxPhotoDimensions = smallest
        }
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
            if photoOutput.isFastCapturePrioritizationSupported {
                photoOutput.isFastCapturePrioritizationEnabled = true
            }
        }
    }

    // MARK: Capture

    func capturePhoto(flash: CameraFlashMode) async throws(AppError) -> Data {
        guard session.isRunning else { throw .cameraUnavailable }

        let settings = AVCapturePhotoSettings()
        // Balanced, not quality: the photo is downscaled to 1024 px, and speed serves the 15 s posting goal.
        settings.photoQualityPrioritization = .balanced
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        if photoOutput.supportedFlashModes.contains(flash.avFlashMode) {
            settings.flashMode = flash.avFlashMode
        }
        if let connection = photoOutput.connection(with: .video),
           let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }

        let captureID = settings.uniqueID
        let events = eventContinuation
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let delegate = PhotoCaptureDelegate(
                    continuation: continuation,
                    onWillCapture: { events?.yield(.willCapture) },
                    onFinish: { [weak self] in
                        Task { await self?.finishCapture(captureID) }
                    })
                inFlightCaptures[captureID] = delegate
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        } catch {
            Logger.services.error("Photo capture failed: \(error.localizedDescription, privacy: .public)")
            throw .captureFailed
        }
    }

    private func finishCapture(_ captureID: Int64) {
        inFlightCaptures[captureID] = nil
    }

    // MARK: Focus and camera switching

    func focus(at devicePoint: CGPoint) {
        guard let device = videoInput?.device else { return }
        do {
            try device.lockForConfiguration()
        } catch {
            Logger.services.error("Focus lock failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        defer { device.unlockForConfiguration() }
        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = .continuousAutoExposure
        }
    }

    func switchCamera() throws(AppError) -> [CameraFlashMode] {
        guard let currentInput = videoInput else { throw .cameraUnavailable }
        let position: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let device = Self.device(at: position),
              let newInput = try? AVCaptureDeviceInput(device: device) else { throw .cameraUnavailable }

        session.beginConfiguration()
        session.removeInput(currentInput)
        let didSwitch = session.canAddInput(newInput)
        let activeInput = didSwitch ? newInput : currentInput
        session.addInput(activeInput)
        videoInput = activeInput
        configurePhotoOutput(for: activeInput.device)
        session.commitConfiguration()

        guard didSwitch else { throw .cameraUnavailable }
        makeRotationCoordinator(for: device)
        return supportedFlashModes()
    }

    // MARK: Rotation

    /// Levels the preview and the captured photo for the current device orientation.
    private func makeRotationCoordinator(for device: AVCaptureDevice) {
        let previewLayer = session.connections.lazy.compactMap(\.videoPreviewLayer).first
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator

        let source = previewSource
        source.setPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) {
            @Sendable _, change in
            guard let angle = change.newValue else { return }
            source.setPreviewRotation(angle)
        }
    }

    // MARK: Interruptions and errors

    private func observeSession() {
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session,
                               queue: nil) { @Sendable [weak self] notification in
                let rawReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
                let interruption = CameraInterruption(rawReason: rawReason)
                Task { await self?.emit(.interrupted(interruption)) }
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session,
                               queue: nil) { @Sendable [weak self] _ in
                Task { await self?.emit(.resumed) }
            },
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session,
                               queue: nil) { @Sendable [weak self] notification in
                let code = (notification.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code
                Task { await self?.handleRuntimeError(code) }
            },
        ]
    }

    private func emit(_ event: CameraEvent) {
        eventContinuation?.yield(event)
    }

    private func handleRuntimeError(_ code: AVError.Code?) {
        Logger.services.error("Camera runtime error: \(code?.rawValue ?? -1, privacy: .public)")
        if code == .mediaServicesWereReset, wantsRunning {
            session.startRunning()
            if session.isRunning { return }
        }
        emit(.failed)
    }

    private nonisolated static func device(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
}

private nonisolated extension CameraAuthorization {
    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .restricted: self = .restricted
        case .denied: self = .denied
        @unknown default: self = .denied
        }
    }
}

private nonisolated extension CameraInterruption {
    init(rawReason: Int?) {
        switch rawReason.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:)) {
        case .videoDeviceNotAvailableInBackground: self = .background
        case .videoDeviceInUseByAnotherClient, .audioDeviceInUseByAnotherClient: self = .inUseByAnotherApp
        case .videoDeviceNotAvailableWithMultipleForegroundApps: self = .multitasking
        case .videoDeviceNotAvailableDueToSystemPressure: self = .systemPressure
        default: self = .other
        }
    }
}

private nonisolated extension CameraFlashMode {
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
    }
}
