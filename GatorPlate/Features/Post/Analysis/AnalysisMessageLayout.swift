import SwiftUI

/// Why analysis stopped, as the pill on the photos says it.
struct AnalysisStatus {
    let label: String
    let icon: String
    let tint: Color
}

/// Shared layout for the analysis outcomes that aren't a draft (AI failed, photo rejected), built like
/// `AnalyzingScreen` so the flow reads as one: the photos with a status pill, a centered title and message, a note
/// card, and the actions pinned at the bottom. Without photos, an icon in a tinted circle stands in.
struct AnalysisMessageLayout<Actions: View>: View {
    let photos: [CapturedPhoto]
    var obscuresPhotos = false
    let status: AnalysisStatus
    let title: String
    let message: String
    let note: String
    @ViewBuilder let actions: Actions

    @ScaledMetric(relativeTo: .largeTitle) private var circle: CGFloat = 88

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header
                    .padding(.top, Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                Label {
                    Text(note)
                } icon: {
                    Image(systemName: "info.circle").foregroundStyle(Theme.Palette.brandPurple)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.brandPurple.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.field))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.md) { actions }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .background(.background)
        }
        .background(.background)
    }

    @ViewBuilder
    private var header: some View {
        if photos.isEmpty {
            Image(systemName: status.icon)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(status.tint)
                .frame(width: circle, height: circle)
                .background(status.tint.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
        } else {
            let count = min(photos.count, 4)
            AnalysisPhotoStack(photos: photos, obscured: obscuresPhotos,
                               accessibilityLabel: "\(count == 1 ? "Your food photo" : "Your \(count) photos"). "
                                   + status.label) {
                AnalysisStatusPill(title: status.label, systemImage: status.icon, tint: status.tint)
            }
        }
    }
}
