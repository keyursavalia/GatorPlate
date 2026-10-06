import SwiftUI

/// Inline info, warning or error banner. Icon + text, never color alone.
struct Banner: View {
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: style.icon).foregroundStyle(style.tint)
            Text(message).font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background(style.tint.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.photo))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.spokenName): \(message)")
    }
}

#Preview {
    VStack {
        Banner(style: .info, message: "Posts end after 30 minutes by default.")
        Banner(style: .warning, message: "Double-check allergens with the host.")
        Banner(style: .error, message: "Couldn't reach the server.")
    }
    .padding()
}
