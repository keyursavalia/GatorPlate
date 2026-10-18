import SwiftUI

/// Bottom of the post sheet. Poster: a filled red Mark as gone (with confirmation). Others: "Reported" once they
/// report from the ⋯ menu. No pickup or claim tracking (R6).
struct PostActionsSection: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @State private var isConfirmingGone = false

    var body: some View {
        if viewModel.isOwnPost(post) {
            Section {
                DestructiveButton(title: "Mark as gone", isLoading: viewModel.markGoneStatus == .working) {
                    isConfirmingGone = true
                }
                .accessibilityHint("Removes this post for everyone")
            } footer: {
                if case .failed(let message) = viewModel.markGoneStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .confirmationDialog("Mark this food as gone?", isPresented: $isConfirmingGone, titleVisibility: .visible) {
                Button("Mark as gone", role: .destructive) {
                    Task { await viewModel.markGone(post) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It disappears from the map and feed for everyone.")
            }
        } else if viewModel.reportedPostIds.contains(post.id) {
            Section {
                NoteRow(text: "Reported. Thanks, we'll review it.", systemImage: "checkmark.seal")
            }
        }
    }
}
