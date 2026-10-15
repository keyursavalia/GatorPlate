import SwiftUI

/// Post flow step 3 (design system screen 4): the composer. Visual order: photos -> what -> is it safe ->
/// where and when -> attestation, with a sticky Publish bar. Pre-filled by AI or empty for manual entry.
struct ReviewView: View {
    @Bindable var viewModel: ReviewViewModel
    let onClose: () -> Void
    let onEditPhotos: () -> Void
    let onPublished: (PublishResult) -> Void

    @FocusState private var focus: ReviewFocus?
    @State private var isPickingLocation = false
    @State private var isPreviewing = false
    @State private var showsAIStrip = true
    @State private var highlighted: PostDraftValidator.Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let attestationText = "I confirm this food has been kept safe (hot food hot, cold food cold) and was not served from open serving for more than 2 hours."

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        hero
                        notices
                        ReviewWhatSection(viewModel: viewModel, focus: $focus, highlighted: highlighted)
                        ReviewSafetySection(viewModel: viewModel)
                        ReviewWhereSection(viewModel: viewModel, focus: $focus, highlighted: highlighted) {
                            isPickingLocation = true
                        }
                        attestation.id(PostDraftValidator.Field.attestation)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    ReviewPublishBar(viewModel: viewModel, onShowIssue: { showFirstIssue(proxy) }, onPublish: publish)
                }
            }
        }
        .background(.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                if focus != .room {
                    Button("Next") { moveFocus() }
                }
                Button("Done") { focus = nil }
            }
        }
        .onSubmit(moveFocus)
        .sheet(isPresented: $isPickingLocation) {
            LocationPickerSheet(selected: viewModel.draft.location,
                                userCoordinate: viewModel.userCoordinate) { viewModel.draft.location = $0 }
        }
        .sheet(isPresented: $isPreviewing) {
            ReviewPreviewSheet(post: viewModel.previewPost,
                               photoSources: viewModel.photos.map(PostPhotoSource.captured))
        }
        .sensoryFeedback(.warning, trigger: viewModel.publishState) { _, new in
            if case .failed = new { return true }
            if case .cooldown = new { return true }
            return false
        }
    }

    // MARK: Header

    private var topBar: some View {
        HStack {
            GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close", accessibilityHint: "Cancels the post",
                            action: onClose)
            Spacer()
            Text("Review post")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Preview") { isPreviewing = true }
                .buttonStyle(.glass)
                .frame(minHeight: Theme.Size.minTapTarget)
                .accessibilityHint("Shows the post as students will see it")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var hero: some View {
        if viewModel.photos.isEmpty {
            Button(action: onEditPhotos) {
                Label("Add photos", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(Theme.Palette.brandPurple.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.photo))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the camera to add up to \(AppConfig.postMaxPhotos) photos")
        } else {
            VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
                PhotoCarousel(sources: viewModel.photos.map(PostPhotoSource.captured), images: nil)
                Button("Edit photos", systemImage: "photo.stack", action: onEditPhotos)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .accessibilityHint("Add, remove or reorder photos")
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let notice = viewModel.removedPhotosNotice {
            dismissibleStrip(notice, systemImage: "person.crop.square.badge.camera") {
                viewModel.removedPhotosNotice = nil
            }
        }
        if viewModel.aiBaseline != nil, showsAIStrip {
            dismissibleStrip("AI drafted this post. Check each section.", systemImage: "sparkles") {
                showsAIStrip = false
            }
        } else if viewModel.aiBaseline == nil {
            Text("Fill in what's there, where it is and how long it lasts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func dismissibleStrip(_ text: String, systemImage: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            Text(text).font(.subheadline)
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.Palette.brandPurple.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.field))
    }

    // MARK: Attestation

    private var attestation: some View {
        Button {
            viewModel.draft.safetyAttested.toggle()
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: viewModel.draft.safetyAttested ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(viewModel.draft.safetyAttested ? Theme.Palette.brandPurple : Color.secondary)
                    .accessibilityHidden(true)
                Text(Self.attestationText)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .reviewHighlight(highlighted == .attestation)
        .accessibilityLabel(Self.attestationText)
        .accessibilityAddTraits(viewModel.draft.safetyAttested ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(viewModel.draft.safetyAttested ? "Checked" : "Not checked")
    }

    // MARK: Actions

    private func moveFocus() {
        focus = switch focus {
        case .title: .description
        case .description: .room
        case .room, nil: nil
        }
    }

    private func showFirstIssue(_ proxy: ScrollViewProxy) {
        guard let field = viewModel.firstBlockingField else { return }
        withAnimation(reduceMotion ? nil : .easeInOut) {
            proxy.scrollTo(field, anchor: .top)
            highlighted = field
        }
        if let issue = viewModel.blockingIssues.first {
            AccessibilityNotification.Announcement(issue.message).post()
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : .easeOut) { highlighted = nil }
        }
    }

    private func publish() {
        focus = nil
        Task {
            if let result = await viewModel.publish() { onPublished(result) }
        }
    }
}

#Preview("AI draft") {
    ReviewView(viewModel: ReviewViewModel(photos: [], analysis: .sample,
                                          author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                                          posts: MockPostService(), location: MockLocationProvider()),
               onClose: {}, onEditPhotos: {}, onPublished: { _ in })
}

#Preview("Manual, AX5") {
    ReviewView(viewModel: ReviewViewModel(photos: [], analysis: nil,
                                          author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                                          posts: MockPostService(), location: MockLocationProvider()),
               onClose: {}, onEditPhotos: {}, onPublished: { _ in })
        .dynamicTypeSize(.accessibility5)
}
