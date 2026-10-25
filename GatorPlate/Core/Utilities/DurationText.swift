import Foundation

/// Post lengths and time left in whole minutes, shared by the countdown pill and the Review duration picker.
nonisolated enum DurationText {
    /// "45 min", "1 h", "2 h 15 min".
    static func short(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(rest) min"
        }
    }

    /// "45 minutes", "1 hour", "2 hours 15 minutes" for VoiceOver.
    static func spoken(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minuteText = rest == 1 ? "1 minute" : "\(rest) minutes"
        switch (hours, rest) {
        case (0, _): return minuteText
        case (_, 0): return hourText
        default: return "\(hourText) \(minuteText)"
        }
    }
}
