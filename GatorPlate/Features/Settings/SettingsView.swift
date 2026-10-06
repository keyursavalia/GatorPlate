import SwiftUI

/// Placeholder settings. Notifications, calorie toggle and terms arrive in later sprints.
struct SettingsView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent(profile.accountType == .organization ? "Organization" : "Name",
                                   value: profile.displayName)
                }
                Section {
                    Button("Sign out", role: .destructive, action: onSignOut)
                        .frame(minHeight: Theme.Size.minTapTarget)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
