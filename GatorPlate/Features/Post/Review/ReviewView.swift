import SwiftUI

/// Post flow step 3 (design system screen 4): the editable post, pre-filled by AI or empty for manual entry.
struct ReviewView: View {
    @Bindable var viewModel: ReviewViewModel
    let onRetake: () -> Void
    let onPublished: (FoodPost) -> Void

    @State private var isPickingLocation = false
    @State private var isConfirmingRetake = false

    static let attestationText = "I confirm this food has been kept safe (hot food hot, cold food cold) and was not served from open serving for more than 2 hours."

    var body: some View {
        Form {
            header
            titleSection
            descriptionSection
            ReviewItemsSection(viewModel: viewModel)
            allergensSection
            cautionsSection
            servingsSection
            locationSection
            durationSection
            attestationSection
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { publishBar }
        .sheet(isPresented: $isPickingLocation) {
            LocationPickerSheet(selected: viewModel.draft.location,
                                userCoordinate: viewModel.userCoordinate) { viewModel.draft.location = $0 }
        }
        .confirmationDialog("Retake the photo?", isPresented: $isConfirmingRetake, titleVisibility: .visible) {
            Button("Retake and discard this post", role: .destructive, action: onRetake)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your edits will be lost.")
        }
        .sensoryFeedback(.warning, trigger: viewModel.publishState) { _, new in
            if case .failed = new { return true }
            if case .cooldown = new { return true }
            return false
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var header: some View {
        Section {
            if let photo = viewModel.photo {
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    .accessibilityLabel("Your food photo")
                Button("Retake photo") { isConfirmingRetake = true }
            }
            if viewModel.aiBaseline != nil {
                Banner(style: .info, message: "AI drafted this post. Check every field before you publish.")
                    .listRowInsets(EdgeInsets())
            } else {
                Text("Fill in what's there, where it is and how long it lasts.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var titleSection: some View {
        Section {
            TextField("FREE: food - place - until time", text: $viewModel.title, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityLabel("Title")
            if viewModel.draft.titleIsCustom {
                Button("Use suggested title") { viewModel.useSuggestedTitle() }
                    .accessibilityHint("Replaces your title with \(viewModel.suggestedTitle)")
            }
        } header: {
            ReviewSectionHeader(title: "Title", isAIValue: viewModel.isAIValue(.title))
        } footer: {
            if let issue = viewModel.warning(for: .title) {
                ReviewIssueText(issue: issue)
            } else if !viewModel.draft.titleIsCustom {
                Text("Updates as you pick the place and time. Type to write your own.")
            }
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField("What it is, how much, anything to know", text: $viewModel.description, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityLabel("Description")
        } header: {
            ReviewSectionHeader(title: "Description", isAIValue: viewModel.isAIValue(.description))
        } footer: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(viewModel.draft.description.count)/\(AppConfig.postDescriptionMaxLength)")
                    .monospacedDigit()
                    .foregroundStyle(viewModel.warning(for: .description) == nil ? Color.secondary : Theme.Palette.warning)
                    .accessibilityLabel("\(viewModel.draft.description.count) of \(AppConfig.postDescriptionMaxLength) characters")
                if let issue = viewModel.warning(for: .description) { ReviewIssueText(issue: issue) }
            }
        }
    }

    private var allergensSection: some View {
        Section {
            AllergenToggleGrid(selected: viewModel.draft.allergens, onToggle: viewModel.toggleAllergen)
            if viewModel.draft.allergens.isEmpty {
                Banner(style: .warning, message: "Allergen info unverified, ask the host.")
                    .listRowInsets(EdgeInsets())
            }
        } header: {
            ReviewSectionHeader(title: "May contain", isAIValue: viewModel.allergensMatchAI)
        } footer: {
            Text("Tap to add or remove. Allergens are never guaranteed; students should always confirm with the host.")
        }
    }

    private var cautionsSection: some View {
        Section {
            ForEach(viewModel.draft.cautions) { caution in
                HStack {
                    TextField("e.g. Contains raw onion", text: cautionBinding(for: caution.id), axis: .vertical)
                        .accessibilityLabel("Caution note")
                    Button {
                        viewModel.removeCaution(caution.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Theme.Palette.danger)
                            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove caution")
                }
            }
            if viewModel.draft.cautions.count < AppConfig.postMaxCautions {
                Button {
                    viewModel.addCaution()
                } label: {
                    Label("Add caution", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            ReviewSectionHeader(title: "Cautions",
                                isAIValue: viewModel.isAIValue(.cautions) && !viewModel.draft.cautions.isEmpty)
        }
    }

    private var servingsSection: some View {
        Section {
            if let servings = viewModel.draft.estimatedServings {
                Stepper(value: servingsBinding(default: servings), in: AppConfig.postServingsRange) {
                    Text("About \(servings) servings")
                }
                Button("Not sure", role: .destructive) { viewModel.draft.estimatedServings = nil }
            } else {
                Button {
                    viewModel.draft.estimatedServings = 10
                } label: {
                    Label("Add a servings estimate", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            ReviewSectionHeader(title: "Servings",
                                isAIValue: viewModel.isAIValue(.servings) && viewModel.draft.estimatedServings != nil)
        }
    }

    private var locationSection: some View {
        Section {
            Button {
                isPickingLocation = true
            } label: {
                HStack {
                    Label(viewModel.draft.location?.displayName ?? "Choose a building or spot",
                          systemImage: "mappin.circle.fill")
                        .foregroundStyle(viewModel.draft.location == nil ? Theme.Palette.brandPurple : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Location: \(viewModel.draft.location?.displayName ?? "not chosen")")
            .accessibilityHint("Opens the building list")
            TextField("Room / floor / entrance (required)", text: $viewModel.locationDetail)
                .accessibilityLabel("Room, floor or entrance")
        } header: {
            Text("Location")
        } footer: {
            Text("Add a room, floor or entrance, e.g. \"Room 201\" or \"step-free entrance on the east side\".")
        }
    }

    private var durationSection: some View {
        Section {
            Picker("Available for", selection: $viewModel.draft.durationMinutes) {
                ForEach(AppConfig.postDurationOptionsMinutes, id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Available for")
            TimelineView(.everyMinute) { context in
                Label("Available until \(viewModel.availableUntil(now: context.date).formatted(date: .omitted, time: .shortened))",
                      systemImage: "clock")
            }
        } header: {
            Text("How long")
        } footer: {
            Text("Posts end automatically. Food shouldn't sit out longer than this.")
        }
    }

    private var attestationSection: some View {
        Section {
            Toggle(isOn: $viewModel.draft.safetyAttested) {
                Text(Self.attestationText)
                    .font(.subheadline)
            }
        } header: {
            Text("Food safety")
        }
    }

    // MARK: Publish

    private var publishBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            switch viewModel.publishState {
            case .failed(let message):
                Banner(style: .error, message: message,
                       actions: [Banner.Action(title: "Try again") { publish() },
                                 Banner.Action(title: "OK", isPrimary: false) { viewModel.dismissPublishMessage() }])
            case .cooldown(let seconds):
                Banner(style: .warning, message: "You just posted. You can post again in \(seconds) s.",
                       actions: [Banner.Action(title: "OK", isPrimary: false) { viewModel.dismissPublishMessage() }])
            case .idle, .publishing:
                if !viewModel.blockingIssues.isEmpty {
                    missingList
                }
            }
            PrimaryButton(title: "Publish", isLoading: viewModel.publishState == .publishing) { publish() }
                .disabled(!viewModel.canPublish)
                .opacity(viewModel.canPublish ? 1 : 0.5)
                .accessibilityHint(viewModel.canPublish ? "Posts your food for everyone on campus" : "Complete the items listed above first")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.bar)
    }

    private var missingList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("To publish:")
                .font(.footnote.weight(.semibold))
            ForEach(viewModel.blockingIssues, id: \.self) { issue in
                Label(issue.message, systemImage: "circle")
                    .font(.footnote)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func publish() {
        Task {
            if let post = await viewModel.publish() { onPublished(post) }
        }
    }

    // MARK: Bindings

    private func cautionBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.draft.cautions.first { $0.id == id }?.text ?? "" },
            set: { viewModel.setCautionText($0, for: id) })
    }

    private func servingsBinding(default value: Int) -> Binding<Int> {
        Binding(
            get: { viewModel.draft.estimatedServings ?? value },
            set: { viewModel.draft.estimatedServings = $0 })
    }
}

/// All nine allergens as toggle chips. Selected chips read "May contain <allergen>".
private struct AllergenToggleGrid: View {
    let selected: Set<Allergen>
    let onToggle: (Allergen) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var minChipWidth: CGFloat = 104

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minChipWidth), spacing: Theme.Spacing.sm, alignment: .leading)],
                  alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(Allergen.allCases, id: \.self) { allergen in
                chip(allergen)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func chip(_ allergen: Allergen) -> some View {
        let isOn = selected.contains(allergen)
        return Button {
            onToggle(allergen)
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isOn ? "exclamationmark.triangle.fill" : "plus")
                    .foregroundStyle(isOn ? Theme.Palette.warning : Color.secondary)
                Text(allergen.displayName)
                    .foregroundStyle(.primary)
            }
            .font(.subheadline)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: Theme.Size.minTapTarget)
            .background(isOn ? Theme.Palette.warning.opacity(0.15) : Color.clear, in: .capsule)
            .overlay(Capsule().stroke(isOn ? Color.clear : Color.secondary.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(allergen.displayName)
        .accessibilityValue(isOn ? "May contain" : "Not listed")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("AI draft") {
    ReviewView(viewModel: ReviewViewModel(photo: nil, analysis: .sample,
                                          author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                                          posts: MockPostService(), location: MockLocationProvider()),
               onRetake: {}, onPublished: { _ in })
}

#Preview("Manual, large text") {
    ReviewView(viewModel: ReviewViewModel(photo: nil, analysis: nil,
                                          author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                                          posts: MockPostService(), location: MockLocationProvider()),
               onRetake: {}, onPublished: { _ in })
        .dynamicTypeSize(.accessibility3)
}
