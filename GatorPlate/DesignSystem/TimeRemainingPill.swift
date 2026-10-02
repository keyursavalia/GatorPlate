import SwiftUI

/// "24 min left"; orange under 10 minutes, red "Ending soon" under 5. Icon and text, never color alone.
struct TimeRemainingPill: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let state = Display(secondsLeft: expiresAt.timeIntervalSince(context.date))
            Label(state.text, systemImage: state.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.tint)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xs + 2)
                .background(state.tint.opacity(0.15), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.spokenText)
        }
    }

    struct Display: Equatable {
        let secondsLeft: TimeInterval

        var minutesLeft: Int { max(0, Int((secondsLeft / 60).rounded(.up))) }
        var isExpired: Bool { secondsLeft <= 0 }
        /// Thresholds use the real seconds, so "under 5 minutes" is true from 4:59 down, not only once the rounded-up minute count drops.
        var isEndingSoon: Bool { !isExpired && secondsLeft < 5 * 60 }
        var isWarning: Bool { !isExpired && secondsLeft < 10 * 60 }

        var text: String {
            if isExpired { return "Expired" }
            if isEndingSoon { return "Ending soon" }
            return "\(minutesLeft) min left"
        }

        var spokenText: String {
            if isExpired { return "Expired" }
            if isEndingSoon { return "Ending soon, \(minutesLeft) minutes left" }
            return "\(minutesLeft) minutes left"
        }

        var systemImage: String { isWarning || isExpired ? "clock.badge.exclamationmark" : "clock" }

        var tint: Color {
            if isExpired || isEndingSoon { return .danger }
            return isWarning ? .warning : .secondary
        }
    }
}

#Preview("Time states") {
    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
        TimeRemainingPill(expiresAt: Date().addingTimeInterval(24 * 60))
        TimeRemainingPill(expiresAt: Date().addingTimeInterval(8 * 60))
        TimeRemainingPill(expiresAt: Date().addingTimeInterval(3 * 60))
        TimeRemainingPill(expiresAt: Date().addingTimeInterval(-10))
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
