import Foundation

/// Builds the suggested title: `FREE: <food> - <building room> - until <time>` (school posting best practice).
nonisolated enum PostTitleFormatter {
    static let freePrefix = "FREE: "

    static func title(food: String, location: PostLocation?, detail: String, until: Date) -> String {
        let place = [location?.shortName, PostText.clean(detail)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let time = "until " + until.formatted(date: .omitted, time: .shortened)
        let tail = (place.isEmpty ? [] : [place]) + [time]
        let suffix = tail.map { " - " + $0 }.joined()

        // The food part gives way first so the place and time always fit.
        let foodBudget = max(0, AppConfig.postTitleMaxLength - freePrefix.count - suffix.count)
        var foodPart = FoodAnalysisSanitizer.truncated(PostText.clean(food), to: foodBudget)
        if foodPart.isEmpty { foodPart = "Food" }
        let title = freePrefix + foodPart + suffix
        return String(title.prefix(AppConfig.postTitleMaxLength))
    }

    /// The food words: the AI title without "FREE: ", else up to two item names.
    static func food(aiTitle: String?, items: [FoodItem]) -> String {
        if let aiTitle {
            var body = aiTitle
            if body.hasPrefix(freePrefix) { body.removeFirst(freePrefix.count) }
            body = PostText.clean(body)
            if !body.isEmpty { return body }
        }
        let names = items.prefix(2).map(\.name)
        return names.isEmpty ? "Food" : names.formatted(.list(type: .and))
    }
}
