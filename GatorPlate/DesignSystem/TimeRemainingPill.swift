import SwiftUI

/// "24 min left". Orange under 10 minutes, red "Ending soon" under 5. Refreshes each time the minute count drops.
struct TimeRemainingPill: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(CountdownSchedule(expiresAt: expiresAt)) { context in
            let state = Urgency(minutesLeft: Self.minutesLeft(until: expiresAt, now: context.date))
            Label(state.text, systemImage: state.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state.tint)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(state.tint.opacity(0.12), in: .capsule)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.spokenText)
        }
    }

    /// Whole minutes left, rounded up so "0 min" never shows while the post is live.
    static func minutesLeft(until expiresAt: Date, now: Date = .now) -> Int {
        max(0, Int((expiresAt.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private struct Urgency {
        let minutesLeft: Int

        var text: String {
            switch minutesLeft {
            case 0: "Ended"
            case ..<5: "Ending soon"
            default: "\(minutesLeft) min left"
            }
        }

        var spokenText: String {
            switch minutesLeft {
            case 0: "Ended"
            case ..<5: "Ending soon, \(minutesLeft) minutes left"
            default: "\(minutesLeft) minutes left"
            }
        }

        var icon: String {
            minutesLeft < 10 ? "exclamationmark.circle.fill" : "clock"
        }

        var tint: Color {
            switch minutesLeft {
            case ..<5: Theme.Palette.danger
            case ..<10: Theme.Palette.warning
            default: .secondary
            }
        }
    }
}

#Preview {
    VStack {
        TimeRemainingPill(expiresAt: .now.addingTimeInterval(24 * 60))
        TimeRemainingPill(expiresAt: .now.addingTimeInterval(8 * 60))
        TimeRemainingPill(expiresAt: .now.addingTimeInterval(3 * 60))
    }
}
