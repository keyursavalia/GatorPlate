import SwiftUI

/// Sticky bottom bar: blocking issues collapse into an "N things left" chip (tap scrolls to the first one),
/// and Publish shows when the post will end. Errors and the cooldown appear above it.
struct ReviewPublishBar: View {
    let viewModel: ReviewViewModel
    let onShowIssue: () -> Void
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            switch viewModel.publishState {
            case .failed(let message):
                Banner(style: .error, message: message,
                       actions: [Banner.Action(title: "Try again", handler: onPublish),
                                 Banner.Action(title: "OK", isPrimary: false) { viewModel.dismissPublishMessage() }])
            case .cooldown(let seconds):
                Banner(style: .warning, message: "You just posted. You can post again in \(seconds) s.",
                       actions: [Banner.Action(title: "OK", isPrimary: false) { viewModel.dismissPublishMessage() }])
            case .idle, .publishing:
                EmptyView()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.md) { content }
                VStack(spacing: Theme.Spacing.sm) { content }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        let count = viewModel.blockingIssues.count
        if count > 0 {
            Button(action: onShowIssue) {
                Label(count == 1 ? "1 thing left" : "\(count) things left", systemImage: "chevron.down.circle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.md)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .background(Theme.Palette.danger.opacity(0.12), in: .capsule)
                    .foregroundStyle(Theme.Palette.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(count) required \(count == 1 ? "item" : "items") left: "
                                + viewModel.blockingIssues.map(\.message).joined(separator: " "))
            .accessibilityHint("Scrolls to the first one")
        }
        TimelineView(.everyMinute) { context in
            let until = viewModel.availableUntil(now: context.date).formatted(date: .omitted, time: .shortened)
            PrimaryButton(title: "Publish · until \(until)", isLoading: viewModel.publishState == .publishing,
                          action: onPublish)
                .disabled(!viewModel.canPublish)
                .opacity(viewModel.canPublish ? 1 : 0.5)
                .accessibilityHint(viewModel.canPublish ? "Posts your food for everyone on campus"
                                                        : "Finish the required items first")
        }
    }
}
