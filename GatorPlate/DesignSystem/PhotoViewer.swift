import SwiftUI

/// Full-screen pager over a post's photos: pinch or double-tap to zoom, swipe down to close. In the post flow it
/// also offers Remove and Make cover. Presented with a zoom transition from its source (`PhotoCarousel`, `PhotoTray`).
struct PhotoViewer: View {
    struct EditActions {
        let onRemove: (PostPhotoSource) -> Void
        let onMakeCover: (PostPhotoSource) -> Void
    }

    let sources: [PostPhotoSource]
    let images: PostImageCache?
    @Binding var selection: Int
    var editActions: EditActions?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom: CGFloat = 1
    @State private var dragOffset: CGFloat = 0

    private static let maxZoom: CGFloat = 4
    private static let dismissDistance: CGFloat = 120

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    PostPhotoView(source: source, images: images, cornerRadius: 0, contentMode: .fit)
                        .scaleEffect(index == selection ? zoom : 1)
                        .tag(index)
                        .accessibilityElement()
                        .accessibilityLabel("Photo \(index + 1) of \(sources.count)")
                        .accessibilityAddTraits(.isImage)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .gesture(magnify)
            .simultaneousGesture(dismissDrag)
            .onTapGesture(count: 2) {
                withAnimation(reduceMotion ? nil : .snappy) { zoom = zoom > 1 ? 1 : 2.5 }
            }
            .onChange(of: selection) { zoom = 1 }
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomBar }
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close photos", action: { dismiss() })
            Spacer()
            if sources.count > 1 {
                Text("\(selection + 1)/\(sources.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(.black.opacity(0.65), in: .capsule)
                    .accessibilityLabel("Photo \(selection + 1) of \(sources.count)")
            }
        }
        .padding(Theme.Spacing.lg)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let editActions, sources.indices.contains(selection) {
            let source = sources[selection]
            GlassEffectContainer {
                HStack(spacing: Theme.Spacing.md) {
                    if selection != 0 {
                        Button("Make cover", systemImage: "star") { editActions.onMakeCover(source) }
                            .buttonStyle(.glass)
                            .frame(minHeight: Theme.Size.minTapTarget)
                    }
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        editActions.onRemove(source)
                        if sources.count <= 1 { dismiss() }
                    }
                    .buttonStyle(.glass)
                    .frame(minHeight: Theme.Size.minTapTarget)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in zoom = min(max(value.magnification, 1), Self.maxZoom) }
            .onEnded { _ in
                if zoom < 1.1 { withAnimation(reduceMotion ? nil : .snappy) { zoom = 1 } }
            }
    }

    /// Swipe down to close, only when not zoomed (zoomed, the drag pans the pager).
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard zoom == 1, value.translation.height > 0,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation.height
            }
            .onEnded { _ in
                if dragOffset > Self.dismissDistance {
                    dismiss()
                } else {
                    withAnimation(reduceMotion ? nil : .snappy) { dragOffset = 0 }
                }
            }
    }
}
