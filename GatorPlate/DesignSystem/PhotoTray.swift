import SwiftUI

/// Thumbnail strip of the photos chosen so far (camera and Review). The first is marked as the cover.
/// Tap opens the photo; long-press and drag reorders; VoiceOver gets Move left/right, Make cover and Remove.
struct PhotoTray<AddButton: View>: View {
    let photos: [CapturedPhoto]
    let onSelect: (Int) -> Void
    let onMove: (_ id: UUID, _ targetId: UUID) -> Void
    let onMoveBy: (_ id: UUID, _ offset: Int) -> Void
    let onMakeCover: (UUID) -> Void
    let onRemove: (UUID) -> Void
    /// Shown after the thumbnails while there's room (for example a library picker).
    @ViewBuilder var addButton: AddButton

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 56

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    thumbnail(photo, index: index)
                }
                addButton
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func thumbnail(_ photo: CapturedPhoto, index: Int) -> some View {
        Button { onSelect(index) } label: {
            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: Theme.Radius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.field)
                        .strokeBorder(index == 0 ? Theme.Palette.brandGold : .white.opacity(0.8),
                                      lineWidth: index == 0 ? 3 : 1)
                }
                .overlay(alignment: .bottomLeading) {
                    if index == 0 {
                        Image(systemName: "star.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(3)
                            .background(Theme.Palette.brandGold, in: .circle)
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
        .draggable(photo.id.uuidString) {
            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: Theme.Radius.field))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let dropped = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            onMove(dropped, photo.id)
            return true
        }
        .accessibilityLabel(index == 0 ? "Photo 1, cover" : "Photo \(index + 1)")
        .accessibilityHint("Opens the photo")
        .accessibilityAction(named: "Move left") { onMoveBy(photo.id, -1) }
        .accessibilityAction(named: "Move right") { onMoveBy(photo.id, 1) }
        .accessibilityAction(named: "Make cover") { onMakeCover(photo.id) }
        .accessibilityAction(named: "Remove") { onRemove(photo.id) }
    }
}
