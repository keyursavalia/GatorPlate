import SwiftUI

/// Top-of-screen overlay: a new-post alert (tap opens the post) or the "no longer available" notice.
struct AlertBannerOverlay: View {
    let model: NotificationsModel
    let onOpen: (String) -> Void

    private static let autoDismiss: Duration = .seconds(6)

    var body: some View {
        VStack {
            if let content = model.banner {
                Banner(
                    kind: .info,
                    message: AlertContentFormatter.bannerMessage(for: content),
                    actionTitle: "View"
                ) {
                    model.dismissBanner()
                    onOpen(content.postID)
                }
                .shadow(radius: 4)
                .task(id: content) {
                    try? await Task.sleep(for: Self.autoDismiss)
                    if !Task.isCancelled { model.dismissBanner() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let notice = model.unavailableNotice {
                Banner(kind: .warning, message: notice, actionTitle: "OK") { model.dismissUnavailableNotice() }
                    .shadow(radius: 4)
                    .task(id: notice) {
                        try? await Task.sleep(for: Self.autoDismiss)
                        if !Task.isCancelled { model.dismissUnavailableNotice() }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .animation(.default, value: model.banner)
        .animation(.default, value: model.unavailableNotice)
        .sensoryFeedback(.impact(weight: .light), trigger: model.banner)
    }
}

#Preview("New post alert") {
    let model = NotificationsModel(profile: SampleData.profile, service: MockNotificationService())
    Color.surface.overlay(alignment: .top) { AlertBannerOverlay(model: model) { _ in } }
        .task {
            await model.refreshPermission()
        }
        .environment(\.appEnvironment, .mock)
}
