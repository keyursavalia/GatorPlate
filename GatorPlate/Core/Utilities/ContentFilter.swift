import Foundation
import OSLog

/// Text filter for posts and names. Mirror of `functions/src/content-filter.ts`; both run the shared fixture
/// `functions/test/fixtures/content-filter-cases.json`, so change them together.
///
/// Normalization: lowercase, fold diacritics, map leetspeak (0→o 1→i 3→e 4→a 5→s 7→t @→a $→s), turn non-letters
/// into spaces, cut runs of 3+ repeated letters to 2, split into tokens. A one-word term matches a whole token, or
/// anywhere inside one when it has 6+ letters; a multi-word term matches consecutive tokens. Trading also matches a
/// price ("$5", "5 bucks") on the original text. Blocked words win over trading.
nonisolated struct ContentFilter: Sendable {
    enum Verdict: String, Sendable {
        /// Words that aren't allowed.
        case terms
        /// Prices or payment apps (posts must be free).
        case trading
    }

    /// One-word terms this long also match inside a token.
    private static let substringMinLetters = 6
    private static let leet: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s",
    ]
    private static let pricePatterns = [#"\$\s?\d"#, #"\d\s?(dollars?|bucks)"#]

    private let terms: [[String]]
    private let tradingTerms: [[String]]

    /// Term lists are normalized once; empty terms are dropped.
    init(terms: [String], tradingTerms: [String]) {
        self.terms = terms.map(Self.tokens).filter { !$0.isEmpty }
        self.tradingTerms = tradingTerms.map(Self.tokens).filter { !$0.isEmpty }
    }

    func check(_ text: String) -> Verdict? {
        let textTokens = Self.tokens(text)
        if Self.matchesAny(textTokens, terms) { return .terms }
        if Self.hasPrice(text) || Self.matchesAny(textTokens, tradingTerms) { return .trading }
        return nil
    }

    /// Normalized tokens of `text` (see the type comment).
    static func tokens(_ text: String) -> [String] {
        let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        var out = ""
        var last: Character?
        var run = 0
        for raw in folded {
            let char = leet[raw] ?? raw
            if char.isLetter {
                if char == last {
                    run += 1
                } else {
                    last = char
                    run = 1
                }
                if run <= 2 { out.append(char) }
            } else {
                out.append(" ")
                last = nil
                run = 0
            }
        }
        return out.split(separator: " ").map(String.init)
    }

    static func hasPrice(_ text: String) -> Bool {
        pricePatterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private static func matchesAny(_ textTokens: [String], _ terms: [[String]]) -> Bool {
        terms.contains { term in
            if term.count == 1 {
                let word = term[0]
                let allowSubstring = word.count >= substringMinLetters
                return textTokens.contains { $0 == word || (allowSubstring && $0.contains(word)) }
            }
            guard textTokens.count >= term.count else { return false }
            return (0...(textTokens.count - term.count)).contains { start in
                term.indices.allSatisfy { textTokens[start + $0] == term[$0] }
            }
        }
    }
}

/// The bundled seed lists (`Resources/content-filter-seed.json`), used until Remote Config has been fetched.
/// Identical to `functions/src/content-filter-seed.ts` (a Node test compares them).
nonisolated enum ContentFilterSeed {
    struct Lists: Decodable, Equatable, Sendable {
        var terms: [String]
        var tradingTerms: [String]
    }

    static let bundled: Lists = {
        guard let url = Bundle.main.url(forResource: "content-filter-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lists = decode(data) else {
            Logger.app.error("Content filter seed missing from the bundle")
            return Lists(terms: [], tradingTerms: [])
        }
        return lists
    }()

    static func decode(_ data: Data) -> Lists? {
        try? JSONDecoder().decode(Lists.self, from: data)
    }
}
