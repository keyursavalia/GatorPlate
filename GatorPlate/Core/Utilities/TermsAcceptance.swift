import Foundation

/// The Terms of Use (and Privacy Policy) version accepted on this device, before any account exists. Guests
/// and members both pass this gate on first launch; the version is also recorded on the user's profile.
nonisolated struct TermsAcceptance {
    static let versionKey = "terms.acceptedVersion"
    static let dateKey = "terms.acceptedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True when the current `AppConfig.termsVersion` was accepted here.
    var isCurrent: Bool {
        defaults.string(forKey: Self.versionKey) == AppConfig.termsVersion
    }

    /// When the current version was accepted; nil if it wasn't.
    var acceptedAt: Date? {
        guard isCurrent else { return nil }
        return defaults.object(forKey: Self.dateKey) as? Date
    }

    func recordCurrent(at date: Date = .now) {
        defaults.set(AppConfig.termsVersion, forKey: Self.versionKey)
        defaults.set(date, forKey: Self.dateKey)
    }
}
