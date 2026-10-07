import Foundation

/// Analyzer for previews: a fixed outcome after a short delay.
@MainActor
final class MockFoodAnalyzer: FoodAnalyzing {
    var result: Result<FoodAnalysisOutcome, AppError>
    var delay: Duration
    private(set) var lastDiagnostics: FoodAnalysisDiagnostics?

    init(result: Result<FoodAnalysisOutcome, AppError> = .success(.accepted(.sample)), delay: Duration = .seconds(2)) {
        self.result = result
        self.delay = delay
    }

    func analyze(jpegData: Data) async throws(AppError) -> FoodAnalysisOutcome {
        do {
            try await Task.sleep(for: delay)
        } catch {
            throw .cancelled
        }
        lastDiagnostics = FoodAnalysisDiagnostics(latencyMs: Int(delay / .milliseconds(1)), attempts: 1,
                                                  category: "mock", modelDietary: nil, modelConfidence: nil)
        return try result.get()
    }
}

extension FoodAnalysisResult {
    nonisolated static var sample: FoodAnalysisResult {
        FoodAnalysisResult(
            title: "FREE: Vegetable pad thai and spring rolls",
            description: "Pad thai noodles with tofu, vegetable spring rolls and cut fruit. May contain soy, peanuts and wheat.",
            items: [
                FoodItem(name: "Vegetable pad thai", dietary: .vegetarian, calories: CalorieRange(low: 380, high: 520)),
                FoodItem(name: "Spring rolls", dietary: .vegan, calories: CalorieRange(low: 90, high: 150)),
                FoodItem(name: "Cut fruit", dietary: .vegan, calories: nil),
            ],
            overallDietary: .vegetarian, allergens: [.peanuts, .wheat, .soy],
            cautions: ["Noodles are perishable; eat within 2 hours of serving."],
            estimatedServings: 10, confidence: 0.82, promptVersion: "mock", modelName: "mock")
    }
}
