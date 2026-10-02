import SwiftUI

/// Pick a reason, then send. No free text, so nothing personal can be typed in.
struct ReportSheet: View {
    let onSelect: (ReportReason) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ReportReason.allCases) { reason in
                Button {
                    onSelect(reason)
                    dismiss()
                } label: {
                    Text(reason.rawValue)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .accessibilityHint("Reports this post as \(reason.rawValue.lowercased())")
            }
            .navigationTitle("Report this post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ReportSheet { _ in }
        .environment(\.appEnvironment, .mock)
}
