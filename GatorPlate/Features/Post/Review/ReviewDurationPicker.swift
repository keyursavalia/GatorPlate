import SwiftUI

/// "Available for" in Where & when: the one-tap lengths and "+ Custom" in one segmented row (a menu at accessibility
/// sizes). Custom adds a "Custom length" row that opens hours and minutes wheels, like picking a time in Calendar:
/// 15 min to 5 h in 5-minute steps (`AppConfig.postDurationRangeMinutes`; `firestore.rules` caps posts at 5 h too).
/// Each row is its own list row.
struct ReviewDurationPicker: View {
    @Binding var minutes: Int
    @Binding var isCustom: Bool
    var isHighlighted = false

    @State private var showsWheels = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    private enum Choice: Hashable {
        case preset(Int)
        case custom
    }

    var body: some View {
        Group {
            choices
                .id(PostDraftValidator.Field.duration)
            if isCustom {
                customRow
                if showsWheels {
                    wheels
                        .transition(.opacity)
                }
            }
        }
        .listRowBackground(rowHighlight(isHighlighted))
    }

    // MARK: Presets and Custom

    @ViewBuilder
    private var choices: some View {
        let picker = Picker("Available for", selection: choice) {
            ForEach(AppConfig.postDurationOptionsMinutes, id: \.self) { option in
                Text(DurationText.short(minutes: option))
                    .accessibilityLabel(DurationText.spoken(minutes: option))
                    .tag(Choice.preset(option))
            }
            Text(isCustom ? "Custom" : "+ Custom")
                .accessibilityLabel("Custom length")
                .tag(Choice.custom)
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private var choice: Binding<Choice> {
        Binding(
            get: { isCustom ? .custom : .preset(minutes) },
            set: { new in
                withAnimation(.snappy) {
                    switch new {
                    case .preset(let option):
                        isCustom = false
                        showsWheels = false
                        minutes = option
                    case .custom:
                        guard !isCustom else { return }
                        isCustom = true
                        showsWheels = true
                        minutes = AppConfig.defaultCustomPostDurationMinutes
                    }
                }
            })
    }

    /// "Custom length   1 h 30 min": tapping shows or hides the wheels.
    private var customRow: some View {
        Button {
            withAnimation(.snappy) { showsWheels.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                Text("Custom length")
                    .foregroundStyle(Color.primary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(DurationText.short(minutes: minutes))
                    .monospacedDigit()
                    .foregroundStyle(showsWheels ? Theme.Palette.accent : Color.secondary)
                    .contentTransition(.numericText())
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Custom length, \(DurationText.spoken(minutes: minutes))")
        .accessibilityHint(showsWheels ? "Hides the hours and minutes" : "Shows the hours and minutes")
    }

    // MARK: Wheels

    private var wheels: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: hours) {
                ForEach(Self.hourOptions, id: \.self) { hour in
                    Text(hour == 1 ? "1 hour" : "\(hour) hours").tag(hour)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            Picker("Minutes", selection: minutePart) {
                ForEach(minuteOptions, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    private static var hourOptions: [Int] {
        Array(0...(AppConfig.postDurationRangeMinutes.upperBound / 60))
    }

    /// 5-minute steps; fewer at the ends so the total stays within 15 min to 5 h.
    private var minuteOptions: [Int] {
        let range = AppConfig.postDurationRangeMinutes
        let hourStart = (minutes / 60) * 60
        return stride(from: 0, to: 60, by: AppConfig.postDurationStepMinutes)
            .filter { range.contains(hourStart + $0) }
    }

    private var hours: Binding<Int> {
        Binding(
            get: { minutes / 60 },
            set: { minutes = Self.clamped($0 * 60 + minutes % 60) })
    }

    private var minutePart: Binding<Int> {
        Binding(
            get: { minutes % 60 },
            set: { minutes = Self.clamped((minutes / 60) * 60 + $0) })
    }

    private static func clamped(_ value: Int) -> Int {
        let range = AppConfig.postDurationRangeMinutes
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
