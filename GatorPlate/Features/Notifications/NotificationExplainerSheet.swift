import SwiftUI

/// Shown before the system permission prompt, which iOS only ever shows once.
struct NotificationExplainerSheet: View {
    let model: NotificationsModel

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandPurple)
                .accessibilityHidden(true)
            Text("Get alerts for free food")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("We'll let you know when someone on campus posts leftover food, so you can get there before it's gone. You can turn this off any time in Settings.")
                .multilineTextAlignment(.center)
            Text(model.footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Turn on alerts") {
                Task { await model.confirmExplainer() }
            }
            Button("Not now") { model.declineExplainer() }
                .frame(minHeight: Theme.minTapTarget)
        }
        .padding(Theme.Spacing.xl)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NotificationExplainerSheet(model: NotificationsModel(profile: SampleData.profile, service: MockNotificationService()))
        .environment(\.appEnvironment, .mock)
}
