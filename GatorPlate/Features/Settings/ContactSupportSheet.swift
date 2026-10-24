import SwiftUI

/// Settings > About > Contact support, presented like the Terms and Privacy sheets (title and Done, no grabber): a
/// short header and the support address (Remote Config `support_email`) with Copy.
struct ContactSupportSheet: View {
    let email: String

    @State private var copied = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title) private var circle: CGFloat = 64

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    header
                    addressCard
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: copied) { _, now in now }
    }

    /// Envelope in a tinted circle, a title and what to expect. Centered.
    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "envelope.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(width: circle, height: circle)
                .background(Theme.Palette.brandPurple.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.xs) {
                Text("We're here to help")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("We read every message and reply as soon as we can. "
                     + "Reports of offensive posts are reviewed within 24 hours.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// "Email us at" over the address, with a Copy capsule that turns into "Copied" for 2 s. The whole card copies.
    private var addressCard: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
        return Button(action: copy) {
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email us at")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Text(email)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Theme.Spacing.sm) }
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 7)
                    .background(Theme.Palette.brandPurple.opacity(0.25), in: .capsule)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(copied ? "Address copied" : "Copy address, \(email)")
    }

    private func copy() {
        Clipboard.copy(email)
        withAnimation { copied = true }
        AccessibilityNotification.Announcement("Address copied").post()
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }
}

/// Dims a tile while pressed.
private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
    }
}
