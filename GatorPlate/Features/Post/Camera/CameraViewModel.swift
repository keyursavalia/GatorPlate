import Foundation
import Observation
import OSLog
import PhotosUI
import SwiftUI

/// Camera screen state: permission state machine, session lifetime, flash, capture and library import.
@MainActor
@Observable
final class CameraViewModel {
    enum State: Equatable {
        case checking
        /// In-app explanation before the system prompt.
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

    func allowCamera() async {
        switch await camera.requestAccess() {
        case .authorized: state = .starting
        case .restricted: state = .restricted
        case .denied, .notDetermined: state = .denied
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

    func importPhoto(_ item: PhotosPickerItem) async -> CapturedPhoto? {
        guard !isProcessing else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = ImagePreprocessor.unreadable.userMessage
                return nil
            }
            return try await preprocessor.process(data, source: .library)
        } catch let error as AppError {
            errorMessage = error.userMessage
        } catch {
            Logger.ui.error("Library import failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't load that photo. Check your connection and try again."
        }
        return nil
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
