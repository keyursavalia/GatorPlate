import SwiftUI

/// Sheet content for a selected pin. Small detent: title, time, directions. Medium: everything.
struct PostBottomCard: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @AppStorage(AppConfig.showCalorieEstimatesKey) private var showCalories = true
    @State private var showReportSheet = false
    @State private var confirmGone = false
    @State private var mapsFailed = false

    private var actions: PostActionsModel { viewModel.actions }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                PostCardDirections(
                    state: viewModel.routeState,
                    onDirections: viewModel.startDirections,
                    onEndRoute: viewModel.endRoute,
                    onOpenInMaps: openInMaps
                )

                if mapsFailed {
                    Banner(kind: .error, message: "Apple Maps couldn't be opened.")
                }

                noticeBanner

                Divider()

                details

                Divider()

                postActions
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showReportSheet) {
            ReportSheet { reason in
                Task { await actions.report(post, reason: reason) }
            }
        }
        .confirmationDialog("Mark this food as gone?", isPresented: $confirmGone, titleVisibility: .visible) {
            Button("Mark as gone", role: .destructive) {
                Task { await actions.markGone(post) }
            }
        } message: {
            Text("It disappears for everyone right away.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            if post.hasPhoto {
                PostPhotoView(postID: post.id, hasPhoto: true, size: 88)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(post.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(post.orgName ?? post.authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.s) { pills }
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) { pills }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var pills: some View {
        TimeRemainingPill(expiresAt: post.expiresAt)
        DietaryBadge(dietary: post.overallDietary)
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if !post.allergenWarnings.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("May contain")
                        .font(.subheadline.weight(.semibold))
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.s) { chips }
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) { chips }
                    }
                }
            }

            if showCalories, let calories = calorieText {
                Text(calories)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !post.cautions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(post.cautions, id: \.self) { caution in
                        Label(caution, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(Color.warning)
                    }
                }
            }

            Label(locationText, systemImage: "mappin.and.ellipse")
                .font(.subheadline)

            Text(post.description)
                .font(.body)

            Text("Double-check allergens with the host.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(post.allergenWarnings, id: \.self) { allergen in
            AllergenChip(allergen: allergen)
        }
    }

    private var locationText: String {
        var parts = [post.locationName]
        if let detail = post.locationDetail { parts.append(detail) }
        if let distance = viewModel.location.distanceText(to: post) { parts.append("\(distance) away") }
        return parts.joined(separator: ", ")
    }

    private var calorieText: String? {
        let ranges = post.items.compactMap(\.calories)
        guard !ranges.isEmpty else { return nil }
        let low = ranges.reduce(0) { $0 + $1.low }
        let high = ranges.reduce(0) { $0 + $1.high }
        return "~\(low)-\(high) kcal per serving (estimate)"
    }

    // MARK: Mark as gone and Report

    @ViewBuilder private var noticeBanner: some View {
        switch actions.notice {
        case .reported:
            Banner(kind: .info, message: "Thanks, we'll review it.")
        case .failed(let message):
            Banner(kind: .error, message: message)
        case nil:
            EmptyView()
        }
    }

    private var postActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // Only the author sees this (the Firestore rules enforce it too).
            if actions.canMarkGone(post) {
                Button(role: .destructive) {
                    confirmGone = true
                } label: {
                    Label("Mark as gone", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.bordered)
                .disabled(actions.isWorking)
                .accessibilityHint("Removes this post for everyone")
            }

            Button {
                showReportSheet = true
            } label: {
                Label(actions.hasReported(post) ? "Reported" : "Report", systemImage: "flag")
                    .frame(minHeight: Theme.minTapTarget)
            }
            .disabled(actions.hasReported(post) || actions.isWorking)
            .accessibilityHint("Tell us if this post is not food, unsafe, or spam")
        }
    }

    private func openInMaps() {
        mapsFailed = !viewModel.openInAppleMaps()
    }
}

#Preview("Card") {
    let model = MapPreviews.mapViewModel()
    return PostBottomCard(post: SampleData.mapPosts()[0], viewModel: model)
        .environment(\.appEnvironment, .mock)
}

#Preview("Card, author, large text") {
    let model = MapPreviews.mapViewModel(userID: SampleData.profile.uid)
    var post = SampleData.mapPosts()[0]
    post.authorUid = SampleData.profile.uid
    return PostBottomCard(post: post, viewModel: model)
        .dynamicTypeSize(.accessibility3)
        .environment(\.appEnvironment, .mock)
}
