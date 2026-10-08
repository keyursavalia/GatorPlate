import SwiftUI

/// Poster: Mark as gone (with confirmation). Everyone else: Report. No pickup or claim tracking (R6).
struct PostActionsSection: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @State private var isConfirmingGone = false
    @State private var isReporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if viewModel.isOwnPost(post) {
                markGone
            } else {
                report
            }
        }
    }

    @ViewBuilder
    private var markGone: some View {
        Button(role: .destructive) {
            isConfirmingGone = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if viewModel.markGoneStatus == .working {
                    ProgressView()
                }
                Label("Mark as gone", systemImage: "checkmark.circle")
            }
            .frame(minHeight: Theme.Size.minTapTarget)
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.markGoneStatus == .working)
        .accessibilityHint("Removes this post for everyone")
        .confirmationDialog("Mark this food as gone?", isPresented: $isConfirmingGone, titleVisibility: .visible) {
            Button("Mark as gone", role: .destructive) {
                Task { await viewModel.markGone(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears from the map and feed for everyone.")
        }

        if case .failed(let message) = viewModel.markGoneStatus {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.danger)
        }
    }

    @ViewBuilder
    private var report: some View {
        if viewModel.reportedPostIds.contains(post.id) {
            Label("Reported. Thanks, we'll review it.", systemImage: "checkmark.seal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Button {
                isReporting = true
            } label: {
                Label("Report", systemImage: "flag")
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
            .buttonStyle(.borderless)
            .tint(.secondary)
            .accessibilityHint("Tell us if this post is not food, unsafe or spam")
            .sheet(isPresented: $isReporting) {
                ReportReasonSheet(post: post, viewModel: viewModel)
            }
        }
    }
}
