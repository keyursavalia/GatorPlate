import UIKit

/// Copies plain text (the support address when Mail can't open). UIKit only for `UIPasteboard`.
enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
