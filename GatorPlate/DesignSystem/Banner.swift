import SwiftUI

/// Inline info, warning or error banner. Icon + text, never color alone. Optional action buttons.
struct Banner: View {
    struct Action {
        let title: String
        var isPrimary = true
        let handler: () -> Void
    }

    enum Style {
        case info, warning, error

        var icon: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: Theme.Palette.brandPurple
            case .warning: Theme.Palette.warning
            case .error: Theme.Palette.danger
            }
        }

        var spokenName: String {
            switch self {
            case .info: "Info"
            case .warning: "Warning"
            case .error: "Error"
            }
        }
    }

    let style: Style
    let message: String
    var actions: [Action] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                Image(systemName: style.icon).foregroundStyle(style.tint)
                Text(message).font(.subheadline)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(style.spokenName): \(message)")

            if !actions.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.sm) { actionButtons }
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) { actionButtons }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(style.tint.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.photo))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actionButtons: some View {
        ForEach(actions.indices, id: \.self) { index in
            let action = actions[index]
            if action.isPrimary {
                Button(action.title, action: action.handler)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: Theme.Size.minTapTarget)
            } else {
                Button(action.title, action: action.handler)
                    .buttonStyle(.bordered)
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
        }
    }
}
