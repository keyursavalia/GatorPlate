import SwiftUI

/// Settings: profile card (opens Account), alerts and filters, display, privacy and safety, about, sign out.
/// DEBUG builds add a Developer section.
struct SettingsView: View {
    let session: MainSession
    let profile: UserProfile
    let isSigningOut: Bool
    let onSignOut: () -> Void
    /// Deletes the account with the user's password (see `MainTabView.deleteAccount`).
    let onDeleteAccount: (String) async throws -> Void

    @State private var isShowingTerms = false
    @State private var isConfirmingSignOut = false
    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    #if DEBUG
    @AppStorage("debug.mapBoundsOverlay") private var showsMapBoundsOverlay = false
    #endif
    @Environment(\.openURL) private var openURL

    private var viewModel: SettingsViewModel { session.settings }

    var body: some View {
        @Bindable var navigation = session.navigation
        NavigationStack(path: $navigation.settingsPath) {
            List {
                Section {
                    NavigationLink(value: AppNavigation.SettingsRoute.account) { profileCard }
                }
                alertsSection
                Section("Display") {
                    Toggle(isOn: $showCalories) {
                        Label("Show calorie estimates", systemImage: "flame")
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                }
                Section("Privacy & safety") {
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "hand.raised") }
                    Button { isShowingTerms = true } label: { Label("Terms of Use", systemImage: "doc.text") }
                }
                Section("About") {
                    NavigationLink { AboutView() } label: { Label("About GatorPlate", systemImage: "info.circle") }
                }
                Section {
                    Button(role: .destructive) { isConfirmingSignOut = true } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Sign out")
                            if isSigningOut { ProgressView() }
                        }
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .disabled(isSigningOut)
                }
                #if DEBUG
                Section("Developer") {
                    Toggle("Map bounds overlay", isOn: $showsMapBoundsOverlay)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationDestination(for: AppNavigation.SettingsRoute.self) { route in
                switch route {
                case .alertFilters:
                    AlertFiltersView(settings: viewModel, repository: session.repository)
                case .account:
                    AccountView(profile: profile, onDeleteAccount: onDeleteAccount)
                }
            }
            .sheet(isPresented: $isShowingTerms) {
                TermsOfUseSheet(onDismiss: { isShowingTerms = false })
            }
            .confirmationDialog("Sign out of GatorPlate?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive, action: onSignOut)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This phone stops getting free food alerts until you sign in again.")
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            MonogramAvatar(name: profile.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName).font(.headline)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(profile.email)
                    if AppConfig.requireEmailVerification {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.Palette.success)
                            .accessibilityLabel("verified")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(profile.accountType == .organization ? "Organization" : "Student")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your account")
    }

    private var alertsSection: some View {
        Section {
            Toggle(isOn: alertsBinding) {
                Label("Free food alerts", systemImage: "bell.badge")
            }
            .disabled(viewModel.isUpdating)
            .frame(minHeight: Theme.Size.minTapTarget)

            NavigationLink(value: AppNavigation.SettingsRoute.alertFilters) {
                LabeledContent {
                    Text(AlertFilterSummary.short(for: viewModel.alertFilters))
                } label: {
                    Label("What to alert me about", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            Toggle(isOn: quietHoursBinding) {
                Label(SettingsViewModel.quietHoursLabel, systemImage: "moon")
            }
            .disabled(!viewModel.alertsEnabled || viewModel.isUpdating)
            .frame(minHeight: Theme.Size.minTapTarget)

            if viewModel.isBlockedBySystem {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Notifications are off in iOS Settings.", systemImage: "bell.slash")
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
            Text("Alerts")
        } footer: {
            Text("You choose what you're alerted about; nothing is targeted by need. Your own posts don't alert you. Quiet hours use campus time (Pacific).")
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
    let session = MainSession.preview
    SettingsView(session: session, profile: UserProfile(uid: "mock-uid", displayName: "Alex Gator",
                                                        email: "alex@gmail.com", accountType: .student, orgName: nil,
                                                        acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                                        notificationsEnabled: true, createdAt: .now),
                 isSigningOut: false, onSignOut: {}, onDeleteAccount: { _ in })
}
