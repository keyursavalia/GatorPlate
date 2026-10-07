import PhotosUI
import SwiftUI

/// Post flow step 1: full-bleed camera with shutter, flash, library and close.
/// Falls back to `CameraPermissionView` whenever there is no live preview.
struct CameraScreen: View {
    @Bindable var viewModel: CameraViewModel
    let onPhoto: (CapturedPhoto) -> Void
    let onClose: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?
    @State private var showsPeopleHint = false
    @AppStorage("camera.hasSeenPeopleHint") private var hasSeenPeopleHint = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let shutterSize: CGFloat = 72
    private static let focusRingSize: CGFloat = 72

    var body: some View {
        Group {
            if viewModel.state.showsPreview {
                cameraLayer
            } else if viewModel.state == .checking {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CameraPermissionView(state: viewModel.state, pickerItem: $pickerItem,
                                     isProcessing: viewModel.isProcessing) {
                    Task { await viewModel.allowCamera() }
                }
                .overlay(alignment: .topLeading) {
                    closeButton.padding(Theme.Spacing.lg)
                }
            }
        }
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refresh() } }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let photo = await viewModel.importPhoto(item) { onPhoto(photo) }
                pickerItem = nil
            }
        }
        .alert("Photo not ready", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.shutterCount)
        .sensoryFeedback(.warning, trigger: viewModel.errorMessage) { _, new in new != nil }
    }

    // MARK: Live camera

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(source: viewModel.camera.previewSource) { devicePoint, viewPoint in
                viewModel.focus(at: devicePoint)
                focusPoint = viewPoint
            }
            .overlay { focusRing }
            .ignoresSafeArea()
            .onAppear { viewModel.startSession() }
            .onDisappear { viewModel.stopSession() }

            shutterFlash

            if viewModel.state == .starting {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Starting camera")
            }

            VStack(spacing: Theme.Spacing.md) {
                topBar
                Spacer()
                if let pauseMessage = viewModel.pauseMessage {
                    overlayText(pauseMessage)
                } else if showsPeopleHint {
                    overlayText("Photograph the food, not people.")
                        .transition(.opacity)
                }
                bottomBar
            }
            .padding(Theme.Spacing.lg)
        }
        .background(.black)
        .task { await showPeopleHintOnce() }
    }

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            if !viewModel.supportedFlashModes.isEmpty {
                GlassIconButton(systemImage: viewModel.flashMode.systemImage,
                                accessibilityLabel: "Flash \(viewModel.flashMode.title)",
                                accessibilityHint: "Changes the flash mode") {
                    viewModel.cycleFlash()
                }
            }
        }
    }

    private var bottomBar: some View {
        // Local copy: the picker's label closure is Sendable.
        let tapTarget = Theme.Size.minTapTarget
        return HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .frame(width: tapTarget, height: tapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(viewModel.isProcessing)
            .accessibilityLabel("Choose from library")
            .accessibilityHint("Pick a photo of the food instead of taking one")

            Spacer()
            shutterButton
            Spacer()

            if viewModel.canSwitchCamera {
                GlassIconButton(systemImage: "arrow.triangle.2.circlepath.camera",
                                accessibilityLabel: "Switch camera",
                                accessibilityHint: "Flips between the back and front camera") {
                    Task { await viewModel.switchCamera() }
                }
            } else {
                Color.clear
                    .frame(width: Theme.Size.minTapTarget, height: Theme.Size.minTapTarget)
                    .accessibilityHidden(true)
            }
        }
    }

    private var shutterButton: some View {
        Button {
            Task {
                if let photo = await viewModel.capture() { onPhoto(photo) }
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: Self.shutterSize, height: Self.shutterSize)
                Circle()
                    .fill(.white)
                    .frame(width: Self.shutterSize - 14, height: Self.shutterSize - 14)
                if viewModel.isProcessing {
                    ProgressView().tint(.black)
                }
            }
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state != .ready || viewModel.isProcessing || viewModel.pauseMessage != nil)
        .accessibilityLabel("Take photo")
        .accessibilityValue(viewModel.isProcessing ? "Processing" : "")
    }

    private var closeButton: some View {
        GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close", accessibilityHint: "Cancels the post",
                        action: onClose)
    }

    private func overlayText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            // Solid, not glass: text over a live preview needs a steady backing.
            .background(.black.opacity(0.65), in: .capsule)
    }

    // MARK: Feedback

    @ViewBuilder
    private var focusRing: some View {
        if let focusPoint {
            Circle()
                .stroke(Theme.Palette.brandGold, lineWidth: 2)
                .frame(width: Self.focusRingSize, height: Self.focusRingSize)
                .position(focusPoint)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .task(id: focusPoint) {
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.easeOut) { self.focusPoint = nil }
                }
        }
    }

    /// A quick white blink on capture; with Reduce Motion, a gentle dim instead.
    private var shutterFlash: some View {
        let peak = reduceMotion ? 0.25 : 0.6
        return Rectangle()
            .fill(reduceMotion ? Color.black : Color.white)
            .keyframeAnimator(initialValue: 0.0, trigger: viewModel.shutterCount) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                CubicKeyframe(peak, duration: 0.05)
                CubicKeyframe(0, duration: reduceMotion ? 0.3 : 0.15)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func showPeopleHintOnce() async {
        guard !hasSeenPeopleHint else { return }
        showsPeopleHint = true
        try? await Task.sleep(for: .seconds(5))
        withAnimation(reduceMotion ? nil : .easeOut) { showsPeopleHint = false }
        hasSeenPeopleHint = true
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            })
    }
}

#Preview("Camera") {
    CameraScreen(viewModel: CameraViewModel(camera: MockCameraService()), onPhoto: { _ in }, onClose: {})
}

#Preview("Not asked yet") {
    CameraScreen(viewModel: CameraViewModel(camera: MockCameraService(authorization: .notDetermined)),
                 onPhoto: { _ in }, onClose: {})
}
