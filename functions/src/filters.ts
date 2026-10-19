/**
 * Alert filters ("What to alert me about"), stored at users/{uid}.alertFilters and chosen by each student for
 * themselves. Pure functions, mirrored in the app by `AlertFilterMatcher.swift`; both run the shared fixture
 * `test/fixtures/alert-filter-cases.json`. Matching is AND across categories, OR within one; an empty category
 * doesn't restrict. Malformed filters fall back to "all free food", so nobody silently loses alerts.
 */

/** Limits mirror AppConfig.alertFilter* in the app. Rules can't check list elements, so they're checked here. */
export const MAX_PLACES = 15;
export const MAX_FOODS = 10;
export const MAX_FOOD_LENGTH = 30;
export const MAX_PLACE_ID_LENGTH = 40;

export const DIETS = ["vegan", "vegetarian", "nonVegetarian"] as const;
export const ALLERGENS = ["milk", "eggs", "fish", "shellfish", "treeNuts", "peanuts", "wheat", "soy", "sesame"];

export type Diet = (typeof DIETS)[number];

/** Normalized custom filters. `null` everywhere below means "all free food". */
export interface AlertFilters {
  diets: Diet[];
  includeUnknownDiet: boolean;
  places: string[];
  avoidAllergens: string[];
  skipUnverifiedAllergens: boolean;
  foods: string[];
}

/** The post fields filters look at (Firestore field names and raw values). */
export interface FilterablePost {
  title?: unknown;
  description?: unknown;
  items?: unknown;
  overallDietary?: unknown;
  allergenWarnings?: unknown;
  buildingId?: unknown;
  locationName?: unknown;
  expiresAt?: unknown;
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((element) => typeof element === "string");
}

/** Missing fields take their defaults; a field of the wrong type makes the whole value malformed. */
function listField(raw: Record<string, unknown>, key: string): string[] | undefined {
  if (!(key in raw)) return [];
  const value = raw[key];
  return isStringArray(value) ? value : undefined;
}

function boolField(raw: Record<string, unknown>, key: string): boolean | undefined {
  if (!(key in raw)) return false;
  const value = raw[key];
  return typeof value === "boolean" ? value : undefined;
}

/** Custom filters, or `null` for "all" (mode "all", missing, or malformed). */
export function normalizeFilters(raw: unknown): AlertFilters | null {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) return null;
  const record = raw as Record<string, unknown>;
  if (record.mode !== "custom") return null;

  const diets = listField(record, "diets");
  const places = listField(record, "places");
  const avoidAllergens = listField(record, "avoidAllergens");
  const foods = listField(record, "foods");
  const includeUnknownDiet = boolField(record, "includeUnknownDiet");
  const skipUnverifiedAllergens = boolField(record, "skipUnverifiedAllergens");
  if (!diets || !places || !avoidAllergens || !foods
    || includeUnknownDiet === undefined || skipUnverifiedAllergens === undefined) return null;

  if (!diets.every((diet) => (DIETS as readonly string[]).includes(diet))) return null;
  if (!avoidAllergens.every((allergen) => ALLERGENS.includes(allergen))) return null;
  if (places.length > MAX_PLACES || !places.every((id) => id.length >= 1 && id.length <= MAX_PLACE_ID_LENGTH)) {
    return null;
  }
  const cleanFoods = foods.map((food) => food.trim());
  if (cleanFoods.length > MAX_FOODS
    || !cleanFoods.every((food) => food.length >= 1 && [...food].length <= MAX_FOOD_LENGTH)) return null;

  return {
    diets: diets as Diet[],
    includeUnknownDiet,
    places,
    avoidAllergens,
    skipUnverifiedAllergens,
    foods: cleanFoods,
  };
}

interface PostItem {
  name: string;
  dietary: string;
}

function postItems(post: FilterablePost): PostItem[] {
  const items = Array.isArray(post.items) ? post.items : [];
  const parsed = items.flatMap((item): PostItem[] => {
    if (typeof item !== "object" || item === null) return [];
    const record = item as Record<string, unknown>;
    return [{
      name: typeof record.name === "string" ? record.name : "",
      dietary: typeof record.dietary === "string" ? record.dietary : "unknown",
    }];
  });
  if (parsed.length > 0) return parsed;
  // No items: judge by the post's overall class.
  return [{ name: "", dietary: typeof post.overallDietary === "string" ? post.overallDietary : "unknown" }];
}

function stringList(value: unknown): string[] {
  return isStringArray(value) ? value : [];
}

/**
 * Lowercased words with diacritics removed ("Crème brûlée" -> ["creme", "brulee"]). Letters and digits only;
 * everything else separates words. The app's `AlertFilterMatcher.words` does the same.
 */
