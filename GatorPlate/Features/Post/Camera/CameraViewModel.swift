import Foundation
import Observation
import OSLog
import PhotosUI
import SwiftUI

/// Camera screen state: permission state machine, session lifetime, flash, capture and library import.
/// Photos go to the flow's `PhotoTrayModel`; the preview stays live for the next shot.
@MainActor
@Observable
final class CameraViewModel {
    enum State: Equatable {
        case checking
        /// Not asked yet: the "Snap the food" page shows while the system prompt fires on its own.
        case needsExplanation
        case denied
        case restricted
        /// Simulator or no camera: library only.
        case unavailable
        /// Authorized; the preview is on screen while the session starts.
        case starting
        case ready
        case failed(String)

        var showsPreview: Bool {
            self == .starting || self == .ready
        }
    }

    private(set) var state: State = .checking
    private(set) var flashMode: CameraFlashMode = .auto
    private(set) var supportedFlashModes: [CameraFlashMode] = []
    /// Set while an interruption pauses the session.
    private(set) var pauseMessage: String?
    /// Transient error from a capture or library import.
    var errorMessage: String?
    /// Capturing or preparing a photo; the shutter is disabled.
    private(set) var isProcessing = false
    /// Incremented at the real shutter moment; triggers the haptic and flash animation.
    private(set) var shutterCount = 0
    /// The system camera prompt is up; the page hides its "Allow camera" button.
    private(set) var isRequestingAccess = false
    /// Incremented when the user declines the prompt; triggers a warning haptic.
    private(set) var declineCount = 0
    @ObservationIgnored private var hasAutoRequested = false

    let camera: any CameraCapturing
    private let preprocessor = ImagePreprocessor()
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    /// Chains start/stop so they reach the session in call order (retake = stop then start).
    @ObservationIgnored private var sessionTask: Task<Void, Never>?

    init(camera: any CameraCapturing) {
        self.camera = camera
    }

    var canSwitchCamera: Bool {
        camera.canSwitchCamera && state == .ready
    }

    // MARK: Permission

    /// Call on appear and when the app becomes active (for example back from Settings).
    func refresh() async {
        guard camera.isCameraAvailable else {
            state = .unavailable
            return
        }
        switch await camera.authorization() {
        case .notDetermined: state = .needsExplanation
        case .denied: state = .denied
        case .restricted: state = .restricted
        case .authorized:
            if !state.showsPreview { state = .starting }
        }
    }

    /// The first time the post flow opens undecided, the system prompt fires by itself once the cover has
    /// finished presenting, over the "Snap the food" page.
    func autoRequestIfNeeded() async {
        guard state == .needsExplanation, !hasAutoRequested else { return }
        hasAutoRequested = true
        try? await Task.sleep(for: .seconds(AppConfig.cameraPromptDelaySeconds))
        guard !Task.isCancelled, state == .needsExplanation else { return }
        await allowCamera()
    }

    func allowCamera() async {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        defer { isRequestingAccess = false }
        switch await camera.requestAccess() {
        case .authorized: state = .starting
        case .restricted: state = .restricted
        case .denied, .notDetermined:
            state = .denied
            declineCount += 1
        }
    }

    // MARK: Session

    /// Called by the preview once its layer exists, so the session connects to it.
    func startSession() {
        // Back from Retake: keep the shutter disabled until the session runs again.
        if state == .ready { state = .starting }
        listenForEvents()
        enqueueSessionWork { [weak self, camera] in
            do throws(AppError) {
                try await camera.start()
                let modes = await camera.supportedFlashModes()
                self?.sessionDidStart(flashModes: modes)
            } catch {
                self?.state = .failed(error.userMessage)
            }
        }
    }

    func stopSession() {
        eventsTask?.cancel()
        eventsTask = nil
        enqueueSessionWork { [camera] in await camera.stop() }
    }

    private func enqueueSessionWork(_ work: @escaping @MainActor () async -> Void) {
        let previous = sessionTask
        sessionTask = Task {
            await previous?.value
            await work()
        }
    }

    private func sessionDidStart(flashModes: [CameraFlashMode]) {
        updateFlashModes(flashModes)
        pauseMessage = nil
        state = .ready
    }

    private func updateFlashModes(_ modes: [CameraFlashMode]) {
        supportedFlashModes = modes
        if !modes.contains(flashMode) {
            flashMode = modes.contains(.auto) ? .auto : .off
        }
    }

    private func listenForEvents() {
        guard eventsTask == nil else { return }
        eventsTask = Task { [weak self, camera] in
            for await event in await camera.events() {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: CameraEvent) {
        switch event {
        case .willCapture:
            shutterCount += 1
        case .interrupted(let interruption):
            pauseMessage = Self.message(for: interruption)
        case .resumed:
            pauseMessage = nil
        case .failed:
            pauseMessage = nil
            state = .failed(AppError.cameraUnavailable.userMessage)
        }
    }

    private static func message(for interruption: CameraInterruption) -> String? {
        switch interruption {
        case .background: nil
        case .inUseByAnotherApp: "Camera paused while another app is using it."
        case .multitasking: "Camera paused. Use GatorPlate full screen to take a photo."
        case .systemPressure: "Camera paused because the device is too warm. Try again in a moment."
        case .other: "Camera paused."
        }
    }

    // MARK: Controls

    func cycleFlash() {
        guard let index = supportedFlashModes.firstIndex(of: flashMode), !supportedFlashModes.isEmpty else { return }
        flashMode = supportedFlashModes[(index + 1) % supportedFlashModes.count]
    }

    func focus(at devicePoint: CGPoint) {
        Task { [camera] in await camera.focus(at: devicePoint) }
    }

    func switchCamera() async {
        do {
            updateFlashModes(try await camera.switchCamera())
        } catch {
            errorMessage = error.userMessage
        }
    }

    // MARK: Photos

    func capture() async -> CapturedPhoto? {
        guard state == .ready, pauseMessage == nil, !isProcessing else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let data = try await camera.capturePhoto(flash: flashMode)
            return try await preprocessor.process(data, source: .camera)
        } catch {
            errorMessage = error.userMessage
            return nil
        }
    }

    /// Library picks in the user's pick order. Unreadable photos are skipped with one message.
    func importPhotos(_ items: [PhotosPickerItem]) async -> [CapturedPhoto] {
        guard !isProcessing, !items.isEmpty else { return [] }
        isProcessing = true
        defer { isProcessing = false }
        var photos: [CapturedPhoto] = []
        var failed = 0
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    failed += 1
                    continue
                }
                photos.append(try await preprocessor.process(data, source: .library))
            } catch {
                Logger.ui.error("Library import failed: \(String(describing: type(of: error)), privacy: .public)")
                failed += 1
            }
        }
        if failed > 0 {
            errorMessage = failed == 1 ? "Couldn't load 1 photo. Try another one."
                                       : "Couldn't load \(failed) photos. Try other ones."
        }
        return photos
    }
}

extension CameraFlashMode {
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
