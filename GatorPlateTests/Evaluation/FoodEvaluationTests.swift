import Foundation
import OSLog
import Testing
@testable import GatorPlate

/// Opt-in live evaluation (spec section 8). Skipped in the normal run: set `RUN_AI_EVAL=1` in the scheme's
/// environment variables. Uses the real Gemini analyzer, so it needs Firebase configured and a registered
/// App Check debug token, and it spends quota. Writes `food-eval-report.md` to the temporary directory.
struct FoodEvaluationTests {
    private struct Label: Decodable {
        var file: String
        var expectFood: Bool
        var expectPeople: Bool
        var itemKeywords: [String]?
        var dietary: String?
    }

    private final class BundleToken {}

    private static let enabled = ProcessInfo.processInfo.environment["RUN_AI_EVAL"] == "1"

    @Test(.enabled(if: FoodEvaluationTests.enabled))
    func evaluateFixturesAgainstLiveGemini() async throws {
        let bundle = Bundle(for: BundleToken.self)
        let labelsURL = try #require(bundle.url(forResource: "labels", withExtension: "json"))
        let labels = try JSONDecoder().decode([Label].self, from: Data(contentsOf: labelsURL))
        let analyzer = GeminiFoodAnalyzer()

        var rows: [String] = []
        var latencies: [Double] = []
        var falseVegan = 0, wrongRejection = 0, badLength = 0, failures = 0

        for label in labels {
            let name = (label.file as NSString).deletingPathExtension
            guard let url = bundle.url(forResource: name, withExtension: (label.file as NSString).pathExtension),
                  let photo = try? ImagePreprocessor.process(data: Data(contentsOf: url))
            else {
                rows.append("| \(label.file) | missing fixture | | | | |")
                continue
            }

            let start = ContinuousClock.now
            let outcome = try? await analyzer.analyze(imageJPEG: photo.jpegData)
            let parts = (ContinuousClock.now - start).components
            let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            latencies.append(seconds)

            switch outcome {
            case .accepted(let result)?:
                let shouldReject = !label.expectFood || label.expectPeople
                if shouldReject { wrongRejection += 1 }
                let isFalseVegan = result.overallDietary == .vegan && label.dietary != nil && label.dietary != "vegan"
                if isFalseVegan { falseVegan += 1 }
                let lengthOK = (100...150).contains(result.description.count)
                if !lengthOK { badLength += 1 }
                let names = result.items.map(\.name).joined(separator: ", ")
                let matched = (label.itemKeywords ?? []).allSatisfy { names.localizedCaseInsensitiveContains($0) }
                rows.append("| \(label.file) | accepted: \(names) | \(result.overallDietary.rawValue)\(isFalseVegan ? " FALSE VEGAN" : "") | \(result.allergenWarnings.map(\.rawValue).joined(separator: ", ")) | \(result.description.count)\(lengthOK ? "" : " (!)") | \(matched ? "items ok" : "items?") \(String(format: "%.1fs", seconds)) |")
            case .rejected(let reason)?:
                let shouldReject = !label.expectFood || label.expectPeople
                if !shouldReject { wrongRejection += 1 }
                rows.append("| \(label.file) | rejected: \(reason) | | | | \(shouldReject ? "correct" : "WRONG") \(String(format: "%.1fs", seconds)) |")
            case nil:
                failures += 1
                rows.append("| \(label.file) | FAILED | | | | \(String(format: "%.1fs", seconds)) |")
            }
        }

        let sorted = latencies.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let average = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let report = """
        # Food analysis evaluation

        Model: \(AppConfig.geminiModelName), prompt \(FoodAnalysisPrompt.promptVersion), photos: \(labels.count)

        - False-vegan count: \(falseVegan) (target 0)
        - Wrong accept/reject decisions: \(wrongRejection)
        - Descriptions outside 100-150 characters: \(badLength)
        - Failed analyses: \(failures)
        - Latency: median \(String(format: "%.1f", median))s, average \(String(format: "%.1f", average))s (target < 6s)

        | Photo | Result | Overall dietary | Allergens | Description chars | Notes |
        |---|---|---|---|---|---|
        \(rows.joined(separator: "\n"))
        """
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("food-eval-report.md")
        try report.write(to: output, atomically: true, encoding: .utf8)
        Logger.ai.info("evaluation report written to \(output.path, privacy: .public)")

        #expect(falseVegan == 0)
    }
}
