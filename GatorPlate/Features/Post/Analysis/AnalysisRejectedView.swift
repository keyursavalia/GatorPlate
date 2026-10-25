import SwiftUI

/// The photo can't become a post (not food, people, unclear). Offers a retake or the manual path. Photos showing
/// people are blurred here and never carried over.
struct AnalysisRejectedView: View {
    let reason: FoodAnalysisRejection
    var photos: [CapturedPhoto] = []
    let onRetake: () -> Void
    let onFillManually: () -> Void

    var body: some View {
        AnalysisMessageLayout(photos: photos, obscuresPhotos: reason == .containsPeople, status: content.status,
                              title: content.title, message: content.message, note: content.note) {
            PrimaryButton(title: reason == .containsPeople ? "Take new photos" : "Back to photos", action: onRetake)
            SecondaryButton(title: "Fill it in myself", action: onFillManually)
                .accessibilityHint("Opens the post form without AI")
        }
    }

    private var content: (status: AnalysisStatus, title: String, message: String, note: String) {
        switch reason {
        case .notFood:
            (AnalysisStatus(label: "Not food", icon: "questionmark", tint: Theme.Palette.warning),
             "That doesn't look like food",
             "Try another photo of the food, or fill in the post yourself.",
             "Only free, edible food can be posted.")
        case .containsPeople:
            (AnalysisStatus(label: "People in photo", icon: "person.fill.xmark", tint: Theme.Palette.danger),
             "Please avoid photographing people",
             "Take new photos with only the food in frame.",
             "These photos are discarded and won't be posted.")
        case .lowConfidence:
            (AnalysisStatus(label: "Unclear photo", icon: "eye.slash", tint: Theme.Palette.warning),
             "We couldn't tell what this is",
             "Try a closer, brighter photo of the food, or fill in the post yourself.",
             "Good light and the whole dish in frame help the most.")
        }
    }
}
