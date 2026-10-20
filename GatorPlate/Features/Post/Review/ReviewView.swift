import SwiftUI

/// Post flow step 3: the composer, a grouped list like Settings. Photos (whole, never cropped) -> title ->
/// what's there -> description -> may contain -> heads up -> where & when -> the safety confirmation, with a
/// sticky Publish bar. Pre-filled by AI (so most posts are a quick check and Publish) or empty for manual entry.
struct ReviewView: View {
    @Bindable var viewModel: ReviewViewModel
    let onClose: () -> Void
    let onEditPhotos: () -> Void
    let onPublished: (PublishResult) -> Void

    @FocusState private var focus: ReviewFocus?
    @State private var isPickingLocation = false
    @State private var isPreviewing = false
    @State private var highlighted: PostDraftValidator.Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let attestationText = "I confirm this food has been kept safe (hot food hot, cold food cold) and was not served from open serving for more than 2 hours."

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    photosSection
                    notesSection
                    ReviewWhatSection(viewModel: viewModel, focus: $focus, highlighted: highlighted)
                    ReviewSafetySection(viewModel: viewModel, highlighted: highlighted)
                    ReviewWhereSection(viewModel: viewModel, focus: $focus, highlighted: highlighted) {
                        isPickingLocation = true
                    }
                    attestation
                }
                .listSectionSpacing(.compact)
                .environment(\.defaultMinListRowHeight, 48)
                .environment(\.listAccent, Theme.Palette.accent)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    ReviewPublishBar(viewModel: viewModel, onShowIssue: { showFirstIssue(proxy) }, onPublish: publish)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .accessibilityHint("Cancels the post")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Preview") { isPreviewing = true }
                        .accessibilityHint("Shows the post as students will see it")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focus != .room {
                        Button("Next") { moveFocus() }
                    }
                    Button("Done") { focus = nil }
                }
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

    // MARK: Photos and notes

    @ViewBuilder
    private var photosSection: some View {
        if viewModel.photos.isEmpty {
            Section {
                Button(action: onEditPhotos) {
                    ListRow(title: "Add photos", systemImage: "camera", showsDisclosure: true)
                }
                .accessibilityHint("Opens the camera to add up to \(AppConfig.postMaxPhotos) photos")
            }
        } else {
            Section {
                PhotoCarousel(sources: viewModel.photos.map(PostPhotoSource.captured), images: nil)
                    .overlay(alignment: .bottomLeading) {
                        Button(action: onEditPhotos) {
                            Label("Edit", systemImage: "photo.stack")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.Spacing.md)
                                .frame(minHeight: 32)
                                // Solid: pills over photos never use glass.
                                .background(.black.opacity(0.65), in: .capsule)
                                .padding(Theme.Spacing.sm)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit photos")
                        .accessibilityHint("Add, remove or reorder photos")
                    }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if viewModel.aiBaseline != nil || viewModel.removedPhotosNotice != nil || viewModel.showsAIDisabledNote {
            Section {
                if viewModel.showsAIDisabledNote {
                    NoteRow(text: "AI drafting is off right now. Fill in the details yourself.", systemImage: "info.circle")
                }
                if viewModel.aiBaseline != nil {
                    NoteRow(text: "AI drafted this post. Give it a quick check, then publish.", systemImage: "sparkles")
                }
                if let notice = viewModel.removedPhotosNotice {
                    NoteRow(text: notice, systemImage: "person.crop.square.badge.camera")
                }
            }
        }
    }

    // MARK: Attestation

    private var attestation: some View {
        Section {
            Toggle(isOn: $viewModel.draft.safetyAttested) {
                Text(Self.attestationText)
                    .font(.subheadline)
            }
            .tint(Theme.Palette.brandPurple)
            .listRowBackground(rowHighlight(highlighted == .attestation))
            .id(PostDraftValidator.Field.attestation)
        } footer: {
            Text("Required to publish.")
        }
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
            proxy.scrollTo(field, anchor: .center)
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

/// Fields the keyboard toolbar moves through, in order.
enum ReviewFocus: Hashable {
    case title, description, room
}

/// Red tint on a row that "N things left" scrolled to; nil keeps the normal row background.
func rowHighlight(_ isOn: Bool) -> Color? {
    isOn ? Theme.Palette.danger.opacity(0.15) : nil
}

/// Section header text with an AI badge while the section still holds the AI's values.
struct ReviewSectionHeader: View {
    let title: String
    var isAI = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
            if isAI { AIBadge().textCase(nil) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline validation message: blocking issues in red, warnings in orange, always with an icon.
struct ReviewIssueText: View {
    let issue: PostDraftValidator.Issue

    var body: some View {
        Label(issue.message, systemImage: issue.isBlocking ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(issue.isBlocking ? Theme.Palette.danger : Theme.Palette.warning)
            .accessibilityLabel("\(issue.isBlocking ? "Required" : "Tip"): \(issue.message)")
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
