import SwiftUI

/// Review's Preview: the post exactly as students will see it in the map sheet, built from the draft, read-only.
struct ReviewPreviewSheet: View {
    let post: FoodPost
    let photoSources: [PostPhotoSource]

    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PostDetailContent(post: post, photoSources: photoSources, images: nil, distanceMeters: nil,
                              isExpanded: true, showCalories: showCalories) {
                EmptyView()
            } route: {
                Label("Directions and Apple Maps appear here for students.", systemImage: "figure.walk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } actions: {
                EmptyView()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(.background)
    }
}
