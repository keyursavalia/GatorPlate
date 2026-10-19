import SwiftUI

/// "Check your email" after a reset link is requested. The message is the same whether or not the account exists.
/// Open Mail (when Mail is installed), Resend with a cooldown, and Back to sign in (or Done from Account).
struct PasswordResetSentView: View {
    let model: PasswordResetModel
    let email: String
    let isAccount: Bool
    let onBack: () -> Void
    let onEditEmail: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.brandPurple)
                .padding(.top, Theme.Spacing.xl)
                .accessibilityHidden(true)
            AuthHeader(title: "Check your email", subtitle: AccountMessages.resetSent(to: email))
            Label("It can take a minute. Check Spam or Junk.", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let message = model.errorMessage {
                Banner(style: .error, message: message)
            }

            VStack(spacing: Theme.Spacing.md) {
                if MailAppURL.isAvailable, let url = MailAppURL.url {
                    PrimaryButton(title: "Open Mail") { openURL(url) }
                        .textCase(.uppercase)
                }
                resendButton
                AuthTextButton(title: isAccount ? "Done" : "Back to sign in", action: onBack)
                if !isAccount {
                    AuthTextButton(title: "Use a different email", action: onEditEmail)
                }
            }
        }
    }

    /// "Resend link (45 s)" while cooling down. VoiceOver reads "Resend link, available in 45 seconds" when it
    /// lands on the button, not on every tick.
    private var resendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let wait = model.secondsUntilResend(at: context.date)
            SecondaryButton(title: wait > 0 ? "Resend link (\(wait) s)" : "Resend link") {
                Task { await model.resend() }
            }
            .disabled(wait > 0 || model.isSending)
            .opacity(wait > 0 || model.isSending ? 0.5 : 1)
            .accessibilityLabel("Resend link")
            .accessibilityValue(wait > 0 ? "Available in \(wait) seconds" : "")
        }
    }
}

#Preview {
    ScrollView {
        PasswordResetSentView(model: PasswordResetModel(account: MockAccountService()), email: "student@gmail.com",
                              isAccount: false, onBack: {}, onEditEmail: {})
            .padding()
    }
}

#Preview("AX5") {
    ScrollView {
        PasswordResetSentView(model: PasswordResetModel(account: MockAccountService()), email: "student@gmail.com",
                              isAccount: true, onBack: {}, onEditEmail: {})
            .padding()
    }
    .dynamicTypeSize(.accessibility5)
}
