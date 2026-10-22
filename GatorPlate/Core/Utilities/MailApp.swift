import UIKit

/// Email apps the support sheet can write with. Each has a compose URL; an app is listed only when it's installed
/// (`canOpenURL`, which needs every scheme in `LSApplicationQueriesSchemes` in Info.plist). UIKit is imported only
/// for `canOpenURL`; open the URL with SwiftUI's `openURL`.
nonisolated enum MailApp: String, CaseIterable, Identifiable {
    /// `mailto:`: the phone's default email app (Mail unless the person changed it).
    case standard
    case gmail
    case outlook
    case spark
    case yahoo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: "Mail"
        case .gmail: "Gmail"
        case .outlook: "Outlook"
        case .spark: "Spark"
        case .yahoo: "Yahoo Mail"
        }
    }

    /// A new message to `address` with `subject` filled in.
    func composeURL(to address: String, subject: String) -> URL? {
        var components = URLComponents()
        switch self {
        case .standard:
            components.scheme = "mailto"
            components.path = address
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        case .gmail:
            components = Self.components("googlegmail", host: "co", path: "", to: ("to", address), subject: subject)
        case .outlook:
            components = Self.components("ms-outlook", host: "compose", path: "", to: ("to", address), subject: subject)
        case .spark:
            components = Self.components("readdle-spark", host: "compose", path: "", to: ("recipient", address),
                                         subject: subject)
        case .yahoo:
            components = Self.components("ymail", host: "mail", path: "/compose", to: ("to", address), subject: subject)
        }
        return components.url
    }

    /// The installed apps, in `allCases` order.
    @MainActor
    static var installed: [MailApp] {
        allCases.filter { app in
            app.composeURL(to: "support@example.com", subject: "").map(UIApplication.shared.canOpenURL) ?? false
        }
    }

    private static func components(_ scheme: String, host: String, path: String, to: (String, String),
                                   subject: String) -> URLComponents {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = [URLQueryItem(name: to.0, value: to.1), URLQueryItem(name: "subject", value: subject)]
        return components
    }
}
