import MessageUI
import UIKit

/// The email apps Contact support offers: Apple Mail, Gmail and Outlook, each shown only when it's on the phone.
/// Apple Mail writes in the app (`MFMailComposeViewController`) when a Mail account is set up, else through
/// `mailto:`; Gmail and Outlook open their own compose screens. Availability uses `canOpenURL`, which needs each
/// scheme in `LSApplicationQueriesSchemes` (Info.plist). UIKit is imported only for that; open URLs with SwiftUI's
/// `openURL`.
nonisolated enum MailApp: String, CaseIterable, Identifiable {
    case appleMail
    case gmail
    case outlook

    var id: String { rawValue }

    var name: String {
        switch self {
        case .appleMail: "Mail"
        case .gmail: "Gmail"
        case .outlook: "Outlook"
        }
    }

    /// The asset catalog image for the app's logo. Until it's added, `fallbackSymbol` shows instead.
    var logoAsset: String {
        switch self {
        case .appleMail: "MailLogo"
        case .gmail: "GmailLogo"
        case .outlook: "OutlookLogo"
        }
    }

    var fallbackSymbol: String { self == .appleMail ? "envelope.fill" : "envelope" }

    /// A new message to `address` with `subject` filled in (Apple Mail: `mailto:`, used when the in-app composer
    /// can't send).
    func composeURL(to address: String, subject: String) -> URL? {
        var components = URLComponents()
        switch self {
        case .appleMail:
            components.scheme = "mailto"
            components.path = address
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        case .gmail:
            components.scheme = "googlegmail"
            components.host = "co"
            components.queryItems = [URLQueryItem(name: "to", value: address), URLQueryItem(name: "subject", value: subject)]
        case .outlook:
            components.scheme = "ms-outlook"
            components.host = "compose"
            components.queryItems = [URLQueryItem(name: "to", value: address), URLQueryItem(name: "subject", value: subject)]
        }
        return components.url
    }

    /// True when Mail has an account set up, so the in-app composer can send.
    @MainActor
    static var canComposeInApp: Bool { MFMailComposeViewController.canSendMail() }

    /// The installed apps, in `allCases` order. Mail counts when it's installed (`message:`) or can send.
    @MainActor
    static var installed: [MailApp] {
        allCases.filter { app in
            switch app {
            case .appleMail:
                canComposeInApp || URL(string: "message://").map(UIApplication.shared.canOpenURL) == true
            case .gmail, .outlook:
                app.composeURL(to: "support@example.com", subject: "").map(UIApplication.shared.canOpenURL) ?? false
            }
        }
    }

    /// Whether the logo image has been added to the asset catalog.
    @MainActor
    var hasLogo: Bool { UIImage(named: logoAsset) != nil }
}
