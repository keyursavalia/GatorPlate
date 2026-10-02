import SwiftUI

/// A post's photo, loaded lazily from the `ImageStore` (cached) with a placeholder while it loads or when there is none.
struct PostPhotoView: View {
    let postID: String
    let hasPhoto: Bool
    var size: CGFloat = 72

    @Environment(\.appEnvironment) private var environment
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(image, scale: 1, label: Text("Photo of the food"))
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceSecondary
                Image(systemName: hasPhoto ? "photo" : "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
        .task(id: postID) { await load() }
    }

    private func load() async {
        guard hasPhoto else {
            image = nil
            return
        }
        guard let data = try? await environment.images.load(forPostID: postID) else { return }
        image = await PhotoDecoder.cgImage(from: data)
    }
}

#Preview("Photo states") {
    HStack {
        PostPhotoView(postID: "none", hasPhoto: false)
        PostPhotoView(postID: "loading", hasPhoto: true)
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
