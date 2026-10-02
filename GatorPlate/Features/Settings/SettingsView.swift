import SwiftUI

/// Sprint 1 Settings: account info, Terms of Use, and Sign out.
struct SettingsView: View {
    let profile: UserProfile
    let notifications: NotificationsModel

    @Environment(AuthViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL
    @State private var showTerms = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Posting as", value: profile.displayName)
                    LabeledContent("Account type", value: accountTypeLabel)
                    LabeledContent("Email", value: profile.email)
                }

                notificationsSection

                Section {
                    Button("Terms of Use") { showTerms = true }
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }

                Section {
                    if let message = viewModel.signOutError {
                        Banner(kind: .error, message: message)
                    }
                    Button("Sign out", role: .destructive) {
                        Task {
                            // Remove this device's push token while still signed in.
                            await notifications.detachDevice()
                            await viewModel.signOut()
                        }
                    }
                    .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }

                if !AppConfig.requireEmailVerification {
                    Section {
                        Text("DEMO MODE: GatorPlate is a hackathon prototype, not an official SFSU app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showTerms) {
                TermsOfUseSheet(requiresAcceptance: false)
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Free food alerts", isOn: Binding(
                get: { notifications.isEnabled },
                set: { newValue in Task { await notifications.setEnabled(newValue) } }
            ))
            .frame(minHeight: Theme.minTapTarget)
            .accessibilityHint("Alerts you when someone posts free food")
            if let message = notifications.errorMessage {
                if notifications.permission == .denied {
                    Banner(kind: .warning, message: message, actionTitle: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } else {
                    Banner(kind: .error, message: message)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(notifications.footnote)
        }
        .task { await notifications.refreshPermission() }
    }

    private var accountTypeLabel: String {
        switch profile.accountType {
        case .student: "Student"
        case .organization: "Student Organization"
        }
    }
}

#Preview("Student") {
    SettingsView(profile: SampleData.profile, notifications: NotificationsModel(profile: SampleData.profile, service: MockNotificationService()))
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(SampleData.profile)))
        .environment(\.appEnvironment, .mock)
}

#Preview("Organization, AX3") {
    var org = SampleData.profile
    org.accountType = .organization
    org.orgName = "Gator Cooking Club"
    org.displayName = "Gator Cooking Club"
    return SettingsView(profile: org, notifications: NotificationsModel(profile: org, service: MockNotificationService()))
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(org)))
        .environment(\.appEnvironment, .mock)
        .dynamicTypeSize(.accessibility3)
}
