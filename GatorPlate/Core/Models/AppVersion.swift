import Foundation

/// A marketing version like "1", "1.2" or "1.2.3"; missing parts count as 0, so "1.2" == "1.2.0".
/// Used by the Remote Config update gates (`minimum_app_version`, `recommended_app_version`).
nonisolated struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// Nil unless the text is 1 to 3 dot-separated numbers (no spaces, letters or empty parts).
    init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) })
        else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        major = numbers[0]
        minor = numbers.count > 1 ? numbers[1] : 0
        patch = numbers.count > 2 ? numbers[2] : 0
    }

    /// This build's `CFBundleShortVersionString`, or nil if it can't be read (then no gate ever shows).
    static let current: AppVersion? = {
        guard let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return nil }
        return AppVersion(text)
    }()

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
