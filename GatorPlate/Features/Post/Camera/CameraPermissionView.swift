import PhotosUI
import SwiftUI

/// Every camera state without a live preview: not asked yet (the backdrop for the system prompt), denied,
/// restricted, unavailable, failed. The photo library and manual entry are offered in all of them.
struct CameraPermissionView: View {
    let state: CameraViewModel.State
    @Binding var pickerItems: [PhotosPickerItem]
    /// Photos left in the tray; the library picks up to this many.
    var remaining = AppConfig.postMaxPhotos
    var isProcessing = false
    /// The system prompt is up: the "Allow camera" button hides so it never looks like a second ask.
    var isRequestingAccess = false
    /// Manual entry with no photo; hidden when nil.
    var onFillManually: (() -> Void)?
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
                    if let onFillManually {
                        Button("Fill it in myself", action: onFillManually)
                            .font(.headline)
                            .frame(minHeight: Theme.Size.minTapTarget)
                            .tint(Theme.Palette.brandPurple)
                            .accessibilityHint("Write the post without a photo or AI")
                    }
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
        return PhotosPicker(selection: $pickerItems, maxSelectionCount: max(remaining, 1),
                            selectionBehavior: .ordered, matching: .images) {
            Label("Choose from library", systemImage: "photo.on.rectangle")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Theme.Palette.brandPurple)
        .disabled(isProcessing || remaining == 0)
        .accessibilityHint("Pick up to \(remaining) photos of the food")
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch state {
        case .needsExplanation:
            if !isRequestingAccess {
                PrimaryButton(title: "Allow camera", action: onAllow)
                    .accessibilityHint("Shows the system permission prompt")
            }
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
    CameraPermissionView(state: .needsExplanation, pickerItems: .constant([])) {}
}

#Preview("Denied") {
    CameraPermissionView(state: .denied, pickerItems: .constant([])) {}
}

#Preview("Unavailable") {
    CameraPermissionView(state: .unavailable, pickerItems: .constant([])) {}
}
