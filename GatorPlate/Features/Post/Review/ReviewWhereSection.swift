import MapKit
import SwiftUI

/// "Where & when": the place (map thumbnail + name, opens the picker), room/floor/entrance, and how long.
struct ReviewWhereSection: View {
    @Bindable var viewModel: ReviewViewModel
    var focus: FocusState<ReviewFocus?>.Binding
    var highlighted: PostDraftValidator.Field?
    let onPickLocation: () -> Void

    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 56

    var body: some View {
        SectionCard(title: "Where & when", systemImage: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                place.id(PostDraftValidator.Field.location)
                room.id(PostDraftValidator.Field.locationDetail)
                Divider()
                duration.id(PostDraftValidator.Field.duration)
            }
        }
        .reviewHighlight(highlighted.map { [.location, .locationDetail, .duration].contains($0) } ?? false)
    }

    private var place: some View {
        Button(action: onPickLocation) {
            HStack(spacing: Theme.Spacing.md) {
                mapThumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.draft.location?.displayName ?? "Choose a building or spot")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(viewModel.draft.location == nil ? Theme.Palette.brandPurple : Color.primary)
                        .multilineTextAlignment(.leading)
                    Text("Change place").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Location: \(viewModel.draft.location?.displayName ?? "not chosen")")
        .accessibilityHint("Opens the building list")
    }

    @ViewBuilder
    private var mapThumbnail: some View {
        if let location = viewModel.draft.location {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: location.coordinate.clLocationCoordinate,
                                                   distance: 600)),
                interactionModes: []) {
                Marker("", coordinate: location.coordinate.clLocationCoordinate)
                    .tint(Theme.Palette.brandPurple)
            }
            .id(location)
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(.rect(cornerRadius: Theme.Radius.field))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .background(Theme.Palette.brandPurple.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.field))
                .accessibilityHidden(true)
        }
    }

    private var room: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Room / floor / entrance").font(.subheadline.weight(.semibold))
            TextField("e.g. Room 201, or east entrance", text: $viewModel.locationDetail)
                .focused(focus, equals: .room)
                .submitLabel(.done)
                .padding(Theme.Spacing.md)
                .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
                .accessibilityLabel("Room, floor or entrance, required")
        }
    }

    private var duration: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Available for").font(.subheadline.weight(.semibold))
                Spacer()
                TimelineView(.everyMinute) { context in
                    Text("until \(viewModel.availableUntil(now: context.date).formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            FlowLayout {
                ForEach(AppConfig.postDurationOptionsMinutes, id: \.self) { minutes in
                    ToggleChip(title: "\(minutes) min", systemImage: "clock",
                               isSelected: viewModel.draft.durationMinutes == minutes) {
                        viewModel.draft.durationMinutes = minutes
                    }
                }
            }
            Text("Posts end automatically. Food shouldn't sit out longer than this.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
