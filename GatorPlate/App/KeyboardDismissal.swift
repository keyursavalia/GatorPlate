import UIKit

/// Tap anywhere outside a text field to put the keyboard away, on every screen (S09, user decision: one UIKit
/// helper instead of per-screen gestures, which can't see taps on List rows). One tap recognizer per window that
/// never cancels or delays other touches, so buttons and rows still get their taps; taps inside a text field or
/// text view (search fields too) are ignored. Swipe-down dismissal is `.scrollDismissesKeyboard(.interactively)`.
final class KeyboardDismissal: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissal()

    private var windows: [ObjectIdentifier] = []

    /// Idempotent; `AppDelegate` calls it whenever the app becomes active (windows exist by then).
    func install() {
        let allWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in allWindows where !windows.contains(ObjectIdentifier(window)) {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            windows.append(ObjectIdentifier(window))
        }
    }

    @objc private func dismissKeyboard(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
