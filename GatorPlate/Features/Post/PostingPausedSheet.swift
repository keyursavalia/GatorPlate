import SwiftUI

/// Shown instead of the post flow during a posting ban: why posting is paused, until when, and an appeal (one per
/// ban) that the admin reviews. Browsing, alerts and reporting keep working.
struct PostingPausedSheet: View {
    let ban: PostingBan
    let onAppeal: (String) async throws -> Void

    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var hasAppealed: Bool
    @FocusState private var isMessageFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(ban: PostingBan, onAppeal: @escaping (String) async throws -> Void) {
        self.ban = ban
        self.onAppeal = onAppeal
        _hasAppealed = State(initialValue: ban.hasAppealed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    if hasAppealed {
                        appealSent
                    } else {
                        appealForm
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Posting paused")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.warning)
                .accessibilityHidden(true)
            Text("You can post again \(ban.bannedUntil.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Several of your posts were removed after reports, so posting is paused until \(ban.bannedUntil.formatted(date: .long, time: .shortened)). You can still browse, get alerts, report and block.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appealForm: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Think this is a mistake?")
                .font(.headline)
            TextField("Tell us what happened. We read every appeal.", text: $message, axis: .vertical)
                .lineLimit(4...8)
                .focused($isMessageFocused)
                .padding(Theme.Spacing.md)
                .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.field))
                .onChange(of: message) { _, new in
                    if new.count > AppConfig.appealMaxLength { message = String(new.prefix(AppConfig.appealMaxLength)) }
                }
                .accessibilityLabel("Your appeal")
            HStack {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.danger)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text("\(trimmed.count)/\(AppConfig.appealMaxLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("\(trimmed.count) of \(AppConfig.appealMaxLength) characters")
            }
            PrimaryButton(title: "Send appeal", isLoading: isSending, action: send)
                .disabled(trimmed.count < AppConfig.appealMinLength || isSending)
                .padding(.top, Theme.Spacing.sm)
            Text("One appeal per pause. If it's upheld, posting comes back right away.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appealSent: some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Appeal sent").font(.headline)
                Text("We'll review it. If it's upheld, you can post again right away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Palette.success)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var trimmed: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        isSending = true
        errorMessage = nil
        Task {
            defer { isSending = false }
            do {
                try await onAppeal(trimmed)
                isMessageFocused = false
                withAnimation { hasAppealed = true }
            } catch {
                errorMessage = ((error as? AppError) ?? .unknown).userMessage
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PostingPausedSheet(ban: PostingBan(bannedUntil: .now.addingTimeInterval(5 * 86_400), hasAppealed: false)) { _ in }
    }
}

#Preview("Appealed") {
    PostingPausedSheet(ban: PostingBan(bannedUntil: .now.addingTimeInterval(86_400), hasAppealed: true)) { _ in }
}
