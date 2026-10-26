import OSLog

/// Category loggers. Never log photos, emails, or full prompts.
nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? AppConfig.appName

    static let app = Logger(subsystem: subsystem, category: "app")
    static let services = Logger(subsystem: subsystem, category: "services")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
