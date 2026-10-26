import SwiftUI

/// AI failed (offline, busy, unavailable). Posting never depends on AI: fill it in (the photos carry over) or try
/// again.
struct AnalysisFailedView: View {
    let error: AppError
    var photos: [CapturedPhoto] = []
    let onRetry: () -> Void
    let onFillManually: () -> Void

    var body: some View {
        AnalysisMessageLayout(photos: photos, status: status, title: title, message: message,
                              note: "Your photos are kept. You review everything before it's posted.") {
            PrimaryButton(title: "Fill it in myself", action: onFillManually)
                .accessibilityHint("Opens the post form with your photos")
            SecondaryButton(title: "Try again", action: onRetry)
                .accessibilityHint("Runs the AI again on the same photos")
        }
    }

    private var status: AnalysisStatus {
        switch error {
        case .network: .init(label: "Offline", icon: "wifi.slash", tint: Theme.Palette.warning)
        case .aiBusy: .init(label: "AI busy", icon: "hourglass", tint: Theme.Palette.warning)
        default: .init(label: "AI unavailable", icon: "exclamationmark.triangle.fill", tint: Theme.Palette.warning)
        }
    }

    private var title: String {
        switch error {
        case .network: "You're offline"
        case .aiBusy: "AI is busy"
        default: "AI couldn't draft this post"
        }
    }

    private var message: String {
        switch error {
        case .network: "You can still fill in the post yourself. Publishing needs a connection."
        default: error.userMessage
        }
    }
}
