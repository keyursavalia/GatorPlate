import SwiftUI

/// Initials in a brand-tinted circle. No profile photos (product non-goal). Decorative to VoiceOver.
struct MonogramAvatar: View {
    let name: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    var body: some View {
        Text(Self.initials(for: name))
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.Palette.brandPurple)
            .frame(width: size, height: size)
            .background(Theme.Palette.brandPurple.opacity(0.15), in: .circle)
            .accessibilityHidden(true)
    }

    /// Up to two initials from the first and last words ("Asian Student Union" -> "AU").
    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

#Preview {
    HStack {
        MonogramAvatar(name: "Alex Gator")
        MonogramAvatar(name: "Asian Student Union")
        MonogramAvatar(name: "")
    }
}
