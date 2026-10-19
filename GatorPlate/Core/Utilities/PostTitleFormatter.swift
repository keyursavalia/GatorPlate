import Foundation

/// Builds the suggested title: `<food> - <building room> - until <time>`. No "FREE" prefix: everything on
/// GatorPlate is free (S09).
nonisolated enum PostTitleFormatter {
    static func title(food: String, location: PostLocation?, detail: String, until: Date) -> String {
        let place = [location?.shortName, PostText.clean(detail)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let time = "until " + until.formatted(date: .omitted, time: .shortened)
        let tail = (place.isEmpty ? [] : [place]) + [time]
        let suffix = tail.map { " - " + $0 }.joined()

        // The food part gives way first so the place and time always fit.
        let foodBudget = max(0, AppConfig.postTitleMaxLength - suffix.count)
        var foodPart = FoodAnalysisSanitizer.truncated(PostText.clean(food), to: foodBudget)
        if foodPart.isEmpty { foodPart = "Food" }
        let title = foodPart + suffix
        return String(title.prefix(AppConfig.postTitleMaxLength))
    }

    /// The food words: the AI title (minus any "FREE" prefix), else up to two item names.
    static func food(aiTitle: String?, items: [FoodItem]) -> String {
        if let aiTitle {
            let body = PostText.clean(FoodAnalysisSanitizer.strippingFreePrefix(PostText.clean(aiTitle)))
            if !body.isEmpty { return body }
        }
        let names = items.prefix(2).map(\.name)
        return names.isEmpty ? "Food" : names.formatted(.list(type: .and))
    }
}
