import SwiftUI

/// Step 1b of the Post flow: look at the shot, then retake or continue.
struct PhotoPreviewScreen: View {
    let photo: CapturedPhoto
    let onRetake: () -> Void
    let onUse: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Photo you just took")

            VStack(spacing: Theme.Spacing.s) {
                PrimaryButton(title: "Use photo", action: onUse)
                Button("Retake", action: onRetake)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
                    .accessibilityHint("Goes back to the camera")
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface.ignoresSafeArea())
    }
}

#Preview("Preview") {
    PhotoPreviewScreen(photo: PreviewSupport.photo(), onRetake: {}, onUse: {})
        .environment(\.appEnvironment, .mock)
}

/// Builds a photo for previews through the real preprocessor.
enum PreviewSupport {
    static func photo(variant: Int = 0) -> CapturedPhoto {
        let data = PlaceholderImage.jpegData(variant: variant)
        return (try? ImagePreprocessor.process(data: data))
            ?? CapturedPhoto(previewImage: UIImage(), jpegData: data)
    }
}
