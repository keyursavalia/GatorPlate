import PhotosUI
import SwiftUI

/// Post flow step 1: full-bleed camera. The shutter adds to a tray (up to 4 photos, camera and library mixed) and
/// the preview stays live; "Next" carries the tray on. Falls back to `CameraPermissionView` whenever there is no
/// live preview, with the same tray and Next after a library pick.
struct CameraScreen: View {
    @Bindable var viewModel: CameraViewModel
    let tray: PhotoTrayModel
    let onNext: () -> Void
    let onClose: () -> Void
    /// Manual entry: Review with the tray's photos and no AI.
    var onFillManually: (() -> Void)?

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var focusPoint: CGPoint?
    @State private var showsPeopleHint = false
    /// "Starting camera" only appears when the session is slow to start.
    @State private var showsStartingSpinner = false
    @State private var viewerIndex = 0
    @State private var isViewingPhotos = false
    @AppStorage("camera.hasSeenPeopleHint") private var hasSeenPeopleHint = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        ZStack {
            if viewModel.state.showsPreview {
                cameraLayer
                    .transition(.opacity)
            } else if viewModel.state == .checking {
                // Plain backdrop, no spinner: the check takes a moment and must not flash.
                Color.clear
            } else {
                CameraPermissionView(state: viewModel.state, pickerItems: $pickerItems, remaining: tray.remaining,
                                     isProcessing: viewModel.isProcessing,
                                     isRequestingAccess: viewModel.isRequestingAccess,
                                     onFillManually: onFillManually) {
                    Task { await viewModel.allowCamera() }
                }
                .overlay(alignment: .topLeading) {
                    closeButton.padding(Theme.Spacing.lg)
                }
                .safeAreaInset(edge: .bottom) {
                    if !tray.isEmpty {
                        HStack {
                            trayStrip
                            NextButton(count: tray.photos.count, action: onNext)
                        }
                        .padding(Theme.Spacing.lg)
                        .background(.bar)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.state.showsPreview)
        .task {
            await viewModel.refresh()
            await viewModel.autoRequestIfNeeded()
        }
        .task(id: viewModel.state) {
            showsStartingSpinner = false
            guard viewModel.state == .starting else { return }
            try? await Task.sleep(for: .seconds(AppConfig.cameraSpinnerDelaySeconds))
            if !Task.isCancelled { showsStartingSpinner = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refresh() } }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let photos = await viewModel.importPhotos(items)
                withAnimation(reduceMotion ? nil : .snappy) { _ = tray.add(contentsOf: photos) }
                pickerItems = []
            }
        }
        .fullScreenCover(isPresented: $isViewingPhotos) {
            PhotoViewer(sources: tray.photos.map(PostPhotoSource.captured), images: nil, selection: $viewerIndex,
                        editActions: PhotoViewer.EditActions(
                            onRemove: { source in
                                if case .captured(let photo) = source { tray.remove(id: photo.id) }
                                viewerIndex = min(viewerIndex, max(tray.photos.count - 1, 0))
                            },
                            onMakeCover: { source in
                                if case .captured(let photo) = source { tray.makeCover(id: photo.id) }
                                viewerIndex = 0
                            }))
        }
        .alert("Photo not ready", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sensoryFeedback(.warning, trigger: viewModel.declineCount)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.shutterCount)
        .sensoryFeedback(.impact(weight: .light), trigger: tray.photos.count) { old, new in new > old }
        .sensoryFeedback(.warning, trigger: viewModel.errorMessage) { _, new in new != nil }
    }

    // MARK: Live camera

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(source: viewModel.camera.previewSource) { devicePoint, viewPoint in
                viewModel.focus(at: devicePoint)
                focusPoint = viewPoint
            }
            .overlay { CameraFocusRing(point: $focusPoint) }
            .ignoresSafeArea()
            .onAppear { viewModel.startSession() }
            .onDisappear { viewModel.stopSession() }

            CameraShutterFlash(trigger: viewModel.shutterCount)

            if viewModel.state == .starting, showsStartingSpinner {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Starting camera")
            }

            VStack(spacing: Theme.Spacing.md) {
                topBar
                Spacer()
                if let pauseMessage = viewModel.pauseMessage {
                    CameraOverlayText(text: pauseMessage)
                } else if tray.isFull {
                    CameraOverlayText(text: "\(AppConfig.postMaxPhotos) photos max. Remove one to add another.")
                } else if showsPeopleHint {
                    CameraOverlayText(text: "Photograph the food, not people.")
                        .transition(.opacity)
                } else if !tray.isEmpty, environment.runtime.current.aiEnabled {
                    // App Review 5.1.2(i): says where the photos are sent, before Next sends them.
                    CameraOverlayText(text: "Next sends your photos to Google's Gemini AI to draft the post.")
                        .transition(.opacity)
                }
                if !tray.isEmpty {
                    trayStrip
                }
                CameraControls(viewModel: viewModel, pickerItems: $pickerItems, photoCount: tray.photos.count,
                               remaining: tray.remaining, onShutter: shoot, onNext: onNext)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(.black)
        .task { await showPeopleHintOnce() }
    }

    private var topBar: some View {
        GlassEffectContainer {
            HStack {
                closeButton
                Spacer()
                if let onFillManually {
                    Button(action: onFillManually) {
                        Label("Fill it in myself", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: Theme.Size.minTapTarget)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityHint(tray.isEmpty ? "Write the post without AI"
                                                    : "Write the post yourself with these photos, without AI")
                    Spacer()
                }
                if !viewModel.supportedFlashModes.isEmpty {
                    GlassIconButton(systemImage: viewModel.flashMode.systemImage,
                                    accessibilityLabel: "Flash \(viewModel.flashMode.title)",
                                    accessibilityHint: "Changes the flash mode") {
                        viewModel.cycleFlash()
                    }
                }
            }
        }
    }

    private var trayStrip: some View {
        PhotoTray(photos: tray.photos,
                  onSelect: { index in
                      viewerIndex = index
                      isViewingPhotos = true
                  },
                  onMove: { id, target in withAnimation(reduceMotion ? nil : .snappy) { tray.move(id: id, to: target) } },
                  onMoveBy: { id, offset in tray.move(id: id, by: offset) },
                  onMakeCover: { tray.makeCover(id: $0) },
                  onRemove: { tray.remove(id: $0) }) {
            if !tray.isFull {
                LibraryPickerButton(pickerItems: $pickerItems, remaining: tray.remaining,
                                    isDisabled: viewModel.isProcessing)
            }
        }
        .transition(reduceMotion ? .opacity : .scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
    }

    private var closeButton: some View {
        GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close", accessibilityHint: "Cancels the post",
                        action: onClose)
    }

    private func shoot() {
        Task {
            guard let photo = await viewModel.capture() else { return }
            withAnimation(reduceMotion ? nil : .snappy) { _ = tray.add(photo) }
            AccessibilityNotification.Announcement("Photo \(tray.photos.count) added").post()
        }
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
