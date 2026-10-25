/**
 * Bundled seed for the content filter, used when Remote Config has no `content_filter_terms` /
 * `content_filter_trading_terms`. Must stay identical to the app's `GatorPlate/Resources/content-filter-seed.json`
 * (a test compares them). The owner extends the lists in Remote Config; no build or deploy needed.
 *
 * Food words never go here: "nuts", "buns", "breast", "balls", "sausage", "wiener", "cracker", "naked" (juice) and
 * "redskin" (potatoes) all collide with real posts. Terms of 6+ letters also match inside words, so check those
 * against food words too, and run the shared fixture before adding anything.
 */
export const SEED_TERMS: readonly string[] = [
  // Profanity
  "fuck", "fucks", "fucker", "fuckers", "fucking", "fucked", "fuckface", "fuckhead", "motherfucker", "motherfuckers",
  "shit", "shits", "shitty", "shithead", "shitface", "bullshit", "horseshit", "dipshit",
  "bitch", "bitches", "bitchy", "son of a bitch", "bastard", "bastards",
  "ass", "asses", "asshole", "assholes", "arsehole", "dumbass", "jackass", "smartass",
  "piss off", "prick", "pricks", "dickhead", "dickheads", "dickface",
  "cock", "cocks", "cocksucker", "cocksuckers", "cunt", "cunts", "twat", "twats",
  "wank", "wanker", "wankers", "bollocks", "bellend", "douche", "douchebag", "douchebags", "scumbag",
  // Sexual
  "skank", "skanky", "slut", "sluts", "slutty", "whore", "whores", "thot", "thots",
  "tits", "titties", "boobs", "boobies", "nipple", "nipples", "pussy", "pussies",
  "penis", "penises", "vagina", "vaginas", "anus", "anal", "butthole", "buttplug",
  "dildo", "dildos", "vibrator", "porn", "porno", "pornography", "pornhub", "onlyfans",
  "nude", "nudes", "sex", "sexy", "sexting", "horny", "orgasm", "orgy",
  "blowjob", "blowjobs", "blow job", "handjob", "hand job", "rimjob",
  "cum", "cumshot", "jizz", "semen", "erection", "boner", "masturbate", "masturbating",
  "jerk off", "jack off", "milf", "hentai",
  // Slurs and hate
  "nigger", "niggers", "nigga", "niggas", "negro", "sandnigger", "jigaboo", "porch monkey", "coon", "coons",
  "chink", "chinks", "gook", "gooks", "zipperhead",
  "spic", "spics", "wetback", "wetbacks", "beaner", "beaners",
  "kike", "kikes", "raghead", "ragheads", "towelhead", "camel jockey", "paki", "pakis",
  "faggot", "faggots", "fag", "fags", "dyke", "dykes", "tranny", "trannies", "shemale",
  "retard", "retards", "retarded", "spaz", "honky", "squaw",
  "nazi", "nazis", "heil hitler", "sieg heil", "kkk", "white power",
  // Threats
  "kill yourself", "kys",
];

/** Prices and payment apps: posts must be free. `$5` and "5 bucks" are caught by a pattern, not this list. */
export const SEED_TRADING_TERMS: readonly string[] = [
  "venmo", "cash app", "cashapp", "zelle", "paypal", "for sale", "per slice", "per plate", "price", "pay me",
  "donation required",
];
