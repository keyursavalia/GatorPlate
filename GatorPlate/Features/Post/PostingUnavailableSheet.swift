import SwiftUI

/// Shown instead of the post flow while Remote Config `posting_enabled` is off. Browsing, alerts, reporting and
/// blocking keep working.
struct PostingUnavailableSheet: View {
    /// The owner's `service_notice`, or empty for the default line.
    let notice: String
    @Environment(\.dismiss) private var dismiss

    private var message: String {
        notice.isEmpty ? "We're doing some maintenance. You can still browse and get alerts." : notice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.warning)
                    .accessibilityHidden(true)
                Text("Posting is paused right now")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: "OK") { dismiss() }
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PostingUnavailableSheet(notice: "")
    }
}

#Preview("Notice, AX5") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PostingUnavailableSheet(notice: "We're updating GatorPlate tonight. Posting is back by 9 PM.")
            .dynamicTypeSize(.accessibility5)
    }
}
