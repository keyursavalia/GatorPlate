import SwiftUI

/// Paged hero of a post's photos with a "1/3" counter. Tapping opens `PhotoViewer` with a zoom transition.
/// The counter sits on a solid pill: glass never goes over photos.
struct PhotoCarousel: View {
    let sources: [PostPhotoSource]
    let images: PostImageCache?
    var height: CGFloat = 220

    @Namespace private var zoomNamespace
    @State private var selection = 0
    @State private var isViewing = false

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                Button {
                    selection = index
                    isViewing = true
                } label: {
                    PostPhotoView(source: source, images: images, cornerRadius: Theme.Radius.photo)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: source.id, in: zoomNamespace)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: sources.count > 1 ? .automatic : .never))
        .frame(height: height)
        .overlay(alignment: .topTrailing) {
            if sources.count > 1 {
                Text("\(selection + 1)/\(sources.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(.black.opacity(0.65), in: .capsule)
                    .padding(Theme.Spacing.sm)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sources.count == 1 ? "Food photo" : "Food photos, \(selection + 1) of \(sources.count)")
        .accessibilityHint("Opens the photos full screen")
        .accessibilityAddTraits([.isImage, .isButton])
        .accessibilityAction { isViewing = true }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = min(selection + 1, sources.count - 1)
            case .decrement: selection = max(selection - 1, 0)
            @unknown default: break
            }
        }
        .fullScreenCover(isPresented: $isViewing) {
            PhotoViewer(sources: sources, images: images, selection: $selection)
                .navigationTransition(.zoom(sourceID: sources.indices.contains(selection) ? sources[selection].id : "",
                                            in: zoomNamespace))
        }
    }
}

#Preview {
    PhotoCarousel(sources: [.stored(postId: "a", slot: 0), .stored(postId: "a", slot: 1)], images: nil)
        .padding()
}
