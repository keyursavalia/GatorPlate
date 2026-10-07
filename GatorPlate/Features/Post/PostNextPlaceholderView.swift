import SwiftUI

/// Temporary end of the Sprint 03 flow: shows the processed photo and its size.
/// Sprint 04 replaces it with the Analyzing step.
struct PostNextPlaceholderView: View {
    let photo: CapturedPhoto
    let onClose: () -> Void

    var body: some View {
        ScrollView {
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
                    .accessibilityLabel("Your food photo")

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Photo ready")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(sizeText)
                        .font(.body.monospacedDigit())
                    Text("Next, AI will draft your post from this photo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(.background)
    }

    private var sizeText: String {
        let bytes = ByteCountFormatter.string(fromByteCount: Int64(photo.jpegData.count), countStyle: .file)
        return "\(bytes) · \(photo.pixelWidth) × \(photo.pixelHeight) px"
    }
}
