import Foundation

/// Builds the suggested title in the Gator Grub Alert style: `FREE: <food> - <building room> - until <time>`.
nonisolated enum PostTitleFormatter {
    static func suggestion(
        items: [String],
        place: String?,
        roomDetail: String,
        expiresAt: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String? {
        let names = items.map(PostText.line).filter { !$0.isEmpty }
        guard let first = names.first else { return nil }

        let food = names.count > 1 ? "\(first) and more" : first
        let room = PostText.line(roomDetail)
        let location = [place.map(PostText.line), room.isEmpty ? nil : room]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let time = expiresAt.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        )
        var tail = " - until \(time)"
        if !location.isEmpty { tail = " - \(location)" + tail }

        let prefix = "FREE: "
        let available = AppConfig.maxTitleLength - prefix.count - tail.count
        guard available > 1 else { return String((prefix + food + tail).prefix(AppConfig.maxTitleLength)) }
        let shownFood = food.count > available ? String(food.prefix(available - 1)) + "…" : food
        return prefix + shownFood + tail
    }
}
