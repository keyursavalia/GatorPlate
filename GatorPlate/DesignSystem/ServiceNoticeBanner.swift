import SwiftUI

/// The owner's service notice (Remote Config `service_notice`), on top of Map and Feed. `info` uses the accent,
/// `warning` the warning color; icon + text, never color alone. VoiceOver announces it once when it appears.
struct ServiceNoticeBanner: View {
    let message: String
    let level: ServiceNoticeLevel
    /// Glass over the map; a tinted card in the Feed.
    var isGlass = false

    private var tint: Color { level == .warning ? Theme.Palette.warning : Theme.Palette.accent }
    private var icon: String { level == .warning ? "exclamationmark.triangle.fill" : "megaphone.fill" }
    private var spoken: String { level == .warning ? "Warning" : "Notice" }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background {
            if isGlass {
                Color.clear.glassEffect(.regular.tint(tint.opacity(0.15)), in: .rect(cornerRadius: Theme.Radius.photo))
            } else {
                tint.opacity(0.12).clipShape(.rect(cornerRadius: Theme.Radius.photo))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spoken): \(message)")
        .task(id: message) {
            AccessibilityNotification.Announcement("\(spoken): \(message)").post()
        }
    }
}
