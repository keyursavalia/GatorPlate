import SwiftUI

/// Settings: profile card (opens Account) or, for guests, a Join / Sign in card; notifications (custom notifications
/// and quiet hours only while notifications are on); display; privacy and legal; about; sign out for accounts.
struct SettingsView: View {
    let session: MainSession
    let authSession: AuthSession
    let isSigningOut: Bool
    /// Forgot password, for Account > Change password.
    let passwordReset: PasswordResetModel
    /// Opens the account flow (join, sign in, or verify the email).
    let onRequestAccount: (AccountFlowView.Start) -> Void
    let onSignOut: () -> Void
    /// Deletes the account with the user's password (see `MainTabView.deleteAccount`).
    let onDeleteAccount: (String) async throws -> Void

    @State private var openDocument: LegalDocument.Kind?
    @State private var isConfirmingSignOut = false
    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @Environment(\.openURL) private var openURL
    @Environment(\.appEnvironment) private var environment

    private var viewModel: SettingsViewModel { session.settings }
    private var profile: UserProfile { authSession.profile }

    @ViewBuilder
    private var aboutView: some View {
        #if DEBUG
        AboutView(testAlert: DebugTestAlertSection(notifications: environment.notifications, posts: session.repository))
        #else
        AboutView()
        #endif
    }

