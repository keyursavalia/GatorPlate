import SwiftUI

/// Minimal text field: the placeholder sits on a single underline that turns brand purple while focused and red
/// with a centered message on error. 44 pt minimum height; the field supplies its own VoiceOver label.
struct UnderlineField<Content: View>: View {
    var error: String?
    var isFocused = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                content
            }
            .font(.title3)
            .frame(minHeight: Theme.Size.minTapTarget)
            Rectangle()
                .fill(lineColor)
                .frame(height: isFocused || error != nil ? 2 : 1)
                .accessibilityHidden(true)
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Error: \(error)")
            }
        }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var lineColor: Color {
        if error != nil { return Theme.Palette.danger }
        return isFocused ? Theme.Palette.brandPurple : Color.secondary.opacity(0.4)
    }

    /// Placeholder text, red while the field shows an error.
    static func prompt(_ text: String, error: String?) -> Text {
        Text(text).foregroundStyle(error == nil ? Color.secondary : Theme.Palette.danger)
    }
}

/// Password field with a show/hide eye button.
struct UnderlinePasswordField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var isFocused = false
    var isNewPassword = false

    @State private var isRevealed = false

    var body: some View {
        UnderlineField(error: error, isFocused: isFocused) {
            Group {
                if isRevealed {
                    TextField(label, text: $text, prompt: UnderlineField<EmptyView>.prompt(label, error: error))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(label, text: $text, prompt: UnderlineField<EmptyView>.prompt(label, error: error))
                }
            }
            .textContentType(isNewPassword ? .newPassword : .password)
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""
    VStack(spacing: Theme.Spacing.xl) {
        UnderlineField(isFocused: true) {
            TextField("Email", text: $email, prompt: UnderlineField<EmptyView>.prompt("Email", error: nil))
        }
        UnderlinePasswordField(label: "Password", text: $password, error: "Password is required.")
    }
    .padding()
}
