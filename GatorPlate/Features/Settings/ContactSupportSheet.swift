import SwiftUI

/// Settings > About > Contact support: the support address (Remote Config `support_email`) with Copy, and every
/// installed email app (`MailApp`) to write with, so people who don't use Mail can pick theirs. With no email app,
/// copying the address is the way.
struct ContactSupportSheet: View {
    let email: String

    @State private var apps: [MailApp] = []
    @State private var copied = false
    @State private var failedApp: MailApp?
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private static let subject = "GatorPlate support"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Theme.Spacing.md) {
                        ListRow(title: email, systemImage: "envelope", subtitle: "Support email")
                            .textSelection(.enabled)
                        Button(copied ? "Copied" : "Copy", action: copy)
                            .buttonStyle(.bordered)
                            .accessibilityLabel(copied ? "Address copied" : "Copy address")
                    }
                } footer: {
                    Text("We read every message and reply as soon as we can. "
                         + "Reports of offensive posts are reviewed within 24 hours.")
                }
                Section {
                    if apps.isEmpty {
                        NoteRow(text: "No email app found. Copy the address and write from any email.",
                                systemImage: "info.circle")
                    }
                    ForEach(apps) { app in
                        Button { write(with: app) } label: {
                            ListRow(title: app.name, systemImage: app == .standard ? "envelope.fill" : "paperplane",
                                    subtitle: app == .standard ? "Your phone's default email app" : nil,
                                    showsDisclosure: true)
                        }
                        .accessibilityHint("Starts an email to GatorPlate support in \(app.name)")
                    }
                } header: {
                    Text("Write with")
                }
            }
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
        .presentationDetents([.medium, .large])
        .onAppear { apps = MailApp.installed }
    }

    private func copy() {
        Clipboard.copy(email)
        copied = true
        AccessibilityNotification.Announcement("Address copied").post()
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
