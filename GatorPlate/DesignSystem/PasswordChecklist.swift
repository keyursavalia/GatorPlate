import SwiftUI

/// The new-password rules as a live checklist (Create account, Change password): gray circles until met, then green
/// checks. With `confirm`, a last line says whether the two passwords match.
struct PasswordChecklist: View {
    let password: String
    var confirm: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(PasswordRule.allCases, id: \.self) { rule in
                RuleLine(text: rule.text, isMet: rule.isMet(by: password))
            }
            if let confirm {
                RuleLine(text: "Passwords match", isMet: !confirm.isEmpty && confirm == password)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "✓ At least 8 characters": gray until met, then green with a filled check.
private struct RuleLine: View {
    let text: String
    let isMet: Bool

    var body: some View {
        Label(text, systemImage: isMet ? "checkmark.circle.fill" : "circle")
            .font(.footnote)
            .foregroundStyle(isMet ? Theme.Palette.success : .secondary)
            .animation(.default, value: isMet)
            .accessibilityLabel(text)
            .accessibilityValue(isMet ? "Done" : "Not yet")
    }
}

#Preview {
    PasswordChecklist(password: "Gator2026", confirm: "Gator2026")
        .padding()
}
