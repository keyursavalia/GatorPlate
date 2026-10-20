#if DEBUG
import Foundation

/// DEBUG-only CSV row for `docs/EVAL-04-REPORT.md` (columns in `header`). Holds categories and numbers only: no image, no text content.
enum AnalysisEvalLine {
    static let header = "outcome,latencyMs,attempts,overallDietary,modelDietary,itemCount,allergens,hasCalories,confidence,model,promptVersion,photoCount"

    static func make(state: AnalysisViewModel.State, diagnostics: FoodAnalysisDiagnostics?) -> String? {
        guard let diagnostics else { return nil }
        let result: FoodAnalysisResult? = if case .success(let result) = state { result } else { nil }
        let confidence = (result?.confidence ?? diagnostics.modelConfidence).map { String(format: "%.2f", $0) } ?? ""
        let fields: [String] = [
            diagnostics.category,
            String(diagnostics.latencyMs),
            String(diagnostics.attempts),
            result?.overallDietary.rawValue ?? "",
            diagnostics.modelDietary ?? "",
            result.map { String($0.items.count) } ?? "",
            result?.allergens.map(\.rawValue).joined(separator: "|") ?? "",
            result.map { $0.items.contains { $0.calories != nil } ? "yes" : "no" } ?? "",
            confidence,
            diagnostics.modelName ?? "",
            FoodAnalysisPrompt.promptVersion,
            diagnostics.photoCount.map(String.init) ?? "",
        ]
        return fields.joined(separator: ",")
    }
}
#endif
