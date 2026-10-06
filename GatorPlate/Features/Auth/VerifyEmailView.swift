import SwiftUI

/// Shown while the signed-in user's email isn't verified.
struct VerifyEmailView: View {
    @Bindable var viewModel: AuthViewModel
    let profile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Check your email")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("We sent a verification link to \(profile.email). Tap it, then come back here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                if let formError = viewModel.formError {
                    Banner(style: .error, message: formError)
                } else if let infoMessage = viewModel.infoMessage {
                    Banner(style: .info, message: infoMessage)
                }

                PrimaryButton(title: "I've verified my email", isLoading: viewModel.isSubmitting) {
                    Task { await viewModel.refreshVerification() }
                }
                Button("Resend email") { Task { await viewModel.sendVerificationEmail() } }
                    .frame(minHeight: Theme.Size.minTapTarget)
                Button("Use a different account", role: .destructive) { viewModel.signOut() }
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    VerifyEmailView(viewModel: AuthViewModel(auth: MockAuthService()),
                    profile: UserProfile(uid: "u", displayName: "Gator", email: "gator@gmail.com",
                                         accountType: .student, orgName: nil, acceptedTermsVersion: nil,
                                         acceptedTermsAt: nil, notificationsEnabled: false, createdAt: .now))
}
