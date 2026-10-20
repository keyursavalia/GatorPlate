import SwiftUI

/// "Where & when": the place (opens the building picker), room / floor / entrance, and how long, one tap each.
struct ReviewWhereSection: View {
    @Bindable var viewModel: ReviewViewModel
    var focus: FocusState<ReviewFocus?>.Binding
    var highlighted: PostDraftValidator.Field?
    let onPickLocation: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        Section {
            Button(action: onPickLocation) {
                ListRow(title: viewModel.draft.location?.displayName ?? "Choose a place",
                        systemImage: "mappin.and.ellipse", showsDisclosure: true)
            }
            .accessibilityLabel("Place: \(viewModel.draft.location?.displayName ?? "not chosen")")
            .accessibilityHint("Opens the building list")
            .listRowBackground(rowHighlight(highlighted == .location))
            .id(PostDraftValidator.Field.location)

            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "door.left.hand.open")
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                TextField("Room, floor or entrance", text: $viewModel.locationDetail)
                    .focused(focus, equals: .room)
                    .submitLabel(.done)
                    .accessibilityLabel("Room, floor or entrance, required")
            }
            .listRowBackground(rowHighlight(highlighted == .locationDetail))
            .id(PostDraftValidator.Field.locationDetail)
            if let issue = viewModel.warning(for: .locationDetail) {
                ReviewIssueText(issue: issue)
                    .listRowBackground(rowHighlight(highlighted == .locationDetail))
            }

            Picker("Available for", selection: $viewModel.draft.durationMinutes) {
                ForEach(AppConfig.postDurationOptionsMinutes, id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(rowHighlight(highlighted == .duration))
            .id(PostDraftValidator.Field.duration)
        } header: {
            Text("Where & when")
        } footer: {
            TimelineView(.everyMinute) { context in
                let until = viewModel.availableUntil(now: context.date).formatted(date: .omitted, time: .shortened)
                Text("Ends at \(until). Food shouldn't sit out longer than this.")
            }
        }
    }
}
