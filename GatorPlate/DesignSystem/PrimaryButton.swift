import SwiftUI

/// Full-width brand button, at least 52 pt tall, with a loading state.
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .padding(.horizontal, Theme.Spacing.l)
            .background(Color.brandPurple, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
    }
}

#Preview("Idle and loading") {
    VStack(spacing: Theme.Spacing.l) {
        PrimaryButton(title: "Continue") {}
        PrimaryButton(title: "Continue", isLoading: true) {}
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
