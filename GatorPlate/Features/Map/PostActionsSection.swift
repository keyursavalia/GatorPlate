import SwiftUI

/// Bottom of the post sheet. Poster: a filled red Mark as gone (`onMarkGone` asks to confirm with a system alert,
/// held by `PostBottomCard` outside the list). Others: "Reported" once they report from the ⋯ menu. No pickup or
/// claim tracking (R6).
struct PostActionsSection: View {
    let post: FoodPost
    let viewModel: MapViewModel
    let onMarkGone: () -> Void

    var body: some View {
        if viewModel.isOwnPost(post) {
            Section {
                DestructiveButton(title: "Mark as gone", isLoading: viewModel.markGoneStatus == .working,
                                  action: onMarkGone)
                .accessibilityHint("Removes this post for everyone")
            } footer: {
                if case .failed(let message) = viewModel.markGoneStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } else if viewModel.reportedPosts.contains(post.id) {
            Section {
                NoteRow(text: "Reported. Thanks, we'll review it.", systemImage: "checkmark.seal")
            }
        }
    }
}
