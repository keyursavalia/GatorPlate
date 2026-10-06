import Foundation

@MainActor
final class MockFoodAnalyzer: FoodAnalyzing {
    var result: Result<FoodAnalysisResult, AppError>

    init(result: Result<FoodAnalysisResult, AppError> = .success(.sample)) {
        self.result = result
    }

    func analyze(imageJPEG: Data) async throws -> FoodAnalysisResult {
        try result.get()
    }
}

extension FoodAnalysisResult {
    nonisolated static var sample: FoodAnalysisResult {
        FoodAnalysisResult(
            title: "Pad Thai", description: "Leftover pad thai.",
            items: [FoodItem(name: "Pad Thai", dietary: .vegan, calories: CalorieRange(low: 420, high: 520))],
            overallDietary: .vegan, allergenWarnings: [.soy, .peanuts], cautions: [], estimatedServings: 10)
    }
}