    var body: some View {
        @Bindable var navigation = session.navigation
        NavigationStack(path: $navigation.settingsPath) {
            List {
                if authSession.isGuest {
                    guestCard
                } else {
                    Section {
                        NavigationLink(value: AppNavigation.SettingsRoute.account) { profileCard }
                        if authSession.needsVerification {
                            Button { onRequestAccount(.signIn) } label: {
                                ListRow(title: "Verify your email to post", systemImage: "envelope.badge")
                            }
                        }
                    }
                }
                alertsSection
                Section("Display") {
                    Toggle(isOn: $showCalories) {
                        ListRow(title: "Show calorie estimates", systemImage: "flame")
                    }
                }
                Section("Privacy & legal") {
                    NavigationLink { PrivacyView() } label: {
                        ListRow(title: "Your privacy", systemImage: "hand.raised")
                    }
                    documentRow(.terms, systemImage: "doc.text")
                }
                Section("About") {
                    NavigationLink { aboutView } label: {
                        ListRow(title: "About GatorPlate", systemImage: "info.circle")
                    }
                }
                if !authSession.isGuest {
                    Section {
                        DestructiveButton(title: "Sign out", isLoading: isSigningOut) { isConfirmingSignOut = true }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .environment(\.defaultMinListRowHeight, 52)
            .animation(.default, value: viewModel.alertsEnabled)
            .navigationTitle("Settings")
            .navigationDestination(for: AppNavigation.SettingsRoute.self) { route in
                switch route {
                case .alertFilters:
                    AlertFiltersView(settings: viewModel)
                case .account:
                    AccountView(profile: profile, passwordReset: passwordReset, onDeleteAccount: onDeleteAccount)
                }
            }
            .sheet(item: $openDocument) { kind in
                LegalDocumentSheet(kind: kind) { openDocument = nil }
            }
            .confirmationDialog("Sign out of GatorPlate?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive, action: onSignOut)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll keep browsing as a guest. Notifications on this phone stop until you turn them on again.")
            }
        }
    }

    // MARK: Account

    private var profileCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            MonogramAvatar(name: profile.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName).font(.headline)
                Text(profile.accountType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your account")
    }

    /// Guests browse and get alerts without an account; this is the only place that offers one.
    private var guestCard: some View {
        Section {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .accessibilityHidden(true)
                Text("Posting food?")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text("Share leftovers in seconds")
                    .font(.title2.weight(.heavy).width(.condensed))
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Browsing and notifications work without an account. You need one only to post.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: Theme.Spacing.sm) {
                    PrimaryButton(title: "Join now") { onRequestAccount(.join) }
                    SecondaryButton(title: "Sign in") { onRequestAccount(.signIn) }
                }
                .textCase(.uppercase)
                .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // MARK: Alerts

    private var alertsSection: some View {
        Section {
            Toggle(isOn: alertsBinding) {
                ListRow(title: "Free food notifications", systemImage: "bell.badge")
            }
            .disabled(viewModel.isUpdating)

            if viewModel.alertsEnabled {
                NavigationLink(value: AppNavigation.SettingsRoute.alertFilters) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ListRow(title: "Custom notifications", systemImage: "line.3.horizontal.decrease.circle")
                        filterGlance
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Custom notifications")
                    .accessibilityValue(AlertFilterSummary.spoken(for: viewModel.alertFilters))
                }
                Toggle(isOn: quietHoursBinding) {
                    ListRow(title: SettingsViewModel.quietHoursLabel, systemImage: "moon")
                }
                .disabled(viewModel.isUpdating)
            }

            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.danger)
            }
        } header: {
            Text("Notifications")
        } footer: {
            if viewModel.isBlockedBySystem {
                Text("Notifications are off for GatorPlate in iOS Settings.")
            } else {
                Text(viewModel.alertsEnabled
                     ? "You choose what you're notified about; nothing is targeted by need. Your own posts don't notify you."
                     : "Get a notification when free food is posted on campus.")
            }
        }
        .alert("Turn on notifications in Settings", isPresented: settingsPromptBinding) {
            Button("Open Settings") {
                viewModel.willOpenSystemSettings()
                openSettings()
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Open Settings, tap Notifications, then turn on Allow Notifications. They'll be on when you come back.")
        }
    }

    private var settingsPromptBinding: Binding<Bool> {
        Binding(get: { viewModel.showsSettingsPrompt }, set: { viewModel.showsSettingsPrompt = $0 })
    }

    /// "All" for all free food, "On" once custom notifications are set (VoiceOver names the categories).
    private var filterGlance: some View {
        Text(AlertFilterSummary.categories(for: viewModel.alertFilters).isEmpty ? "All" : "On")
            .foregroundStyle(.secondary)
    }

    private var alertsBinding: Binding<Bool> {
        Binding(get: { viewModel.alertsEnabled },
                set: { enabled in Task { await viewModel.setAlerts(enabled) } })
    }

    private var quietHoursBinding: Binding<Bool> {
        Binding(get: { viewModel.quietHoursEnabled },
                set: { enabled in Task { await viewModel.setQuietHours(enabled) } })
    }

    // MARK: Helpers

    private func documentRow(_ kind: LegalDocument.Kind, systemImage: String) -> some View {
        Button { openDocument = kind } label: {
            ListRow(title: kind.title, systemImage: systemImage, showsDisclosure: true)
        }
        .foregroundStyle(.primary)
    }

    private func openSettings() {
        guard let url = AppSettingsURL.url else { return }
        openURL(url)
    }
}

#Preview("Account") {
    let session = MainSession.preview
    SettingsView(session: session,
                 authSession: AuthSession(profile: UserProfile(uid: "mock-uid", displayName: "Alex Gator",
                                                               email: "alex@gmail.com", accountType: .student,
                                                               orgName: nil, acceptedTermsVersion: nil,
                                                               acceptedTermsAt: nil, notificationsEnabled: true,
                                                               createdAt: .now),
                                          isEmailVerified: true),
                 isSigningOut: false, passwordReset: PasswordResetModel(account: MockAccountService()),
                 onRequestAccount: { _ in }, onSignOut: {}, onDeleteAccount: { _ in })
}

#Preview("Guest") {
    let session = MainSession.preview
    SettingsView(session: session,
                 authSession: AuthSession(profile: UserProfile(uid: "mock-uid", displayName: "Guest", email: nil,
                                                               accountType: .guest, orgName: nil,
                                                               acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                                               notificationsEnabled: false, createdAt: .now),
                                          isEmailVerified: false),
                 isSigningOut: false, passwordReset: PasswordResetModel(account: MockAccountService()),
                 onRequestAccount: { _ in }, onSignOut: {}, onDeleteAccount: { _ in })
}
