import SwiftUI

/// Inline info, warning, or error banner. Color is always paired with an icon and a spoken kind.
struct Banner: View {
    enum Kind {
        case info, warning, error

        var systemImage: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.octagon.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: .brandPurple
            case .warning: .warning
            case .error: .danger
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

    let kind: Kind
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(kind.tint)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(kind.spokenName): \(message)")

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Theme.minTapTarget)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.Radius.photo))
    }
}

#Preview("All kinds") {
    VStack(spacing: Theme.Spacing.m) {
        Banner(kind: .info, message: "Posts disappear after 30 minutes by default.")
        Banner(kind: .warning, message: "Double-check allergens with the host.")
        Banner(kind: .error, message: "Could not reach the server. Try again.")
        Banner(kind: .warning, message: "Location is off for GatorPlate.", actionTitle: "Open Settings") {}
    }
    .padding()
    .environment(\.appEnvironment, .mock)
}
