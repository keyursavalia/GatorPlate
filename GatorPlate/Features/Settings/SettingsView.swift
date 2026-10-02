import SwiftUI

/// Sprint 1 Settings: account info, Terms of Use, and Sign out.
struct SettingsView: View {
    let profile: UserProfile

    @Environment(AuthViewModel.self) private var viewModel
    @State private var showTerms = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Posting as", value: profile.displayName)
                    LabeledContent("Account type", value: accountTypeLabel)
                    LabeledContent("Email", value: profile.email)
                }

                Section {
                    Button("Terms of Use") { showTerms = true }
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }

                Section {
                    if let message = viewModel.signOutError {
                        Banner(kind: .error, message: message)
                    }
                    Button("Sign out", role: .destructive) {
                        Task { await viewModel.signOut() }
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

    private var accountTypeLabel: String {
        switch profile.accountType {
        case .student: "Student"
        case .organization: "Student Organization"
        }
    }
}

#Preview("Student") {
    SettingsView(profile: SampleData.profile)
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(SampleData.profile)))
        .environment(\.appEnvironment, .mock)
}

#Preview("Organization, AX3") {
    var org = SampleData.profile
    org.accountType = .organization
    org.orgName = "Gator Cooking Club"
    org.displayName = "Gator Cooking Club"
    return SettingsView(profile: org)
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(org)))
        .environment(\.appEnvironment, .mock)
        .dynamicTypeSize(.accessibility3)
}
