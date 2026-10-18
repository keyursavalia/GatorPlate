import UIKit

/// Opens the Mail app's inbox ("Open Mail" after a reset link is sent). UIKit is imported only for `canOpenURL`,
/// which needs `message` in `LSApplicationQueriesSchemes` (Info.plist); open it with SwiftUI's `openURL`.
enum MailAppURL {
    static let url = URL(string: "message://")

    /// False when Mail was deleted; the button is hidden then.
    static var isAvailable: Bool {
        url.map(UIApplication.shared.canOpenURL) ?? false
    }
}
