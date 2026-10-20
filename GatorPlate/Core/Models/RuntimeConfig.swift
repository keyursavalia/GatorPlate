import Foundation

/// Gemini "thinking" preset for the analyzer (`ai_thinking_level`). `off` sends no thinking config (the remote value
/// is `default`), for models that reject one.
nonisolated enum AIThinkingLevel: String, CaseIterable, Sendable {
    case minimal, low, medium, high, off

    /// The Remote Config spelling.
    var remoteValue: String { self == .off ? "default" : rawValue }

    init?(remoteValue: String) {
        if remoteValue == "default" { self = .off } else { self.init(rawValue: remoteValue) }
    }
}

nonisolated enum ServiceNoticeLevel: String, Sendable {
    case info, warning
}

/// Every app setting the owner can change from Firebase Remote Config (client template), parsed and validated.
/// Pure: no Firebase import. Anything invalid falls back to the in-app default and numbers are clamped, so a bad
/// publish can never crash the app or lock people out. Mirrors `functions/src/config-logic.ts` for the shared keys
/// and the catalog in docs/06-OPERATIONS.md.
nonisolated struct RuntimeConfig: Equatable, Sendable {
    /// Remote Config keys (client template).
    enum Key: String, CaseIterable, Sendable {
        case aiEnabled = "ai_enabled"
        case aiModelName = "ai_model_name"
        case aiFallbackModelNames = "ai_fallback_model_names"
        case aiThinkingLevel = "ai_thinking_level"
        case aiTemperature = "ai_temperature"
        case aiMaxOutputTokens = "ai_max_output_tokens"
        case aiTimeoutSeconds = "ai_timeout_seconds"
        case aiMaxTimeoutSeconds = "ai_max_timeout_seconds"
        case aiMinConfidence = "ai_min_confidence"
        case postingEnabled = "posting_enabled"
        case serviceNotice = "service_notice"
        case serviceNoticeLevel = "service_notice_level"
        case minimumAppVersion = "minimum_app_version"
        case recommendedAppVersion = "recommended_app_version"
        case appStoreURL = "app_store_url"
        case supportEmail = "support_email"
        case contentFilterTerms = "content_filter_terms"
        case contentFilterTradingTerms = "content_filter_trading_terms"
    }

    static let maxFallbackModels = 4
    static let serviceNoticeMaxLength = 200
    static let maxFilterTerms = 2000
    static let maxTradingTerms = 200
    static let filterTermLengths = 2...40
    static let appStoreURLPrefix = "https://apps.apple.com/"

    var aiEnabled: Bool
    var aiModelName: String
    /// Never contains `aiModelName` or duplicates.
    var aiFallbackModelNames: [String]
    var aiThinkingLevel: AIThinkingLevel
    var aiTemperature: Double
    var aiMaxOutputTokens: Int
    var aiTimeoutSeconds: Int
    var aiMaxTimeoutSeconds: Int
    var aiMinConfidence: Double
    var postingEnabled: Bool
    /// Trimmed; empty hides the banner.
    var serviceNotice: String
    var serviceNoticeLevel: ServiceNoticeLevel
    var minimumAppVersion: AppVersion?
    var recommendedAppVersion: AppVersion?
    var appStoreURL: URL?
    var supportEmail: String
    var contentFilterTerms: [String]
    var contentFilterTradingTerms: [String]
    /// Keys whose remote value was unusable (fell back or was clamped). Key names only, for one log line.
    var invalidKeys: [String] = []

    /// `[aiModelName] + aiFallbackModelNames`.
    var aiModelChain: [String] { [aiModelName] + aiFallbackModelNames }

    /// Built from the bundled lists; cheap to compare, so it isn't stored.
    var contentFilter: ContentFilter {
        ContentFilter(terms: contentFilterTerms, tradingTerms: contentFilterTradingTerms)
    }

    /// The in-app defaults (from `AppConfig` and the bundled content-filter seed).
    static let defaults = RuntimeConfig(
        aiEnabled: true,
        aiModelName: AppConfig.defaultGeminiModelName,
        aiFallbackModelNames: AppConfig.defaultGeminiFallbackModelNames.filter { $0 != AppConfig.defaultGeminiModelName },
        aiThinkingLevel: AppConfig.defaultAIThinkingLevel,
        aiTemperature: AppConfig.aiTemperature,
        aiMaxOutputTokens: AppConfig.aiMaxOutputTokens,
        aiTimeoutSeconds: AppConfig.aiTimeoutSeconds,
        aiMaxTimeoutSeconds: AppConfig.aiMaxTimeoutSeconds,
        aiMinConfidence: AppConfig.aiMinConfidence,
        postingEnabled: true,
        serviceNotice: "",
        serviceNoticeLevel: .info,
        minimumAppVersion: nil,
        recommendedAppVersion: nil,
        appStoreURL: nil,
        supportEmail: AppConfig.supportEmail,
        contentFilterTerms: ContentFilterSeed.bundled.terms,
        contentFilterTradingTerms: ContentFilterSeed.bundled.tradingTerms)

    init(aiEnabled: Bool, aiModelName: String, aiFallbackModelNames: [String], aiThinkingLevel: AIThinkingLevel,
         aiTemperature: Double, aiMaxOutputTokens: Int, aiTimeoutSeconds: Int, aiMaxTimeoutSeconds: Int,
         aiMinConfidence: Double, postingEnabled: Bool, serviceNotice: String, serviceNoticeLevel: ServiceNoticeLevel,
         minimumAppVersion: AppVersion?, recommendedAppVersion: AppVersion?, appStoreURL: URL?, supportEmail: String,
         contentFilterTerms: [String], contentFilterTradingTerms: [String]) {
        self.aiEnabled = aiEnabled
        self.aiModelName = aiModelName
        self.aiFallbackModelNames = aiFallbackModelNames
        self.aiThinkingLevel = aiThinkingLevel
        self.aiTemperature = aiTemperature
        self.aiMaxOutputTokens = aiMaxOutputTokens
        self.aiTimeoutSeconds = aiTimeoutSeconds
        self.aiMaxTimeoutSeconds = aiMaxTimeoutSeconds
        self.aiMinConfidence = aiMinConfidence
        self.postingEnabled = postingEnabled
        self.serviceNotice = serviceNotice
        self.serviceNoticeLevel = serviceNoticeLevel
        self.minimumAppVersion = minimumAppVersion
        self.recommendedAppVersion = recommendedAppVersion
        self.appStoreURL = appStoreURL
        self.supportEmail = supportEmail
        self.contentFilterTerms = contentFilterTerms
        self.contentFilterTradingTerms = contentFilterTradingTerms
    }

    /// Parses Remote Config string values. Missing or blank keys use `defaults` silently; unusable ones use it too
    /// and are listed in `invalidKeys`.
    init(raw: [String: String], defaults: RuntimeConfig = .defaults) {
        var read = Reader(raw: raw)
        let modelName = read.string(.aiModelName, defaults.aiModelName) { Self.isModelName($0) ? $0 : nil }
        let timeout = read.int(.aiTimeoutSeconds, defaults.aiTimeoutSeconds, 10...60)
        self.init(
            aiEnabled: read.bool(.aiEnabled, defaults.aiEnabled),
            aiModelName: modelName,
            aiFallbackModelNames: read.fallbackModels(defaults.aiFallbackModelNames, primary: modelName),
            aiThinkingLevel: read.string(.aiThinkingLevel, defaults.aiThinkingLevel) {
                AIThinkingLevel(remoteValue: $0.lowercased())
            },
            aiTemperature: read.double(.aiTemperature, defaults.aiTemperature, 0...1),
            aiMaxOutputTokens: read.int(.aiMaxOutputTokens, defaults.aiMaxOutputTokens, 512...8192),
            aiTimeoutSeconds: timeout,
            aiMaxTimeoutSeconds: read.int(.aiMaxTimeoutSeconds, max(defaults.aiMaxTimeoutSeconds, timeout), timeout...90),
            aiMinConfidence: read.double(.aiMinConfidence, defaults.aiMinConfidence, 0.1...0.9),
            postingEnabled: read.bool(.postingEnabled, defaults.postingEnabled),
            serviceNotice: read.string(.serviceNotice, defaults.serviceNotice) {
                $0.count <= Self.serviceNoticeMaxLength ? $0 : nil
            },
            serviceNoticeLevel: read.string(.serviceNoticeLevel, defaults.serviceNoticeLevel) {
                ServiceNoticeLevel(rawValue: $0.lowercased())
            },
            minimumAppVersion: read.string(.minimumAppVersion, defaults.minimumAppVersion) { AppVersion($0) },
            recommendedAppVersion: read.string(.recommendedAppVersion, defaults.recommendedAppVersion) { AppVersion($0) },
            appStoreURL: read.string(.appStoreURL, defaults.appStoreURL) { text in
                text.hasPrefix(Self.appStoreURLPrefix) ? URL(string: text) : nil
            },
            supportEmail: read.string(.supportEmail, defaults.supportEmail) { text in
                Validation.emailIssue(text) == nil ? Validation.normalizedEmail(text) : nil
            },
            contentFilterTerms: read.list(.contentFilterTerms, defaults.contentFilterTerms, max: Self.maxFilterTerms),
            contentFilterTradingTerms: read.list(.contentFilterTradingTerms, defaults.contentFilterTradingTerms,
                                                 max: Self.maxTradingTerms))
        invalidKeys = read.invalidKeys
    }

    /// The defaults as Remote Config strings (`RemoteConfig.setDefaults`), so there is one source of defaults.
    var remoteValues: [String: String] {
        func json(_ list: [String]) -> String {
            (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
        return [
            Key.aiEnabled.rawValue: String(aiEnabled),
            Key.aiModelName.rawValue: aiModelName,
            Key.aiFallbackModelNames.rawValue: json(aiFallbackModelNames),
            Key.aiThinkingLevel.rawValue: aiThinkingLevel.remoteValue,
            Key.aiTemperature.rawValue: String(aiTemperature),
            Key.aiMaxOutputTokens.rawValue: String(aiMaxOutputTokens),
            Key.aiTimeoutSeconds.rawValue: String(aiTimeoutSeconds),
            Key.aiMaxTimeoutSeconds.rawValue: String(aiMaxTimeoutSeconds),
            Key.aiMinConfidence.rawValue: String(aiMinConfidence),
            Key.postingEnabled.rawValue: String(postingEnabled),
            Key.serviceNotice.rawValue: serviceNotice,
            Key.serviceNoticeLevel.rawValue: serviceNoticeLevel.rawValue,
            Key.minimumAppVersion.rawValue: minimumAppVersion?.description ?? "",
            Key.recommendedAppVersion.rawValue: recommendedAppVersion?.description ?? "",
            Key.appStoreURL.rawValue: appStoreURL?.absoluteString ?? "",
            Key.supportEmail.rawValue: supportEmail,
            Key.contentFilterTerms.rawValue: json(contentFilterTerms),
            Key.contentFilterTradingTerms.rawValue: json(contentFilterTradingTerms),
        ]
    }

    /// `gemini-` then lowercase letters, digits, dots and dashes (same rule as the functions).
    static func isModelName(_ text: String) -> Bool {
        text.range(of: #"^gemini-[a-z0-9][a-z0-9.\-]{0,60}$"#, options: .regularExpression) != nil
    }
}

/// Reads one key at a time and remembers which present values were unusable.
private nonisolated struct Reader {
    let raw: [String: String]
    var invalidKeys: [String] = []

    init(raw: [String: String]) {
        self.raw = raw
    }

    private func value(_ key: RuntimeConfig.Key) -> String? {
        guard let text = raw[key.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    private mutating func invalid(_ key: RuntimeConfig.Key) {
        invalidKeys.append(key.rawValue)
    }

    mutating func bool(_ key: RuntimeConfig.Key, _ fallback: Bool) -> Bool {
        guard let text = value(key)?.lowercased() else { return fallback }
        switch text {
        case "true": return true
        case "false": return false
        default:
            invalid(key)
            return fallback
        }
    }

    /// Out-of-range numbers are clamped (and listed); non-numbers fall back.
    mutating func double(_ key: RuntimeConfig.Key, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
        guard let text = value(key) else { return fallback }
        guard let number = Double(text), number.isFinite else {
            invalid(key)
            return fallback
        }
        let clamped = min(range.upperBound, max(range.lowerBound, number))
        if clamped != number { invalid(key) }
        return clamped
    }

    mutating func int(_ key: RuntimeConfig.Key, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
        guard let text = value(key) else { return min(range.upperBound, max(range.lowerBound, fallback)) }
        guard let number = Double(text), number.isFinite else {
            invalid(key)
            return min(range.upperBound, max(range.lowerBound, fallback))
        }
        let rounded = Int(number.rounded())
        let clamped = min(range.upperBound, max(range.lowerBound, rounded))
        if Double(clamped) != number { invalid(key) }
        return clamped
    }

    /// A present value the parser rejects falls back (and is listed). Blank means "use the default".
    mutating func string<T>(_ key: RuntimeConfig.Key, _ fallback: T, _ parse: (String) -> T?) -> T {
        guard let text = value(key) else { return fallback }
        guard let parsed = parse(text) else {
            invalid(key)
            return fallback
        }
        return parsed
    }

    /// Up to `maxFallbackModels` model names; any bad entry rejects the list. Duplicates and the primary are removed.
    mutating func fallbackModels(_ fallback: [String], primary: String) -> [String] {
        var names = fallback
        if let text = value(.aiFallbackModelNames) {
            if let list = Self.stringArray(text), list.count <= RuntimeConfig.maxFallbackModels,
               list.allSatisfy(RuntimeConfig.isModelName) {
                names = list
            } else {
                invalid(.aiFallbackModelNames)
            }
        }
        var seen: Set<String> = [primary]
        return names.filter { seen.insert($0).inserted }
    }

    /// A JSON array of strings with at most `max` entries; entries outside the length range are dropped.
    mutating func list(_ key: RuntimeConfig.Key, _ fallback: [String], max: Int) -> [String] {
        guard let text = value(key) else { return fallback }
        guard let list = Self.stringArray(text), list.count <= max else {
            invalid(key)
            return fallback
        }
        return list
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { RuntimeConfig.filterTermLengths.contains($0.count) }
    }

    private static func stringArray(_ text: String) -> [String]? {
        try? JSONDecoder().decode([String].self, from: Data(text.utf8))
    }
}
