import SwiftUI

/// AI failed (offline, busy, unavailable). Posting never depends on AI: try again or fill it in.
struct AnalysisFailedView: View {
    let error: AppError
    var evalLine: String?
    let onRetry: () -> Void
    let onFillManually: () -> Void

    var body: some View {
        AnalysisMessageLayout(icon: icon, title: title, message: message, evalLine: evalLine) {
            PrimaryButton(title: "Fill it in myself", action: onFillManually)
            Button(action: onRetry) {
                Text("Try again")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Theme.Palette.brandPurple)
            .accessibilityHint("Runs the AI again on the same photo")
        }
    }

    private var icon: String {
        error == .network ? "wifi.slash" : "sparkles"
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

#Preview("Offline") {
    AnalysisFailedView(error: .network, onRetry: {}, onFillManually: {})
}
