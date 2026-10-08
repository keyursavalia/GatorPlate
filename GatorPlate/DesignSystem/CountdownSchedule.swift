import SwiftUI

/// Timeline entries exactly when a countdown's whole-minute value changes (minutes are rounded up),
/// instead of on wall-clock minute boundaries, which can lag by up to 59 seconds.
struct CountdownSchedule: TimelineSchedule {
    let expiresAt: Date

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        Self.dates(from: startDate, until: expiresAt)
    }

    /// `startDate`, then every moment the rounded-up minutes drop, ending at `expiresAt`.
    nonisolated static func dates(from startDate: Date, until expiresAt: Date) -> [Date] {
        let remaining = expiresAt.timeIntervalSince(startDate)
        guard remaining > 0 else { return [startDate] }
        let minutesLeft = Int((remaining / 60).rounded(.up))
        var dates = [startDate]
        for minutes in stride(from: minutesLeft - 1, through: 0, by: -1) {
            let date = expiresAt.addingTimeInterval(-Double(minutes) * 60)
            if date > startDate { dates.append(date) }
        }
        return dates
    }
}
