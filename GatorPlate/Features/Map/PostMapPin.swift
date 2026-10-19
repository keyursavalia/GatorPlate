import SwiftUI

/// A post's pin on the map: `PostPin` with the cover photo once its thumbnail is ready (glyph until then, or
/// when the post has no photo or `AppConfig.mapPhotoPins` is off). Shares the photo download with the Feed.
struct PostMapPin: View {
    let post: FoodPost
    let isSelected: Bool
    let images: PostImageCache?

    @State private var photo: CGImage?

    var body: some View {
        PostPin(dietary: post.overallDietary, isSelected: isSelected, photo: photo)
            .animation(.easeOut(duration: 0.2), value: photo != nil)
            .task(id: post.id) { await load() }
    }

    private func load() async {
        guard AppConfig.mapPhotoPins, let images, let slot = post.coverSlot else {
            photo = nil
            return
        }
        if let cached = images.cachedThumbnail(for: post.id, slot: slot) {
            photo = cached
            return
        }
        let loaded = await images.thumbnail(for: post.id, slot: slot)
        guard !Task.isCancelled else { return }
        photo = loaded
    }
}
