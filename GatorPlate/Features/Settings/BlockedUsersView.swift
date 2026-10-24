import SwiftUI

/// Settings > Safety > Blocked people: everyone this user blocked, newest first, with Unblock (button and swipe).
/// Unblocking brings their posts back on Map and Feed at once.
struct BlockedUsersView: View {
    let blocked: BlockedUsers

    @State private var failureMessage: String?

    var body: some View {
        List {
            if !blocked.users.isEmpty {
                Section {
                    ForEach(blocked.users) { user in
                        row(user)
                    }
                } footer: {
                    Text("They can't see who blocked them. Unblocking shows their posts again.")
                }
            }
        }
        .overlay {
            if blocked.users.isEmpty {
                EmptyState(icon: "hand.raised.fill",
                           title: "No one blocked",
                           message: "You haven't blocked anyone. To block a poster, open their post and tap the ⋯ button.")
            }
        }
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't unblock", isPresented: Binding(get: { failureMessage != nil },
                                                        set: { if !$0 { failureMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private func row(_ user: BlockedUser) -> some View {
        let blockedText = "Blocked \(user.blockedAt.formatted(.relative(presentation: .named)))"
        return HStack(spacing: Theme.Spacing.md) {
            MonogramAvatar(name: user.name)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .foregroundStyle(Color.primary)
                Text(blockedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Button("Unblock") { unblock(user) }
                .buttonStyle(.bordered)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.name), \(blockedText.lowercased())")
        .accessibilityAction(named: "Unblock") { unblock(user) }
        .swipeActions {
            Button("Unblock") { unblock(user) }
                .tint(Theme.Palette.accent)
        }
    }

    private func unblock(_ user: BlockedUser) {
        Task {
            if await !blocked.unblock(uid: user.uid) { failureMessage = BlockedUsers.unblockFailedMessage }
        }
    }
}
