import SwiftUI

/// Rounded content card (radius 20) on the secondary background, with an optional header: title, SF Symbol and a
/// trailing accessory such as the AI badge. Content, never glass.
struct SectionCard<Accessory: View, Content: View>: View {
    let title: String?
    var systemImage: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Group {
                        if let systemImage {
                            Label(title, systemImage: systemImage)
                        } else {
                            Text(title)
                        }
                    }
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Theme.Spacing.sm)
                    accessory
                }
            }
            content
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

extension SectionCard where Accessory == EmptyView {
    init(title: String?, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, accessory: { EmptyView() }, content: content)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.lg) {
            SectionCard(title: "What's there", systemImage: "fork.knife") {
                AIBadge()
            } content: {
                Text("Pad thai and spring rolls")
            }
            SectionCard(title: nil) {
                Text("No header")
            }
        }
        .padding()
    }
}
