import SwiftUI

/// A post's photo, loaded lazily from the shared cache, with a fork-knife placeholder while loading or
/// when there is no photo. Decorative for VoiceOver: the title and details carry the meaning.
struct PostPhotoView: View {
    let postId: String
    let hasPhoto: Bool
    let images: PostImageCache?
    var cornerRadius: CGFloat = Theme.Radius.photo

    @State private var image: CGImage?
    @State private var isLoading = false

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
            .task(id: postId) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        guard hasPhoto, let images else {
            image = nil
            return
        }
        if let cached = images.cachedImage(for: postId) {
            image = cached
            return
        }
        image = nil
        isLoading = true
        let loaded = await images.image(for: postId)
        isLoading = false
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { image = loaded }
    }
}

#Preview {
    PostPhotoView(postId: "sample-post", hasPhoto: false, images: nil)
        .frame(width: 120, height: 90)
}
