import SwiftUI

/// Temporary landing for "Fill it in myself". Sprint 05 replaces it with the Review form (no AI, photo optional).
struct ManualEntryPlaceholderView: View {
    /// Nil when there is no photo, or when it was rejected for showing people.
    let photo: CapturedPhoto?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                if let photo {
                    Image(uiImage: photo.previewImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                        .frame(maxHeight: 280)
                        .accessibilityLabel("Your food photo")
                } else {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.Palette.brandPurple)
                        .accessibilityHidden(true)
                }
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Fill in your post")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("The post form arrives in the next update. You'll add the food, allergens, location and time yourself.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
    }
}
