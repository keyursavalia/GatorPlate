import SwiftUI

/// Labeled field with an inline error. Focus, submit label and `onSubmit` are applied by the parent.
struct AuthTextField: View {
    enum Kind {
        case email
        case password(isNew: Bool)
        case personName
        case organization
    }

    let title: String
    @Binding var text: String
    let kind: Kind
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            field
                .font(.body)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget + Theme.Spacing.s)
                .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.Radius.photo))
                .overlay {
                    if error != nil {
                        RoundedRectangle(cornerRadius: Theme.Radius.photo)
                            .strokeBorder(Color.danger, lineWidth: 1.5)
                    }
                }
                .accessibilityLabel(title)
                .accessibilityHint(error ?? "")

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.danger)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        switch kind {
        case .email:
            TextField(title, text: $text)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .password(let isNew):
            SecureField(title, text: $text)
                .textContentType(isNew ? .newPassword : .password)
        case .personName:
            TextField(title, text: $text)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
        case .organization:
            TextField(title, text: $text)
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
        }
    }
}

#Preview("States") {
    @Previewable @State var email = "test@gmail.com"
    @Previewable @State var password = ""
    VStack(spacing: Theme.Spacing.l) {
        AuthTextField(title: "SFSU email", text: $email, kind: .email, error: AuthMessages.invalidEmail)
        AuthTextField(title: "Password", text: $password, kind: .password(isNew: true))
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
