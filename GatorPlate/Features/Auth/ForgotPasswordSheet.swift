import SwiftUI

/// "Forgot password": an email form, then "Check your email" in its place. The Sent state never says whether the
/// account exists. Opened from Sign in (typed email) or from Account > Change password (the account's own email).
struct ForgotPasswordSheet: View {
    enum Start: Equatable {
        /// From Sign in, prefilled with the Sign in email.
        case signIn(email: String)
        /// From Account: sends to the signed-in account right away.
        case account(email: String)
    }

    let model: PasswordResetModel
    let start: Start
    /// "Back to sign in": closes the sheet and hands the email back to the Sign in form.
    var onBackToSignIn: ((String) -> Void)?

    @State private var email: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(model: PasswordResetModel, start: Start, onBackToSignIn: ((String) -> Void)? = nil) {
        self.model = model
        self.start = start
        self.onBackToSignIn = onBackToSignIn
        switch start {
        case .signIn(let email), .account(let email): _email = State(initialValue: email)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch model.phase {
                    case .form: form
                    case .sent(let email): PasswordResetSentView(model: model, email: email, isAccount: isAccount,
                                                                 onBack: back, onEditEmail: editEmail)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear(perform: open)
        .onChange(of: model.phase) { _, phase in
            guard case .sent = phase else { return }
            AccessibilityNotification.Announcement("Check your email. \(sentLine)").post()
        }
    }

    private var isAccount: Bool {
        if case .account = start { true } else { false }
    }

    private var sentLine: String {
        if case .sent(let email) = model.phase { AccountMessages.resetSent(to: email) } else { "" }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: Theme.Spacing.xl) {
            AuthHeader(title: "Reset password", subtitle: "We'll email you a link to reset your password.")
                .padding(.top, Theme.Spacing.lg)
            if isAccount {
                // Account: the link goes to the account's email; the form only shows while sending or after an error.
                if let message = model.errorMessage {
                    Banner(style: .error, message: message)
                    sendButton(title: "Try again")
                } else {
                    ProgressView("Sending...")
                }
            } else {
                UnderlineField(error: model.errorMessage, isFocused: isFocused) {
                    TextField("Email address", text: $email,
                              prompt: UnderlineField<EmptyView>.prompt("Email address", error: model.errorMessage))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit(send)
                }
                sendButton(title: "Send reset link")
            }
        }
    }

    /// Disabled while a link sent moments ago is cooling down, with the wait spelled out once (not per tick).
    private func sendButton(title: String) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let wait = model.secondsUntilResend(at: context.date)
            let isDisabled = wait > 0 || (!isAccount && email.isEmpty)
            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: title, isLoading: model.isSending, action: send)
                    .textCase(.uppercase)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.5 : 1)
                    .accessibilityValue(wait > 0 ? "Available in \(wait) seconds" : "")
                if wait > 0 {
                    Text("You can send another link in \(wait) s.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Actions

    private func open() {
        model.prepareForOpen()
        if case .account(let email) = start, model.phase == .form {
            Task { await model.sendToCurrentUser(email: email) }
        } else if model.phase == .form {
            isFocused = email.isEmpty
        }
    }

    private func send() {
        isFocused = false
        Task {
            if case .account(let email) = start {
                await model.sendToCurrentUser(email: email)
            } else {
                await model.send(email: email)
            }
        }
    }

    private func editEmail() {
        model.editEmail()
        isFocused = true
    }

    private func back() {
        if case .sent(let sentEmail) = model.phase, !isAccount { onBackToSignIn?(sentEmail) }
        dismiss()
    }
}
