import SwiftUI

/// Settings: profile card (opens Account) or, for guests, a Join / Sign in card; alerts (filters and quiet hours
/// only while alerts are on); display; privacy and legal; about; sign out for accounts.
struct SettingsView: View {
    let session: MainSession
    let authSession: AuthSession
    let isSigningOut: Bool
    /// Opens the account flow (join, sign in, or verify the email).
    let onRequestAccount: (AccountFlowView.Start) -> Void
    let onSignOut: () -> Void
    /// Deletes the account with the user's password (see `MainTabView.deleteAccount`).
    let onDeleteAccount: (String) async throws -> Void

    @State private var openDocument: LegalDocument.Kind?
    @State private var isConfirmingSignOut = false
    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @Environment(\.openURL) private var openURL

    private var viewModel: SettingsViewModel { session.settings }
    private var profile: UserProfile { authSession.profile }

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
                    documentRow(.privacy, systemImage: "lock.doc")
                    documentRow(.terms, systemImage: "doc.text")
                }
                Section("About") {
                    NavigationLink { AboutView() } label: {
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
                    AccountView(profile: profile, onDeleteAccount: onDeleteAccount)
                }
            }
            .sheet(item: $openDocument) { kind in
                LegalDocumentSheet(kind: kind) { openDocument = nil }
            }
            .confirmationDialog("Sign out of GatorPlate?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive, action: onSignOut)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll keep browsing as a guest. Alerts on this phone stop until you turn them on again.")
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
                Text("Browsing and alerts work without an account. You need one only to post.")
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
                ListRow(title: "Free food alerts", systemImage: "bell.badge")
            }
            .disabled(viewModel.isUpdating)

            if viewModel.alertsEnabled {
                NavigationLink(value: AppNavigation.SettingsRoute.alertFilters) {
                    ListRow(title: "What to alert me about", systemImage: "line.3.horizontal.decrease.circle",
                                value: AlertFilterSummary.short(for: viewModel.alertFilters))
                }
                Toggle(isOn: quietHoursBinding) {
                    ListRow(title: SettingsViewModel.quietHoursLabel, systemImage: "moon")
                }
                .disabled(viewModel.isUpdating)
            }

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
            Text(viewModel.alertsEnabled
                 ? "You choose what you're alerted about; nothing is targeted by need. Your own posts don't alert you."
                 : "Get a notification when free food is posted on campus.")
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
                 isSigningOut: false, onRequestAccount: { _ in }, onSignOut: {}, onDeleteAccount: { _ in })
}

#Preview("Guest") {
    let session = MainSession.preview
    SettingsView(session: session,
                 authSession: AuthSession(profile: UserProfile(uid: "mock-uid", displayName: "Guest", email: nil,
                                                               accountType: .guest, orgName: nil,
                                                               acceptedTermsVersion: nil, acceptedTermsAt: nil,
                                                               notificationsEnabled: false, createdAt: .now),
                                          isEmailVerified: false),
                 isSigningOut: false, onRequestAccount: { _ in }, onSignOut: {}, onDeleteAccount: { _ in })
}
