import SwiftUI

/// Account flow step after sign-up while the email isn't verified. Browsing keeps working meanwhile; only
/// posting waits for it.
struct VerifyEmailView: View {
    @Bindable var viewModel: AuthViewModel
    let email: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
                .padding(.top, Theme.Spacing.xl)
            AuthHeader(title: "Check your email",
                       subtitle: "We sent a verification link to \(email). Tap it, then come back here.")

            if let formError = viewModel.formError {
                Banner(style: .error, message: formError)
            } else if let infoMessage = viewModel.infoMessage {
                Banner(style: .info, message: infoMessage)
            }

            VStack(spacing: Theme.Spacing.md) {
                PrimaryButton(title: "I've verified my email", isLoading: viewModel.isSubmitting) {
                    Task { await viewModel.refreshVerification() }
                }
                .textCase(.uppercase)
                AuthTextButton(title: "Resend email") { Task { await viewModel.sendVerificationEmail() } }
                Button("Use a different account", role: .destructive) { viewModel.signOut() }
                    .font(.subheadline)
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
        }
    }
}
