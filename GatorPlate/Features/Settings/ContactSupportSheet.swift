import SwiftUI

/// Settings > About > Contact support, presented like the Terms and Privacy sheets (title and Done, no grabber): a
/// short header, the support address (Remote Config `support_email`) with Copy, and a tile per installed email app
/// (`MailApp`: Mail, Gmail, Outlook) with its logo and name. Mail writes in the app when it can; with no email app,
/// copying the address is the way.
struct ContactSupportSheet: View {
    let email: String

    @State private var apps: [MailApp] = []
    @State private var copied = false
    @State private var failedApp: MailApp?
    @State private var isComposingInApp = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title) private var circle: CGFloat = 64

    private static let subject = "GatorPlate support"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    header
                    addressCard
                    writeWith
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
            .alert("Couldn't open \(failedApp?.name ?? "the app")",
                   isPresented: Binding(get: { failedApp != nil }, set: { if !$0 { failedApp = nil } })) {
                Button("Copy address", action: copy)
                Button("OK", role: .cancel) {}
            } message: {
                Text("Copy the address and write to us from any email.")
            }
            .sheet(isPresented: $isComposingInApp) {
                MailComposeView(recipient: email, subject: Self.subject) { isComposingInApp = false }
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.success, trigger: copied) { _, now in now }
        .onAppear { apps = MailApp.installed }
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

    /// "Write with" and a tile per installed app, side by side (stacked at accessibility sizes).
    private var writeWith: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Write with")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if apps.isEmpty {
                Text("No email app found. Copy the address and write from any email.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            } else {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: Theme.Spacing.md))
                    : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
                layout {
                    ForEach(apps) { app in
                        Button { write(with: app) } label: { MailAppTile(app: app) }
                            .buttonStyle(TileButtonStyle())
                            .accessibilityLabel(app.name)
                            .accessibilityHint("Starts an email to GatorPlate support in \(app.name)")
                    }
                }
            }
        }
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

    private func write(with app: MailApp) {
        if app == .appleMail, MailApp.canComposeInApp {
            isComposingInApp = true
            return
        }
        guard let url = app.composeURL(to: email, subject: Self.subject) else {
            failedApp = app
            return
        }
        openURL(url) { accepted in
            if accepted { dismiss() } else { failedApp = app }
        }
    }
}

/// An email app's logo (or an envelope until the logo asset is added) over its name, on a plain card.
private struct MailAppTile: View {
    let app: MailApp

    @ScaledMetric(relativeTo: .title) private var logo: CGFloat = 52

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Group {
                if app.hasLogo {
                    Image(app.logoAsset)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: app.fallbackSymbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.Palette.brandPurple)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Palette.brandPurple.opacity(0.15))
                }
            }
            .frame(width: logo, height: logo)
            .clipShape(.rect(cornerRadius: logo * 0.225))
            .accessibilityHidden(true)
            Text(app.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, Theme.Spacing.lg)
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
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

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ContactSupportSheet(email: AppConfig.supportEmail)
    }
}

#Preview("AX5") {
    ContactSupportSheet(email: AppConfig.supportEmail)
        .dynamicTypeSize(.accessibility5)
}
