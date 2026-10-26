import FirebaseRemoteConfig
import Foundation
import Observation
import OSLog

/// Remote Config (client template) for the app. Defaults come from `RuntimeConfig.defaults` (no plist, one source).
/// `RemoteConfig` isn't Sendable, so it is only touched on the main actor: SDK callbacks hop back here and
/// everything else reads the plain `RuntimeConfig` value. Errors are logged and swallowed; `current` keeps the last
/// good values. Logs key names and the model name only, never other values.
@MainActor
@Observable
final class FirebaseRuntimeConfig: RuntimeConfigProviding {
    private(set) var current: RuntimeConfig = .defaults

    @ObservationIgnored private var remoteConfig: RemoteConfig?
    @ObservationIgnored private var listener: ConfigUpdateListenerRegistration?

    func start() {
        guard remoteConfig == nil else { return }
        let remoteConfig = RemoteConfig.remoteConfig()
        self.remoteConfig = remoteConfig
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = AppConfig.runtimeConfigMinimumFetchIntervalSeconds
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(RuntimeConfig.defaults.remoteValues.mapValues { $0 as NSString })

        // Last session's fetched values, at once.
        remoteConfig.activate { [weak self] _, _ in
            Task { @MainActor in self?.publish(source: "cached") }
        }
        Task { await fetch() }
        listener = remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
            if let error {
                let nsError = error as NSError
                Logger.services.error("Runtime config listener failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
                return
            }
            guard update != nil else { return }
            Task { @MainActor in self?.activateUpdate() }
        }
    }

    private func fetch() async {
        guard let remoteConfig else { return }
        do {
            try await awaitCompletion(deadlineSeconds: AppConfig.runtimeConfigFetchTimeoutSeconds) { done in
                remoteConfig.fetchAndActivate { _, error in done(error) }
            }
            publish(source: "remote")
        } catch is DeadlineExceeded {
            Logger.services.notice("Runtime config fetch timed out; using cached or default values")
        } catch {
            let nsError = error as NSError
            Logger.services.error("Runtime config fetch failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
        }
    }

    /// A realtime update was fetched: activate it, then publish.
    private func activateUpdate() {
        remoteConfig?.activate { [weak self] _, error in
            if let error {
                let nsError = error as NSError
                Logger.services.error("Runtime config activate failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            }
            Task { @MainActor in self?.publish(source: "remote") }
        }
    }

    private func publish(source: String) {
        guard let remoteConfig else { return }
        var raw: [String: String] = [:]
        for key in RuntimeConfig.Key.allCases {
            raw[key.rawValue] = remoteConfig.configValue(forKey: key.rawValue).stringValue
        }
        let config = RuntimeConfig(raw: raw)
        guard config != current else { return }
        current = config
        Logger.services.info("""
            Runtime config active (source: \(source, privacy: .public), model: \(config.aiModelName, privacy: .public), \
            invalid: \(config.invalidKeys.joined(separator: ","), privacy: .public))
            """)
    }
}
