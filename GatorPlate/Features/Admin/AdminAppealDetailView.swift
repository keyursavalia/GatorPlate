import SwiftUI

/// One appeal: the message, the pause, the poster's removals, and Uphold / Deny (with a note the poster sees), or
/// Lift the pause anyway once decided. Follows the live appeal and, like a report, goes back to the list after an
/// action succeeds ("Done" shows there); a failed action shows "Didn't work" here.
struct AdminAppealDetailView: View {
    let viewModel: AdminViewModel

    @State private var moderation: AdminModeration?
    @State private var clearStrikes = true
    @State private var note = ""
    @State private var decision: Bool?
    @State private var isConfirmingLift = false
    @Environment(\.dismiss) private var dismiss

    private let initialAppeal: AdminAppeal
    private var appeal: AdminAppeal { viewModel.appeal(id: initialAppeal.id) ?? initialAppeal }

    init(appeal: AdminAppeal, viewModel: AdminViewModel) {
        initialAppeal = appeal
        self.viewModel = viewModel
    }

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
                    Toggle("Clear strikes", isOn: $clearStrikes)
                    Button("Lift the pause anyway") { isConfirmingLift = true }
                        .disabled(viewModel.runningAction != nil)
                } footer: {
                    Text("Ends the posting pause now, whatever the decision was.")
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
                run(.resolveAppeal(uid: appeal.uid, upheld: upheld, clearStrikes: upheld && clearStrikes,
                                   note: trimmed.isEmpty ? nil : trimmed))
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Lift the pause?", isPresented: $isConfirmingLift) {
            Button("Lift") { run(.liftBan(uid: appeal.uid, clearStrikes: clearStrikes)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(clearStrikes ? "They can post again right away, and their strikes are cleared."
                              : "They can post again right away. Their strikes stay.")
        }
        .adminActionFailureAlert(viewModel)
    }

    private func run(_ action: AdminActionRequest) {
        Task {
            if await viewModel.run(action) { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        AdminAppealDetailView(appeal: .sample, viewModel: AdminViewModel(service: MockAdminService()))
    }
}
