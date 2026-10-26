import Foundation

/// Text hygiene for user-entered post fields. User text is always shown with `Text(verbatim:)`.
nonisolated enum PostText {
    /// Trims, turns newlines and control characters into spaces, drops emoji, and collapses whitespace.
    /// Emoji are dropped so lengths match the Firestore rules caps.
    static func clean(_ raw: String) -> String {
        let scalars = raw.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) { return " " }
            if scalar.value == 0x200D || (0xFE00...0xFE0F).contains(scalar.value) { return nil }
            if scalar.properties.isEmoji && scalar.value > 0x7F { return nil }
            return scalar
        }
        return String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Hard input cap applied while typing.
    static func limited(_ text: String, to limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) : text
    }
}
