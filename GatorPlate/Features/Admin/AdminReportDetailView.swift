import SwiftUI

/// One report: the post as reported, the reason, the AI verdict, the poster's record, and Remove post.
struct AdminReportDetailView: View {
    let report: AdminReport
    let viewModel: AdminViewModel

    @State private var moderation: AdminModeration?
    @State private var isConfirmingRemoval = false
    @State private var withStrike = true

    var body: some View {
        List {
            Section("Report") {
                LabeledContent("Category", value: report.category.label)
                LabeledContent("Reported", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let reason = report.reason {
                    Text(reason).accessibilityLabel("Reason: \(reason)")
                }
                if let verdict = report.aiVerdict {
                    LabeledContent("AI check", value: verdict + (report.aiConcern.map { " · \($0)" } ?? ""))
                    if let rationale = report.aiRationale, !rationale.isEmpty {
                        Text(rationale).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if let snapshot = report.snapshot {
                Section("Post") {
                    Text(snapshot.title).font(.headline)
                    if !snapshot.description.isEmpty { Text(snapshot.description) }
                    LabeledContent("Place", value: snapshot.locationName)
                    LabeledContent("Poster", value: snapshot.posterName)
                }
            }
            if let moderation {
                Section("Poster's record") {
                    LabeledContent("Removals (30 days)", value: String(moderation.removals.count))
                    LabeledContent("Blocked by", value: String(moderation.blockedByCount))
                    if let until = moderation.bannedUntil, until > .now {
                        LabeledContent("Posting paused until",
                                       value: until.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            Section {
                Toggle("Count as a strike", isOn: $withStrike)
                Button("Remove post", role: .destructive) { isConfirmingRemoval = true }
                    .disabled(viewModel.runningAction != nil)
            } footer: {
                Text("Removes the post if it's still up. A strike counts toward a posting pause. "
                     + "The poster gets an in-app notice, not a push.")
            }
        }
        .navigationTitle(report.category.label)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.runningAction != nil { ProgressView().controlSize(.large) } }
        .task {
            guard let uid = report.snapshot?.authorUid, !uid.isEmpty else { return }
            moderation = try? await viewModel.service.moderation(uid: uid)
        }
        .alert("Remove this post?", isPresented: $isConfirmingRemoval) {
            Button("Remove", role: .destructive) {
                Task { await viewModel.run(.removePost(postId: report.postId, strike: withStrike)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(withStrike ? "It disappears for everyone and counts as a strike." : "It disappears for everyone.")
        }
    }
}

#Preview {
    NavigationStack {
        AdminReportDetailView(report: .sample, viewModel: AdminViewModel(service: MockAdminService()))
    }
}
