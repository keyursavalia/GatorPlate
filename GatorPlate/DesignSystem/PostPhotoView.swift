import SwiftUI

/// Where a photo comes from: a photo in the post flow (in memory) or a published post's slot (Cloud Storage,
/// through the shared `PostImageCache`).
enum PostPhotoSource: Hashable, Identifiable {
    case captured(CapturedPhoto)
    case stored(postId: String, slot: Int)

    var id: String {
        switch self {
        case .captured(let photo): photo.id.uuidString
        case .stored(let postId, let slot): PostImageCache.key(postId: postId, slot: slot)
        }
    }

    /// Every uploaded photo of a post, cover first.
    static func sources(for post: FoodPost) -> [PostPhotoSource] {
        post.photoSlots.map { .stored(postId: post.id, slot: $0) }
    }
}

/// One photo, filling its frame, with a fork-knife placeholder while loading or when there is none.
/// Decorative for VoiceOver: titles and details carry the meaning.
struct PostPhotoView: View {
    let source: PostPhotoSource?
    let images: PostImageCache?
    var cornerRadius: CGFloat = Theme.Radius.photo
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var isLoading = false

    var body: some View {
        Color.clear
            .overlay {
                switch source {
                case .captured(let photo):
                    Image(uiImage: photo.previewImage)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .stored:
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .transition(.opacity)
                    } else {
                        placeholder
                    }
                case nil:
                    placeholder
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
            .task(id: source) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Theme.Palette.brandPurple.opacity(0.12))
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.brandPurple)
            }
        }
    }

    private func load() async {
        guard case .stored(let postId, let slot) = source, let images else {
            image = nil
            return
        }
        if let cached = images.cachedImage(for: postId, slot: slot) {
            image = cached
            return
        }
        image = nil
        isLoading = true
        let loaded = await images.image(for: postId, slot: slot)
        isLoading = false
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { image = loaded }
    }
}

#Preview {
    PostPhotoView(source: nil, images: nil)
        .frame(width: 120, height: 90)
}
