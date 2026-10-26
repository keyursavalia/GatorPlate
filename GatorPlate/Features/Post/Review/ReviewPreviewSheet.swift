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
                              showCalories: showCalories) {
                EmptyView()
            } actions: {
                Section {
                    NoteRow(text: "Students also see walking time and Open in Apple Maps.", systemImage: "figure.walk")
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
