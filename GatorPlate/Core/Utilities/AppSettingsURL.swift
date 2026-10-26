import UIKit

/// The app's page in the Settings app. UIKit is imported only for this constant; open it with `openURL`.
enum AppSettingsURL {
    static var url: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}
