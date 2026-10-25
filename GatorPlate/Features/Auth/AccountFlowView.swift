import SwiftUI

enum AuthFocusField: Hashable {
    case name, email, password, confirmPassword
}

/// Sign in, create an account, or verify the email, full screen with a close button. Shown only when an account
/// is needed (posting) or asked for (Settings). The owner closes it once the session can post.
struct AccountFlowView: View {
    /// Why the flow opened; sets the first screen and the subtitle.
    enum Start: String, Identifiable {
        case post, join, signIn
        var id: String { rawValue }
    }

    let start: Start
    @Bindable var viewModel: AuthViewModel
    /// Signing in replaces the guest session: remove its alert registration first, restart it on failure.
    let prepareSwitch: () async -> Void
    let restore: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let session = viewModel.session, session.needsVerification {
                        VerifyEmailView(viewModel: viewModel, email: session.profile.email ?? "")
                    } else if viewModel.mode == .signUp {
                        CreateAccountForm(viewModel: viewModel, submit: submit)
                    } else {
                        SignInForm(viewModel: viewModel, subtitle: signInSubtitle, submit: submit)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.default, value: viewModel.mode)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .disabled(viewModel.isSubmitting)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSubmitting)
        .onAppear {
            viewModel.setMode(start == .join ? .signUp : .logIn)
            viewModel.clearFormMessages()
        }
    }

    private var signInSubtitle: String {
        start == .post ? "Sign in to post free food." : "Welcome back, Gator."
    }

    private func submit() {
        Task { await viewModel.submit(prepareSwitch: prepareSwitch, restore: restore) }
    }
}
