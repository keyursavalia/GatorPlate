import OSLog

extension Logger {
    private nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? AppConfig.appName

    /// Never log photos, emails, or full prompts.
    nonisolated static let app = Logger(subsystem: subsystem, category: "app")
    nonisolated static let firebase = Logger(subsystem: subsystem, category: "firebase")
    nonisolated static let camera = Logger(subsystem: subsystem, category: "camera")
    nonisolated static let ai = Logger(subsystem: subsystem, category: "ai")
}
