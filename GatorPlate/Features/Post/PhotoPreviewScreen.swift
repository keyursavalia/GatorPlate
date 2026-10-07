import SwiftUI

/// Post flow step 1b: confirm the photo or retake it.
struct PhotoPreviewScreen: View {
    let photo: CapturedPhoto
    let onRetake: () -> Void
    let onUse: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close",
                                accessibilityHint: "Cancels the post", action: onClose)
                Spacer()
            }

            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Your food photo")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.md) { buttons }
                VStack(spacing: Theme.Spacing.md) { buttons }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.background)
    }

    @ViewBuilder
    private var buttons: some View {
        Button(action: onRetake) {
            Text("Retake")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Theme.Palette.brandPurple)
        .accessibilityHint("Goes back to the camera")

        PrimaryButton(title: "Use photo", action: onUse)
            .accessibilityHint("Continues with this photo")
    }
}
