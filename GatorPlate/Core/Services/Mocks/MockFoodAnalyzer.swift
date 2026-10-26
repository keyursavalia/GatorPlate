import Foundation

#if DEBUG
/// Analyzer for debugging without the backend: a fixed outcome after a short delay.
@MainActor
final class MockFoodAnalyzer: FoodAnalyzing {
    var result: Result<FoodAnalysisOutcome, AppError>
    var delay: Duration

    init(result: Result<FoodAnalysisOutcome, AppError> = .success(.accepted(.sample)), delay: Duration = .seconds(2)) {
        self.result = result
        self.delay = delay
    }

    func prepare() {}

    func analyze(photos: [Data]) async throws(AppError) -> FoodAnalysisOutcome {
        do {
            try await Task.sleep(for: delay)
        } catch {
            throw .cancelled
        }
        let outcome = try result.get()
        // Every photo kept, so the multi-photo flow can be exercised.
        guard case .accepted(var accepted) = outcome else { return outcome }
        accepted.keptPhotoIndices = Array(photos.indices)
        return .accepted(accepted)
    }
}

extension FoodAnalysisResult {
    nonisolated static var sample: FoodAnalysisResult {
        FoodAnalysisResult(
            title: "Vegetable pad thai and spring rolls",
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
#endif
