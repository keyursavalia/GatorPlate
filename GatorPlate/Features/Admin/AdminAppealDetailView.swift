import SwiftUI

/// One appeal: the message, the pause, the poster's removals, and Uphold / Deny (with a note the poster sees).
struct AdminAppealDetailView: View {
    let appeal: AdminAppeal
    let viewModel: AdminViewModel

    @State private var moderation: AdminModeration?
    @State private var clearStrikes = true
    @State private var note = ""
    @State private var decision: Bool?

    var body: some View {
        List {
            Section("Appeal") {
                Text(appeal.message)
                LabeledContent("Paused until", value: appeal.bannedUntil.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Sent", value: appeal.createdAt.formatted(.relative(presentation: .named)))
                if let resolution = appeal.resolution {
                    LabeledContent("Decision", value: resolution == .upheld ? "Upheld" : "Denied")
                    if let note = appeal.resolutionNote { Text(note).foregroundStyle(.secondary) }
                }
            }
            if let moderation, !moderation.removals.isEmpty {
                Section("Removed posts") {
                    ForEach(moderation.removals) { removal in
                        LabeledContent(removal.category,
                                       value: removal.removedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            if appeal.isOpen {
                Section {
                    TextField("Note to the poster (optional, 200 max)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: note) { _, new in if new.count > 200 { note = String(new.prefix(200)) } }
                    Toggle("Clear strikes if upheld", isOn: $clearStrikes)
                    Button("Uphold: lift the pause") { decision = true }
                    Button("Deny: keep the pause", role: .destructive) { decision = false }
                } footer: {
                    Text("The poster gets a push with the decision, and the note shows in the app.")
                }
                .disabled(viewModel.runningAction != nil)
            } else {
                Section {
                    Button("Lift the pause anyway") {
                        Task { await viewModel.run(.liftBan(uid: appeal.uid, clearStrikes: clearStrikes)) }
                    }
                    .disabled(viewModel.runningAction != nil)
                }
            }
        }
        .navigationTitle("Appeal")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.runningAction != nil { ProgressView().controlSize(.large) } }
        .task { moderation = try? await viewModel.service.moderation(uid: appeal.uid) }
        .alert(decision == true ? "Uphold this appeal?" : "Deny this appeal?",
               isPresented: Binding(get: { decision != nil }, set: { if !$0 { decision = nil } })) {
            Button(decision == true ? "Uphold" : "Deny", role: decision == true ? nil : .destructive) {
                let upheld = decision == true
                let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    await viewModel.run(.resolveAppeal(uid: appeal.uid, upheld: upheld,
                                                       clearStrikes: upheld && clearStrikes,
                                                       note: trimmed.isEmpty ? nil : trimmed))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        AdminAppealDetailView(appeal: .sample, viewModel: AdminViewModel(service: MockAdminService()))
    }
}
