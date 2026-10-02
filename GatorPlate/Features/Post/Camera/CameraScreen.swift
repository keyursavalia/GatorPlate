import PhotosUI
import SwiftUI

/// Step 1 of the Post flow: full-bleed camera, with the permission states and library fallback.
struct CameraScreen: View {
    @State private var viewModel: CameraViewModel
    @State private var rotation = CameraRotationSource()
    @State private var pickerItem: PhotosPickerItem?
    @State private var flashOpacity = 0.0
    @AppStorage(AppConfig.cameraHintSeenKey) private var hintSeen = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    private let camera: any CameraProviding
    private let onClose: () -> Void
    private let onManual: (() -> Void)?

    init(
        camera: any CameraProviding,
        onPhoto: @escaping (CapturedPhoto) -> Void,
        onClose: @escaping () -> Void,
        onManual: (() -> Void)? = nil
    ) {
        self.camera = camera
        self.onClose = onClose
        self.onManual = onManual
        _viewModel = State(initialValue: CameraViewModel(camera: camera, onPhoto: onPhoto))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            VStack(spacing: Theme.Spacing.s) {
                topBar
                if let message = viewModel.errorMessage {
                    Banner(kind: .error, message: message)
                        .padding(.horizontal, Theme.Spacing.l)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.shutterCount)
        .onChange(of: viewModel.shutterCount) {
            // Reduce Motion: keep the haptic, skip the flash.
            guard !reduceMotion else { return }
            flashOpacity = 0.7
            withAnimation(.easeOut(duration: 0.25)) { flashOpacity = 0 }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                switch phase {
                case .active: await viewModel.refresh()
                case .background: await viewModel.stop()
                default: break
                }
            }
        }
        .task { await viewModel.refresh() }
        .task { await viewModel.observeEvents() }
        .onDisappear {
            hintSeen = true
            Task { await viewModel.stop() }
        }
    }

    // MARK: Content by phase

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .checking:
            ProgressView()
                .tint(.white)
                .accessibilityLabel("Opening camera")
        case .ready:
            cameraLayer
        case .needsExplanation:
            fallback {
                EmptyState(
                    systemImage: "camera.viewfinder",
                    title: "Snap it. We'll draft the post.",
                    message: "GatorPlate uses your camera to photograph the food. Photograph the food, not people.",
                    actionTitle: "Continue"
                ) {
                    Task { await viewModel.requestAccess() }
                }
            }
        case .denied:
            fallback {
                EmptyState(
                    systemImage: "video.slash",
                    title: "Camera access is off",
                    message: "Turn it on in Settings, or choose a photo from your library instead.",
                    actionTitle: "Open Settings",
                    action: openSettings
                )
            }
        case .unavailable:
            fallback {
                EmptyState(
                    systemImage: "camera.fill",
                    title: "No camera available",
                    message: "This device can't open the camera. Choose a photo from your library instead."
                )
            }
        }
    }

    private var cameraLayer: some View {
        ZStack(alignment: .bottom) {
            preview
            VStack(spacing: Theme.Spacing.m) {
                if !hintSeen {
                    Text("Photograph the food, not people.")
                        .font(.footnote)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                shutterButton
                manualButton(onDark: true)
            }
            .padding(.bottom, Theme.Spacing.xl)

            if viewModel.isPaused {
                Text("Camera paused")
                    .font(.headline)
                    .padding(Theme.Spacing.l)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.Radius.photo))
                    .frame(maxHeight: .infinity)
            }
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel("Processing photo")
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let session = camera.previewSession {
            CameraPreview(session: session, rotation: rotation) { devicePoint in
                Task { await viewModel.focus(at: devicePoint) }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        } else {
            // Mocks and previews: nothing to show live.
            LinearGradient(colors: [.gray.opacity(0.4), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }

    /// The no-AI, no-photo path: always reachable from the camera.
    @ViewBuilder private func manualButton(onDark: Bool) -> some View {
        if let onManual {
            Button("Fill it in myself", action: onManual)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.l)
                .frame(minHeight: Theme.minTapTarget)
                .background(onDark ? Color.black.opacity(0.55) : Color.brandPurple, in: Capsule())
                .accessibilityHint("Skips the photo and opens the post form")
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await viewModel.capture(rotationAngle: rotation.captureAngle) }
        } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle().fill(.white)
                    .frame(width: 62, height: 62)
            }
            .opacity(viewModel.canCapture ? 1 : 0.5)
            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canCapture)
        .accessibilityLabel("Take photo")
    }

    // MARK: Controls

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close camera")

            Spacer()

            if viewModel.phase == .ready && viewModel.supportsFlash {
                Button(action: viewModel.cycleFlash) {
                    Image(systemName: viewModel.flash.systemImage)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Flash")
                .accessibilityValue(viewModel.flash.title)
                .accessibilityHint("Changes between off, auto and on")
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Choose from library")
        }
        .padding(Theme.Spacing.l)
    }

    /// Permission and no-camera states: message, plus the library picker (and the sample button in DEBUG).
    private func fallback<Message: View>(@ViewBuilder message: () -> Message) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                message()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, Theme.Spacing.l)
                manualButton(onDark: false)
#if DEBUG
                Button {
                    Task { await viewModel.useSamplePhoto() }
                } label: {
                    Label("Use sample food photo", systemImage: "fork.knife")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, Theme.Spacing.l)
#endif
            }
            .padding(.top, Theme.Spacing.xxl * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Actions

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await viewModel.handlePickedData(data)
            } else {
                viewModel.libraryLoadFailed()
            }
        } catch {
            viewModel.libraryLoadFailed()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview("Ready") {
    CameraScreen(camera: MockCameraService(), onPhoto: { _ in }, onClose: {})
        .environment(\.appEnvironment, .mock)
}

#Preview("Needs explanation") {
    CameraScreen(camera: MockCameraService(authorization: .notDetermined), onPhoto: { _ in }, onClose: {})
        .environment(\.appEnvironment, .mock)
}

#Preview("Denied") {
    CameraScreen(camera: MockCameraService(authorization: .denied), onPhoto: { _ in }, onClose: {})
        .environment(\.appEnvironment, .mock)
}

#Preview("No camera") {
    CameraScreen(camera: MockCameraService(hasCamera: false), onPhoto: { _ in }, onClose: {})
        .environment(\.appEnvironment, .mock)
}
