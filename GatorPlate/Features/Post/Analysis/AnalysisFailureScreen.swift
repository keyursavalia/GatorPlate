import SwiftUI

/// Shown for a rejected photo (not food, people, blocked) or a failed analysis. Both offer retake and manual entry.
struct AnalysisFailureScreen: View {
    let title: String
    let message: String
    var retryTitle: String?
    var onRetry: (() -> Void)?
    let onRetake: () -> Void
    let onManual: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.warning)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            VStack(spacing: Theme.Spacing.s) {
                if let retryTitle, let onRetry {
                    PrimaryButton(title: retryTitle, action: onRetry)
                } else {
                    PrimaryButton(title: "Retake photo", action: onRetake)
                }
                if onRetry != nil {
                    Button("Retake photo", action: onRetake)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                Button("Fill it in myself", action: onManual)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface.ignoresSafeArea())
    }
}

#Preview("Rejected") {
    AnalysisFailureScreen(
        title: RejectionReason.notFood.title, message: RejectionReason.notFood.detail,
        onRetake: {}, onManual: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Failed") {
    AnalysisFailureScreen(
        title: "Couldn't analyze", message: AppError.network.analysisMessage,
        retryTitle: "Try again", onRetry: {}, onRetake: {}, onManual: {}
    )
    .environment(\.appEnvironment, .mock)
}
