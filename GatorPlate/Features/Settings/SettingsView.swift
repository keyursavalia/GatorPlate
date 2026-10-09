import SwiftUI

/// Account, free food alerts and sign out. Calorie toggle and Terms link arrive in Sprint 08.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    let profile: UserProfile
    let isSigningOut: Bool
    let onSignOut: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent(profile.accountType == .organization ? "Organization" : "Name",
                                   value: profile.displayName)
                }

                alertsSection

                Section {
                    Button(role: .destructive, action: onSignOut) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Sign out")
                            if isSigningOut { ProgressView() }
                        }
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Settings")
            .alert("Get free food alerts?", isPresented: $viewModel.isShowingExplainer) {
                Button("Continue") { Task { await viewModel.confirmAlerts() } }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("We'll let you know when someone posts free food on campus. Everyone who opts in gets the same alert, and GatorPlate never tracks what you pick up. You can turn this off anytime.")
            }
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle(isOn: alertsBinding) {
                Label("New free food alerts", systemImage: "bell.badge")
            }
            .disabled(viewModel.isUpdating)
            .frame(minHeight: Theme.Size.minTapTarget)

            Toggle(isOn: quietHoursBinding) {
                Label(SettingsViewModel.quietHoursLabel, systemImage: "moon")
            }
            .disabled(!viewModel.alertsEnabled || viewModel.isUpdating)
            .frame(minHeight: Theme.Size.minTapTarget)

            if viewModel.isBlockedBySystem {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Notifications are off for GatorPlate in iOS Settings.", systemImage: "bell.slash")
                        .font(.subheadline)
                    Button("Open Settings", action: openSettings)
                        .frame(minHeight: Theme.Size.minTapTarget)
                }
            }

            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.danger)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Alerts go to everyone who opts in, never targeted by need. Your own posts don't alert you. Quiet hours use campus time (Pacific).")
        }
    }

    private var alertsBinding: Binding<Bool> {
        Binding(get: { viewModel.alertsEnabled },
                set: { enabled in Task { await viewModel.setAlerts(enabled) } })
    }

    private var quietHoursBinding: Binding<Bool> {
        Binding(get: { viewModel.quietHoursEnabled },
                set: { enabled in Task { await viewModel.setQuietHours(enabled) } })
    }

    private func openSettings() {
        guard let url = AppSettingsURL.url else { return }
        openURL(url)
    }
}

#Preview {
    let profile = UserProfile(uid: "mock-uid", displayName: "Mock Student", email: "mock@gmail.com",
                              accountType: .student, orgName: nil, acceptedTermsVersion: nil, acceptedTermsAt: nil,
                              notificationsEnabled: false, createdAt: .now)
    SettingsView(viewModel: SettingsViewModel(notifications: MockNotificationService(), profile: profile),
                 profile: profile, isSigningOut: false, onSignOut: {})
}
