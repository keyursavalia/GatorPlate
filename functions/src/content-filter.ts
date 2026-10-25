/**
 * Text filter for posts and names. Pure; the same algorithm as the app's `ContentFilter.swift`, and both pass the
 * shared fixture `test/fixtures/content-filter-cases.json`.
 *
 * Normalization: lowercase, fold diacritics, map leetspeak (0→o 1→i 3→e 4→a 5→s 7→t @→a $→s), turn non-letters
 * into spaces, cut runs of 3+ repeated letters to 2, split into tokens.
 * Matching: a one-word term matches a whole token, or anywhere inside a token when it has 6+ letters; a multi-word
 * term matches consecutive tokens. Trading also matches a price ("$5", "5 bucks", "10 dollars") on the original text.
 * Blocked words win over trading when both match.
 */

export type FilterVerdict = "terms" | "trading";

const LEET: Readonly<Record<string, string>> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s" };
/** One-word terms this long also match inside a token (compounds like "superbitchy"). */
const SUBSTRING_MIN_LETTERS = 6;
const PRICE_PATTERNS = [/\$\s?\d/, /\d\s?(dollars?|bucks)/i];

/** Normalized tokens of `text` (see the file comment). */
export function tokens(text: string): string[] {
  const folded = text.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
  let out = "";
  let last = "";
  let run = 0;
  for (const raw of folded) {
    const char = LEET[raw] ?? raw;
    if (/\p{L}/u.test(char)) {
      if (char === last) {
        run += 1;
      } else {
        last = char;
        run = 1;
      }
      if (run <= 2) out += char;
    } else {
      out += " ";
      last = "";
      run = 0;
    }
  }
  return out.split(" ").filter((token) => token.length > 0);
}

function matchesAny(textTokens: readonly string[], terms: readonly (readonly string[])[]): boolean {
  return terms.some((term) => {
    if (term.length === 1) {
      const word = term[0];
      const allowSubstring = [...word].length >= SUBSTRING_MIN_LETTERS;
      return textTokens.some((token) => token === word || (allowSubstring && token.includes(word)));
    }
    for (let start = 0; start + term.length <= textTokens.length; start += 1) {
      if (term.every((word, offset) => textTokens[start + offset] === word)) return true;
    }
    return false;
  });
}

export function hasPrice(text: string): boolean {
  return PRICE_PATTERNS.some((pattern) => pattern.test(text));
}

export class ContentFilter {
  private readonly terms: string[][];
  private readonly tradingTerms: string[][];

  /** Term lists are normalized once; empty terms are dropped. */
  constructor(terms: readonly string[], tradingTerms: readonly string[]) {
    this.terms = terms.map(tokens).filter((term) => term.length > 0);
    this.tradingTerms = tradingTerms.map(tokens).filter((term) => term.length > 0);
  }

  check(text: string): FilterVerdict | null {
    const textTokens = tokens(text);
    if (matchesAny(textTokens, this.terms)) return "terms";
    if (hasPrice(text) || matchesAny(textTokens, this.tradingTerms)) return "trading";
    return null;
  }
}

/** Post fields the server checks, in the app's order: title, description, items, cautions, place detail, names. */
export function postTexts(post: Record<string, unknown>): string[] {
  const text = (value: unknown) => (typeof value === "string" ? [value] : []);
  const items = Array.isArray(post.items)
    ? post.items.flatMap((item) =>
      typeof item === "object" && item !== null ? text((item as { name?: unknown }).name) : [])
    : [];
  const cautions = Array.isArray(post.cautions) ? post.cautions.flatMap(text) : [];
  return [
    ...text(post.title), ...text(post.description), ...items, ...cautions, ...text(post.locationDetail),
    ...text(post.authorName), ...text(post.orgName),
  ];
}

/** The first verdict over a post's texts, or null when every field passes. */
export function checkPost(filter: ContentFilter, post: Record<string, unknown>): FilterVerdict | null {
  for (const text of postTexts(post)) {
    const verdict = filter.check(text);
    if (verdict) return verdict;
  }
  return null;
}
