import PhotosUI
import SwiftUI

/// Every camera state without a live preview: explanation, denied, restricted, unavailable, failed.
/// The photo library is offered in all of them.
struct CameraPermissionView: View {
    let state: CameraViewModel.State
    @Binding var pickerItem: PhotosPickerItem?
    var isProcessing = false
    let onAllow: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: content.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Spacing.sm) {
                    Text(content.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(content.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: Theme.Spacing.md) {
                    primaryAction
                    libraryButton
                }

                if isProcessing {
                    ProgressView("Preparing photo…")
                }
            }
            .padding(Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xxl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var libraryButton: some View {
        // Local copy: the picker's label closure is Sendable.
        let height = Theme.Size.primaryButtonHeight
        return PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose from library", systemImage: "photo.on.rectangle")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Theme.Palette.brandPurple)
        .disabled(isProcessing)
        .accessibilityHint("Pick a photo of the food instead of taking one")
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch state {
        case .needsExplanation:
            PrimaryButton(title: "Allow camera", action: onAllow)
                .accessibilityHint("Shows the system permission prompt")
        case .denied:
            PrimaryButton(title: "Open Settings") {
                if let url = AppSettingsURL.url { openURL(url) }
            }
            .accessibilityHint("Opens GatorPlate in the Settings app")
        default:
            EmptyView()
        }
    }

    private var content: (icon: String, title: String, message: String) {
        switch state {
        case .needsExplanation:
            ("camera.fill", "Snap the food. We'll draft the post.",
             "GatorPlate uses the camera only to photograph leftover food. Photograph the food, not people.")
        case .denied:
            ("camera.badge.ellipsis", "Camera access is off",
             "You can turn it on in Settings, or pick a photo from your library.")
        case .restricted:
            ("lock.fill", "Camera is restricted",
             "This device doesn't allow camera access. You can still pick a photo from your library.")
        case .unavailable:
            ("camera.metering.unknown", "No camera available",
             "Pick a photo of the food from your library instead.")
        case .failed(let message):
            ("exclamationmark.triangle.fill", "Camera unavailable", message)
        case .checking, .starting, .ready:
            ("camera", "", "")
        }
    }
}

#Preview("Explanation") {
    CameraPermissionView(state: .needsExplanation, pickerItem: .constant(nil)) {}
}

#Preview("Denied") {
    CameraPermissionView(state: .denied, pickerItem: .constant(nil)) {}
}

#Preview("Unavailable") {
    CameraPermissionView(state: .unavailable, pickerItem: .constant(nil)) {}
}
