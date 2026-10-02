import SwiftUI

/// TEMPORARY (Sprint 3): proves the photo hand-off. Sprint 4 replaces this with the analyzing screen.
struct PostNextPlaceholderView: View {
    let photo: CapturedPhoto
    let onRetake: () -> Void
    let onClose: () -> Void

    private var sizeText: String {
        let bytes = ByteCountFormatter.string(fromByteCount: Int64(photo.byteCount), countStyle: .file)
        let size = photo.pixelSize
        return "\(Int(size.width)) x \(Int(size.height)) px, \(bytes)"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Photo ready to use")

            VStack(spacing: Theme.Spacing.xs) {
                Text("Photo ready")
                    .font(.title2.bold())
                Text(sizeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Temporary screen: the AI draft arrives in the next sprint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: Theme.Spacing.s) {
                PrimaryButton(title: "Done", action: onClose)
                Button("Retake", action: onRetake)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface.ignoresSafeArea())
    }
}

#Preview("Next placeholder") {
    PostNextPlaceholderView(photo: PreviewSupport.photo(variant: 1), onRetake: {}, onClose: {})
        .environment(\.appEnvironment, .mock)
}
