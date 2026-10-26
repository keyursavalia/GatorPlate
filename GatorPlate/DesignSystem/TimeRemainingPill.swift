import SwiftUI

/// "24 min left" ("2 h 15 min left" for long posts). Orange under 10 minutes, red "Ending soon" under 5. Refreshes each time the minute count drops.
struct TimeRemainingPill: View {
    let expiresAt: Date
    /// Over a photo: an opaque backing (glass and tints never go over photos).
    var isSolid = false
    /// Plain text in a row (no capsule), e.g. the Feed.
    var isInline = false

    var body: some View {
        TimelineView(CountdownSchedule(expiresAt: expiresAt)) { context in
            let state = Urgency(minutesLeft: Self.minutesLeft(until: expiresAt, now: context.date))
            Group {
                if isInline {
                    Label(state.text, systemImage: state.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(state.inlineTint)
                } else {
                    Label(state.text, systemImage: state.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(state.tint.opacity(isSolid ? 0 : 0.12), in: .capsule)
                        .background(isSolid ? AnyShapeStyle(.background) : AnyShapeStyle(.clear), in: .capsule)
                }
            }
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
            default: "\(DurationText.short(minutes: minutesLeft)) left"
            }
        }

        var spokenText: String {
            switch minutesLeft {
            case 0: "Ended"
            case ..<5: "Ending soon, \(minutesLeft) minutes left"
            default: "\(DurationText.spoken(minutes: minutesLeft)) left"
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

        /// Brand purple while there's plenty of time, so the time stands out in a row of gray text.
        var inlineTint: Color {
            minutesLeft < 10 ? tint : Theme.Palette.brandPurple
        }
    }
}
