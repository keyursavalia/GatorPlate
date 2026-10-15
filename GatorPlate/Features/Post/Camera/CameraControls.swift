import PhotosUI
import SwiftUI

/// Camera bottom controls in one `GlassEffectContainer`: library (multi-select up to the photos left), the
/// shutter ring, and either "Next" with the photo count or switch camera.
struct CameraControls: View {
    @Bindable var viewModel: CameraViewModel
    @Binding var pickerItems: [PhotosPickerItem]
    let photoCount: Int
    let remaining: Int
    let onShutter: () -> Void
    let onNext: () -> Void

    private static let shutterSize: CGFloat = 72

    var body: some View {
        GlassEffectContainer {
            HStack {
                LibraryPickerButton(pickerItems: $pickerItems, remaining: remaining,
                                    isDisabled: viewModel.isProcessing)
                Spacer()
                shutter
                Spacer()
                trailing
            }
        }
    }

    private var shutter: some View {
        Button(action: onShutter) {
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
        .buttonStyle(ShutterButtonStyle())
        .disabled(!canShoot)
        .opacity(remaining == 0 ? 0.4 : 1)
        .accessibilityLabel("Take photo")
        .accessibilityValue(viewModel.isProcessing ? "Processing" : "\(photoCount) of \(AppConfig.postMaxPhotos) photos")
    }

    private var canShoot: Bool {
        viewModel.state == .ready && !viewModel.isProcessing && viewModel.pauseMessage == nil && remaining > 0
    }

    @ViewBuilder
    private var trailing: some View {
        if photoCount > 0 {
            NextButton(count: photoCount, action: onNext)
        } else if viewModel.canSwitchCamera {
            GlassIconButton(systemImage: "arrow.triangle.2.circlepath.camera", accessibilityLabel: "Switch camera",
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

/// Photo library, ordered multi-select limited to the photos left. `PhotosPicker` runs out of process, so it
/// needs no permission.
struct LibraryPickerButton: View {
    @Binding var pickerItems: [PhotosPickerItem]
    let remaining: Int
    var isDisabled = false

    var body: some View {
        // Local copy: the picker's label closure is Sendable.
        let tapTarget = Theme.Size.minTapTarget
        PhotosPicker(selection: $pickerItems, maxSelectionCount: max(remaining, 1), selectionBehavior: .ordered,
                     matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.title3)
                .frame(width: tapTarget, height: tapTarget)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(isDisabled || remaining == 0)
        .accessibilityLabel("Choose from library")
        .accessibilityHint(remaining == 0 ? "4 photos max. Remove one to add another."
                                          : "Pick up to \(remaining) photos of the food")
    }
}

/// "Next" capsule with the photo count badge.
struct NextButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Text("Next").font(.headline)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
                Text("\(count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(.white, in: .circle)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: Theme.Size.minTapTarget)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.Palette.brandPurple)
        .accessibilityLabel("Next, \(count) \(count == 1 ? "photo" : "photos")")
        .accessibilityHint("Drafts the post from your photos")
    }
}

/// Press-scale for the shutter ring (a plain cut with Reduce Motion).
private struct ShutterButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: configuration.isPressed)
    }
}
