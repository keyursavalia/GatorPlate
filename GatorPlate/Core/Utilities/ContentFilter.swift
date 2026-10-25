import Foundation
import OSLog

/// Text filter for posts and names. Mirror of `functions/src/content-filter.ts`; both run the shared fixture
/// `functions/test/fixtures/content-filter-cases.json`, so change them together.
///
/// Normalization: lowercase, fold diacritics, map leetspeak (0→o 1→i 3→e 4→a 5→s 7→t @→a $→s), turn non-letters
/// into spaces, cut runs of 3+ repeated letters to 2, split into tokens. A one-word term matches a whole token, or
/// anywhere inside one when it has 6+ letters; a multi-word term matches consecutive tokens. Trading also matches a
/// price ("$5", "5 bucks") on the original text. Blocked words win over trading.
nonisolated struct ContentFilter: Equatable, Sendable {
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

    private let terms: TermIndex
    private let tradingTerms: TermIndex

    /// Term lists are normalized and indexed once; empty terms are dropped.
    init(terms: [String], tradingTerms: [String]) {
        self.terms = TermIndex(terms.map(Self.tokens))
        self.tradingTerms = TermIndex(tradingTerms.map(Self.tokens))
    }

    /// Runs on every keystroke in names and post fields, so matching uses the index instead of scanning every term.
    func check(_ text: String) -> Verdict? {
        let textTokens = Self.tokens(text)
        if terms.matches(textTokens) { return .terms }
        if Self.hasPrice(text) || tradingTerms.matches(textTokens) { return .trading }
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

    /// Normalized terms grouped for lookup: one-word terms in a set (plus the long ones again for substring
    /// matches) and multi-word terms by their first word.
    private struct TermIndex: Equatable, Sendable {
        private var words: Set<String> = []
        private var substringWords: [String] = []
        private var phrasesByFirstWord: [String: [[String]]] = [:]

        init(_ terms: [[String]]) {
            for term in terms {
                switch term.count {
                case 0: continue
                case 1:
                    guard words.insert(term[0]).inserted else { continue }
                    if term[0].count >= ContentFilter.substringMinLetters { substringWords.append(term[0]) }
                default:
                    phrasesByFirstWord[term[0], default: []].append(term)
                }
            }
        }

        func matches(_ textTokens: [String]) -> Bool {
            if textTokens.contains(where: words.contains) { return true }
            if textTokens.contains(where: { token in substringWords.contains { token.contains($0) } }) { return true }
            guard !phrasesByFirstWord.isEmpty else { return false }
            for start in textTokens.indices {
                guard let phrases = phrasesByFirstWord[textTokens[start]] else { continue }
                for phrase in phrases where start + phrase.count <= textTokens.count {
                    if phrase.indices.allSatisfy({ textTokens[start + $0] == phrase[$0] }) { return true }
                }
            }
            return false
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