export function words(text: string): string[] {
  const folded = text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
  return folded.match(/[\p{L}\p{N}]+/gu) ?? [];
}

function sameWord(word: string, keyword: string): boolean {
  return word === keyword || word === keyword + "s" || word + "s" === keyword;
}

/**
 * True when the keyword's words appear in order as whole words in `text`. Case and diacritic insensitive;
 * a trailing "s" matches either way ("pizza" <-> "pizzas"), but "pie" never matches "pierogi".
 */
export function keywordMatches(keyword: string, text: string): boolean {
  const needle = words(keyword);
  if (needle.length === 0) return false;
  const haystack = words(text);
  for (let start = 0; start + needle.length <= haystack.length; start += 1) {
    if (needle.every((word, offset) => sameWord(haystack[start + offset], word))) return true;
  }
  return false;
}

/** Whether a post passes this user's filters. Quiet hours and author exclusion are applied before this. */
export function matchesFilters(post: FilterablePost, rawFilters: unknown): boolean {
  const filters = normalizeFilters(rawFilters);
  if (!filters) return true;

  const items = postItems(post);
  if (filters.diets.length > 0) {
    const allowed = new Set<string>();
    if (filters.diets.includes("vegan")) allowed.add("vegan");
    if (filters.diets.includes("vegetarian")) {
      allowed.add("vegan");
      allowed.add("vegetarian");
    }
    if (filters.diets.includes("nonVegetarian")) {
      allowed.add("nonVegetarian");
      allowed.add("mixed");
    }
    if (filters.includeUnknownDiet) allowed.add("unknown");
    if (!items.some((item) => allowed.has(item.dietary))) return false;
  }

  if (filters.places.length > 0) {
    if (typeof post.buildingId !== "string" || !filters.places.includes(post.buildingId)) return false;
  }

  const allergens = stringList(post.allergenWarnings);
  if (filters.avoidAllergens.some((allergen) => allergens.includes(allergen))) return false;
  if (filters.skipUnverifiedAllergens && allergens.length === 0) return false;

  if (filters.foods.length > 0) {
    const texts = [post.title, post.description, ...items.map((item) => item.name)]
      .filter((text): text is string => typeof text === "string");
    if (!filters.foods.some((food) => texts.some((text) => keywordMatches(food, text)))) return false;
  }
  return true;
}

export const CAMPUS_TIME_ZONE = "America/Los_Angeles";
export const MAX_SUBTITLE_LENGTH = 100;
const MAX_SUBTITLE_PLACE_LENGTH = 40;

/** "Vegan", "Vegetarian", "Vegan options", "Vegetarian options", or null when nothing is vegetarian. */
export function dietPhrase(post: FilterablePost): string | null {
  const diets = postItems(post).map((item) => item.dietary);
  const veg = diets.filter((diet) => diet === "vegan" || diet === "vegetarian");
  if (veg.length === 0) return null;
  const allVegan = veg.every((diet) => diet === "vegan");
  if (veg.length === diets.length) return allVegan ? "Vegan" : "Vegetarian";
  return allVegan ? "Vegan options" : "Vegetarian options";
}

function expiryDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (typeof value === "object" && value !== null && "toMillis" in value
    && typeof (value as { toMillis: unknown }).toMillis === "function") {
    return new Date((value as { toMillis: () => number }).toMillis());
  }
  return null;
}

/**
 * The APNs subtitle, built only from post facts and the same for every recipient (never from anyone's filters):
 * "Vegetarian options · Student Services Building · until 7:40 PM".
 */
export function alertSubtitle(post: FilterablePost, timeZone: string = CAMPUS_TIME_ZONE): string | null {
  const parts: string[] = [];
  const diet = dietPhrase(post);
  if (diet) parts.push(diet);
  if (typeof post.locationName === "string") {
    const place = post.locationName.replace(/\s+/g, " ").trim();
    if (place) parts.push([...place].length > MAX_SUBTITLE_PLACE_LENGTH
      ? [...place].slice(0, MAX_SUBTITLE_PLACE_LENGTH - 1).join("").trimEnd() + "…"
      : place);
  }
  const expires = expiryDate(post.expiresAt);
  if (expires) {
    const time = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", timeZone }).format(expires);
    parts.push(`until ${time}`);
  }
  if (parts.length === 0) return null;
  const subtitle = parts.join(" · ");
  const characters = [...subtitle];
  return characters.length <= MAX_SUBTITLE_LENGTH
    ? subtitle
    : characters.slice(0, MAX_SUBTITLE_LENGTH - 1).join("").trimEnd() + "…";
}
