import SwiftUI

/// Solid capsule notice with an optional action. Announced to VoiceOver when it appears and hides after
/// `duration`, but never while VoiceOver focus is on it. Solid, not glass: it carries text over the map.
struct Toast: View {
    struct Action {
        let title: String
        let handler: () -> Void
    }

    let message: String
    var systemImage = "checkmark.circle.fill"
    var action: Action?
    var duration: Double = AppConfig.toastSeconds
    let onDismiss: () -> Void

    @AccessibilityFocusState private var isFocused: Bool
    @State private var hasElapsed = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.md) { content }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { content }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.background, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isFocused)
        .task {
            AccessibilityNotification.Announcement(spokenText).post()
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            hasElapsed = true
            if !isFocused { onDismiss() }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, hasElapsed { onDismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        Label {
            Text(message).font(.subheadline)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Theme.Palette.success)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let action {
            Button(action.title) {
                action.handler()
                onDismiss()
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: Theme.Size.minTapTarget)
        }
        Button("Dismiss", systemImage: "xmark", action: onDismiss)
            .labelStyle(.iconOnly)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
    }

    private var spokenText: String {
        if let action { "\(message). \(action.title) is available." } else { message }
    }
}

#Preview {
    VStack {
        Toast(message: "Alerts on for all free food.", action: Toast.Action(title: "Customize") {}, onDismiss: {})
        Toast(message: "Saved.", onDismiss: {})
    }
    .padding()
    .background(.gray.opacity(0.3))
}

#Preview("AX5") {
    Toast(message: "Alerts on for all free food.", action: Toast.Action(title: "Customize") {}, onDismiss: {})
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
