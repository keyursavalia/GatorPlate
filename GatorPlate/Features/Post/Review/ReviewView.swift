import SwiftUI

/// Step 3 of the Post flow: the editable form, pre-filled from the AI draft (or empty on the manual path).
struct ReviewView: View {
    let viewModel: ReviewViewModel
    let onRetake: () -> Void
    let onClose: () -> Void

    @State private var showCalories = true
    @State private var isLocationPickerPresented = false
    @FocusState private var focusedField: PostField?

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                titleSection
                descriptionSection
                ReviewItemsSection(viewModel: viewModel, showCalories: showCalories)
                ReviewAllergensSection(viewModel: viewModel)
                ReviewCautionsSection(viewModel: viewModel)
                servingsSection
                locationSection
                durationSection
                attestationSection
            }
            .navigationTitle("Review your post")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .disabled(viewModel.isPublishing)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) { publishBar }
            .sheet(isPresented: $isLocationPickerPresented) {
                LocationPickerSheet(viewModel: viewModel)
            }
        }
        .task { await viewModel.selectNearestBuildingIfOnCampus() }
    }

    // MARK: Sections

    @ViewBuilder private var photoSection: some View {
        Section {
            if let photo = viewModel.photo {
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
                    .accessibilityLabel("Your photo")
                Button("Retake photo", action: onRetake)
                    .frame(minHeight: Theme.minTapTarget)
            } else {
                Label("No photo. Posts without a photo are fine.", systemImage: "photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if viewModel.isAIDraft {
                Text("Check everything below. AI can be wrong about ingredients, allergens and calories.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var titleSection: some View {
        Section {
            TextField("FREE: Food - Building room - until time", text: Binding(
                get: { viewModel.draft.title },
                set: { viewModel.setTitle($0) }
            ), axis: .vertical)
            .lineLimit(1...3)
            .focused($focusedField, equals: .title)
            .accessibilityLabel("Title")
            if viewModel.canOfferSuggestedTitle, let suggestion = viewModel.suggestedTitle {
                Button {
                    viewModel.applySuggestedTitle()
                } label: {
                    Label("Use \"\(suggestion)\"", systemImage: "wand.and.stars")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .accessibilityHint("Replaces the title with the suggested one")
            }
            ForEach(viewModel.issues(for: .title), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Title", showsAI: viewModel.showsAIBadge(.title))
        }
    }

    private var descriptionSection: some View {
        let count = PostText.line(viewModel.draft.description).count
        return Section {
            TextField("What food is there?", text: Binding(
                get: { viewModel.draft.description },
                set: { viewModel.setDescription($0) }
            ), axis: .vertical)
            .lineLimit(3...6)
            .focused($focusedField, equals: .description)
            .accessibilityLabel("Description")
            HStack {
                Spacer()
                Text("\(count)/\(AppConfig.maxDescriptionLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(count > 0 && count < AppConfig.recommendedDescriptionLength ? Color.warning : .secondary)
                    .accessibilityLabel("\(count) of \(AppConfig.maxDescriptionLength) characters")
            }
            ForEach(viewModel.issues(for: .description), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Description", showsAI: viewModel.showsAIBadge(.description))
        }
    }

    private var servingsSection: some View {
        Section {
            Stepper(
                value: Binding(
                    get: { viewModel.draft.servings ?? 0 },
                    set: { viewModel.setServings($0 == 0 ? nil : $0) }
                ),
                in: 0...AppConfig.maxServings
            ) {
                Text(viewModel.draft.servings.map { "About \($0) servings" } ?? "Servings: not set")
            }
            .accessibilityLabel("Servings")
            .accessibilityValue(viewModel.draft.servings.map { "\($0)" } ?? "not set")
            Toggle("Show calorie estimates here", isOn: $showCalories)
        } header: {
            ReviewSectionHeader(title: "Servings", showsAI: viewModel.showsAIBadge(.servings) && viewModel.draft.servings != nil)
        } footer: {
            Text("Calorie estimates are rough guesses. This switch only changes this screen.")
        }
    }

    private var locationSection: some View {
        Section {
            Button {
                isLocationPickerPresented = true
            } label: {
                HStack {
                    Label(
                        viewModel.draft.location?.name ?? "Choose a building",
                        systemImage: "building.2"
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Theme.minTapTarget)
            }
            .accessibilityLabel("Building")
            .accessibilityValue(viewModel.draft.location?.name ?? "Not chosen")
            .accessibilityHint("Opens the list of campus buildings")
            ForEach(viewModel.issues(for: .location), id: \.message) { IssueText(issue: $0) }

            TextField("Room, floor or entrance", text: Binding(
                get: { viewModel.draft.roomDetail },
                set: { viewModel.setRoomDetail($0) }
            ))
            .focused($focusedField, equals: .roomDetail)
            .accessibilityLabel("Room, floor or entrance")
            ForEach(viewModel.issues(for: .roomDetail), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Where is it?")
        } footer: {
            Text("For example: Room 201, 2nd floor, step-free entrance on the east side.")
        }
    }

    private var durationSection: some View {
        Section {
            Picker("Available for", selection: Binding(
                get: { viewModel.draft.durationMinutes },
                set: { viewModel.setDuration($0) }
            )) {
                ForEach(AppConfig.postDurationOptionsMinutes, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Available for")
            TimelineView(.everyMinute) { _ in
                Label(
                    "Available until \(viewModel.expiresAt().formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock"
                )
                .font(.subheadline.weight(.semibold))
            }
        } header: {
            ReviewSectionHeader(title: "How long")
        } footer: {
            Text("Food should be shared within 30 minutes where possible.")
        }
    }

    private var attestationSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.draft.attested },
                set: { viewModel.setAttested($0) }
            )) {
                Text("I confirm this food has been kept safe (hot food hot, cold food cold) and was not served from open serving for more than 2 hours.")
                    .font(.subheadline)
            }
            ForEach(viewModel.issues(for: .attestation), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Food safety")
        }
    }

    // MARK: Publish bar

    private var publishBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            if let message = viewModel.errorMessage {
                Banner(kind: .error, message: message)
            }
            if !viewModel.canPublish && !viewModel.isPublishing {
                Banner(
                    kind: .info,
                    message: "To post: " + viewModel.blockingHints.prefix(2).joined(separator: " ")
                        + (viewModel.blockingHints.count > 2 ? " (+\(viewModel.blockingHints.count - 2) more)" : "")
                )
            }
            PrimaryButton(
                title: viewModel.failedOnce ? "Try again" : "Publish",
                isLoading: viewModel.isPublishing
            ) {
                focusedField = nil
                Task { await viewModel.publish() }
            }
            .disabled(!viewModel.canPublish)
            .opacity(viewModel.canPublish || viewModel.isPublishing ? 1 : 0.4)
            .accessibilityHint(viewModel.canPublish ? "Posts your food to the campus map" : "Finish the required fields first")
        }
        .padding(Theme.Spacing.l)
        .background(.bar)
    }
}

#Preview("AI draft") {
    ReviewView(
        viewModel: ReviewViewModel(
            profile: SampleData.profile, analysis: SampleData.analysisCautious,
            photo: PreviewSupport.photo(variant: 1), posts: MockPostService(), location: MockLocationProvider(),
            cooldown: PostCooldown()
        ),
        onRetake: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Manual, no photo") {
    ReviewView(
        viewModel: ReviewViewModel(
            profile: SampleData.profile, analysis: nil, photo: nil, posts: MockPostService(),
            location: MockLocationProvider(), cooldown: PostCooldown()
        ),
        onRetake: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}
