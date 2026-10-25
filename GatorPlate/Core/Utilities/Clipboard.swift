import UIKit

/// Copies plain text (the support address in Contact support). UIKit only for `UIPasteboard`.
enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
