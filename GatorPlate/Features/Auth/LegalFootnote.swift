import SwiftUI

/// "By signing in, I agree to GatorPlate's Privacy Policy and Terms of Use." with underlined links that open the
/// documents in a sheet. Centered, footnote size.
struct LegalFootnote: View {
    /// The words before the links, e.g. "By signing in, I agree to".
    let lead: String
    /// Words after the links, before the final period (e.g. the AI disclosure on Welcome).
    var trailing: String?

    @State private var openDocument: LegalDocument.Kind?

    var body: some View {
        Text(attributed)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .tint(Theme.Palette.brandPurple)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                guard let kind = LegalDocument.Kind(rawValue: url.host() ?? "") else { return .discarded }
                openDocument = kind
                return .handled
            })
            .sheet(item: $openDocument) { kind in
                LegalDocumentSheet(kind: kind) { openDocument = nil }
            }
    }

    private var attributed: AttributedString {
        var text = AttributedString("\(lead) \(AppConfig.appName)'s ")
        text += link(.privacy)
        text += AttributedString(" and ")
        text += link(.terms)
        if let trailing { text += AttributedString(", \(trailing)") }
        text += AttributedString(".")
        return text
    }

    private func link(_ kind: LegalDocument.Kind) -> AttributedString {
        var link = AttributedString(kind.title)
        link.link = URL(string: "gatorplate-legal://\(kind.rawValue)")
        link.underlineStyle = .single
        link.inlinePresentationIntent = .stronglyEmphasized
        return link
    }
}

#Preview {
    LegalFootnote(lead: "By signing in, I agree to").padding()
}
