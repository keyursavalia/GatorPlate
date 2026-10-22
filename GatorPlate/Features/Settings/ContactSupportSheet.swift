import SwiftUI

/// Settings > About > Contact support: a short header, the support address (Remote Config `support_email`) as a
/// row that copies it, and every installed email app (`MailApp`) to write with, so people who don't use Mail can
/// pick theirs. With no email app, copying the address is the way.
struct ContactSupportSheet: View {
    let email: String

    @State private var apps: [MailApp] = []
    @State private var copied = false
    @State private var failedApp: MailApp?
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .title) private var circle: CGFloat = 64

    private static let subject = "GatorPlate support"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.lg, bottom: Theme.Spacing.sm,
                                                  trailing: Theme.Spacing.lg))
                }
                Section {
                    addressRow
                } footer: {
                    Text("Tap to copy the address.")
                }
                Section {
                    if apps.isEmpty {
                        NoteRow(text: "No email app found. Copy the address and write from any email.",
                                systemImage: "info.circle")
                    }
                    ForEach(apps) { app in
                        appRow(app)
                    }
                } header: {
                    Text("Write with")
                }
            }
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 52)
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// The address; tapping copies it, and the trailing icon turns into a check.
    private var addressRow: some View {
        Button(action: copy) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Support email")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(email)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(copied ? Theme.Palette.success : Theme.Palette.brandPurple)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Support email, \(email)")
        .accessibilityValue(copied ? "Copied" : "")
        .accessibilityHint("Copies the address")
    }

    private func appRow(_ app: MailApp) -> some View {
        Button { write(with: app) } label: {
            HStack(spacing: Theme.Spacing.md) {
                ListRow(title: app.name, systemImage: app == .standard ? "envelope.fill" : "envelope",
                        subtitle: app == .standard ? "Your default email app" : nil)
                Image(systemName: "arrow.up.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint("Starts an email to GatorPlate support in \(app.name)")
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
        guard let url = app.composeURL(to: email, subject: Self.subject) else {
            failedApp = app
            return
        }
        openURL(url) { accepted in
            if accepted { dismiss() } else { failedApp = app }
        }
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
