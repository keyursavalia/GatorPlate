import Foundation

/// The analyzer's model order for one request: `ai_model_name`, then each `ai_fallback_model_names` entry. Moves
/// on only when the backend says a model is unavailable (retired, renamed, unsupported).
nonisolated struct GeminiModelChain: Equatable, Sendable {
    /// Never empty, no duplicates.
    let models: [String]
    private(set) var index: Int

    init(models: [String], startIndex: Int = 0) {
        var seen: Set<String> = []
        let unique = models.filter { seen.insert($0).inserted }
        self.models = unique.isEmpty ? [AppConfig.defaultGeminiModelName] : unique
        index = min(max(0, startIndex), self.models.count - 1)
    }

    var current: String { models[index] }

    /// Moves to the next model; false when the chain is exhausted (the caller falls back to manual entry).
    mutating func advance() -> Bool {
        guard index + 1 < models.count else { return false }
        index += 1
        return true
    }
}

/// Session-sticky memory of the first model that worked, so later requests skip a retired primary. Forgets it when
/// the configured list changes (a new Remote Config publish).
@MainActor
final class GeminiModelMemory {
    private var models: [String] = []
    private var workingIndex = 0

    /// A chain for this config, starting at the model that last worked for the same list.
    func chain(for config: RuntimeConfig) -> GeminiModelChain {
        let configured = GeminiModelChain(models: config.aiModelChain)
        if configured.models != models {
            models = configured.models
            workingIndex = 0
        }
        return GeminiModelChain(models: models, startIndex: workingIndex)
    }

    func markWorking(_ chain: GeminiModelChain) {
        guard chain.models == models else { return }
        workingIndex = chain.index
    }
}
