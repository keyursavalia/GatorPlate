import SwiftUI

/// Full-width brand button, 52 pt tall, with a loading state.
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.lg)
            .foregroundStyle(.white)
            .background(Theme.Palette.brandPurple, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

#Preview("Idle") {
    PrimaryButton(title: "Continue") {}.padding()
}

#Preview("Loading, large text") {
    PrimaryButton(title: "Continue", isLoading: true) {}
        .padding()
        .dynamicTypeSize(.accessibility5)
}
