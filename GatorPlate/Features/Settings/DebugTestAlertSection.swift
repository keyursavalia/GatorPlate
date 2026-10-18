#if DEBUG
import SwiftUI

/// DEBUG only (About): schedules a local alert with the real push's payload, so a tap can be tested from a killed,
/// background or foreground app without a second account. It goes through the same delegate and navigation code.
struct DebugTestAlertSection: View {
    let notifications: any NotificationService
    let posts: PostsRepository

    @State private var status: String?

    /// 20 alphanumeric characters like a real post ID, but never a real post: tests "no longer available".
    private static let missingPostId = "DEBUGMISSINGPOST0000"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Developer")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Button("Send test alert", systemImage: "bell.badge") {
                if let id = posts.activePosts.first?.id { send(postId: id) }
            }
            .disabled(posts.activePosts.isEmpty)
            .frame(minHeight: Theme.Size.minTapTarget)
            Button("Send test alert (missing post)", systemImage: "bell.slash") {
                send(postId: Self.missingPostId)
            }
            .frame(minHeight: Theme.Size.minTapTarget)
            Text(status ?? "Fires \(AppConfig.debugTestAlertDelaySeconds) s after the tap, for the newest post. Lock the phone, leave or close the app, then tap the alert.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func send(postId: String) {
        Task {
            do {
                try await notifications.scheduleTestAlert(postId: postId)
                status = "Scheduled. It arrives in \(AppConfig.debugTestAlertDelaySeconds) s."
            } catch {
                status = "Couldn't schedule it. Are notifications allowed?"
            }
            AccessibilityNotification.Announcement(status ?? "").post()
        }
    }
}
#endif
