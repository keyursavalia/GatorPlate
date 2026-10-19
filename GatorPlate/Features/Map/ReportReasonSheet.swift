import SwiftUI

/// Report reasons: Not food / Unsafe / Spam / Other (with an optional note). The poster never sees who reported.
struct ReportReasonSheet: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @State private var reason = ReportReason.notFood
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    /// Room for "Other: " within `AppConfig.postReportReasonMaxLength`.
    private static let noteMaxLength = AppConfig.postReportReasonMaxLength - 10

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.label).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("What's wrong with this post?")
                } footer: {
                    Text("Reports are private. The poster isn't told who reported.")
                }

                if reason == .other {
                    Section("Details (optional)") {
                        TextField("What happened?", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .onChange(of: note) { _, new in
                                if new.count > Self.noteMaxLength { note = String(new.prefix(Self.noteMaxLength)) }
                            }
                    }
                }

                if case .failed(let message) = viewModel.reportStatus {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Palette.danger)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Report post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.reportStatus == .working {
                        ProgressView()
                    } else {
                        Button("Send") { send() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() {
        Task {
            if await viewModel.report(post, reason: reason, note: note) {
                dismiss()
            }
        }
    }
}
