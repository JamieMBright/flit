/// Difficulty scoring system for clue types and countries.
///
/// Each country has a base recognisability rating (0.0 = universally known,
/// 1.0 = extremely obscure). Each clue type has a difficulty weight reflecting
/// how hard that category is in general. The combined score drives:
///
///   - **Free flight filtering** — Easy/Normal/Hard pools
///   - **Daily scramble difficulty %** — 0-100 rating shown to players
///   - **Score multipliers** — Harder rounds are worth more
///
/// Admin can override per-country ratings via Supabase; the static map below
/// provides compiled-in defaults so seeded challenges stay deterministic even
/// when offline.

import '../clues/clue_types.dart';

// ─── Clue-type difficulty weights ──────────────────────────────────────────
//
// Ordered easiest → hardest:  borders < flag < capital < stats < outline
// Values are 0.0–1.0 and represent the inherent difficulty of the clue
// category regardless of which country is being asked about.

/// Difficulty weight for each [ClueType].
///
/// These weights are combined with per-country recognisability to produce a
/// round difficulty score.
const Map<ClueType, double> clueTypeDifficulty = {
  ClueType.borders: 0.10, // Neighbour names — easiest
  ClueType.flag: 0.30, // Visual flag identification
  ClueType.capital: 0.50, // Capital city knowledge
  ClueType.stats: 0.70, // Population / area / GDP
  ClueType.outline: 0.90, // Silhouette only — hardest
};

/// Human-readable label for each clue type difficulty tier.
const Map<ClueType, String> clueTypeDifficultyLabel = {
  ClueType.borders: 'Tailwind',
  ClueType.flag: 'Fair Weather',
  ClueType.capital: 'Crosswinds',
  ClueType.stats: 'Turbulence',
  ClueType.outline: 'Storm Front',
};

// ─── Flight-themed difficulty bands ────────────────────────────────────────
//
// Used to label the 0–100% combined difficulty on the daily scramble screen
// and in round summaries. Each band maps a range to an evocative name.

/// Returns a flight-themed label for a 0.0–1.0 difficulty fraction.
String difficultyLabel(double fraction) {
  if (fraction <= 0.15) return 'Clear Skies';
  if (fraction <= 0.30) return 'Tailwind';
  if (fraction <= 0.45) return 'Fair Weather';
  if (fraction <= 0.60) return 'Crosswinds';
  if (fraction <= 0.75) return 'Turbulence';
  if (fraction <= 0.90) return 'Storm Front';
  return 'Cat-5 Headwind';
}

/// Returns a colour-associated index (0–6) for the difficulty band.
/// Useful for mapping to a gradient from green → red in UI.
int difficultyBandIndex(double fraction) {
  if (fraction <= 0.15) return 0;
  if (fraction <= 0.30) return 1;
  if (fraction <= 0.45) return 2;
  if (fraction <= 0.60) return 3;
  if (fraction <= 0.75) return 4;
  if (fraction <= 0.90) return 5;
  return 6;
}

// ─── Combined difficulty scoring ───────────────────────────────────────────

/// Compute the combined difficulty for a single round.
///
/// Formula:  `(clueWeight + countryDifficulty) / 2`
///
/// Both inputs are 0.0–1.0, so the result is also 0.0–1.0.
/// The easiest possible round (borders + USA) → ~0.05
/// The hardest possible round (outline + Nauru) → ~0.95
double roundDifficulty(ClueType clueType, String countryCode) {
  final clueWeight = clueTypeDifficulty[clueType] ?? 0.5;
  final countryRating = countryDifficultyRating(countryCode);
  return (clueWeight + countryRating) / 2.0;
}

/// Compute the daily scramble difficulty as a 0–100 integer percentage.
///
/// Takes a list of (clueType, countryCode) pairs — one per round — and
/// averages their individual round difficulties.
int dailyDifficultyPercent(List<(ClueType, String)> rounds) {
  if (rounds.isEmpty) return 50;
  double sum = 0;
  for (final (clue, country) in rounds) {
    sum += roundDifficulty(clue, country);
  }
  return (sum / rounds.length * 100).round().clamp(0, 100);
}

// ─── Per-country recognisability ratings ───────────────────────────────────
//
// Scale:  0.00 = universally recognised  →  1.00 = extremely obscure
//
// Tier guide:
//   0.00 – 0.15  Very Easy   — Global superpowers, iconic shapes
//   0.15 – 0.30  Easy        — Major nations, well-known in media
//   0.30 – 0.50  Medium      — Moderately known, studied in school
//   0.50 – 0.70  Hard        — Smaller / less-covered nations
//   0.70 – 0.85  Very Hard   — Small island states, micro-nations
//   0.85 – 1.00  Extreme     — Truly obscure territories
//
// Ratings consider: population, land area, outline distinctiveness, flag
// distinctiveness, capital familiarity, cultural/media presence, and
// educational frequency.

/// Look up the difficulty rating for a country code.
///
/// Returns the compiled-in default. Admin overrides are applied at the
/// service layer (see [DifficultyService]).
double countryDifficultyRating(String code) {
  return _defaultCountryDifficulty[code] ?? 0.55;
}

/// The full default difficulty map. Exposed for admin UI enumeration.
Map<String, double> get defaultCountryDifficulty =>
    Map.unmodifiable(_defaultCountryDifficulty);

const Map<String, double> _defaultCountryDifficulty = {
  // ── Very Easy (0.00–0.15) — Iconic, universally known ──────────────
  'US': 0.02, // United States — iconic outline, global superpower
  'CN': 0.04, // China — massive, distinctive shape
  'RU': 0.05, // Russia — largest country, unmistakable
  'AU': 0.05, // Australia — continent-country, iconic
  'BR': 0.06, // Brazil — huge, distinctive South America anchor
  'IN': 0.07, // India — subcontinent, very recognisable
  'CA': 0.08, // Canada — second-largest, iconic shape
  'GB': 0.08, // United Kingdom — island nation, culturally dominant
  'JP': 0.09, // Japan — archipelago, very well-known
  'FR': 0.10, // France — hexagon, cultural icon
  'IT': 0.10, // Italy — the boot, unmistakable
  'DE': 0.11, // Germany — central Europe anchor
  'MX': 0.12, // Mexico — distinctive shape, culturally prominent
  'EG': 0.12, // Egypt — Nile, pyramids, northeast Africa
  'ZA': 0.13, // South Africa — tip of Africa
  // ── Easy (0.15–0.30) — Major nations, well-known ───────────────────
  'ES': 0.15, // Spain — Iberian peninsula
  'KR': 0.16, // South Korea — Korean peninsula
  'AR': 0.17, // Argentina — long southern cone
  'SA': 0.17, // Saudi Arabia — large Arabian peninsula
  'TR': 0.18, // Turkey — Europe-Asia bridge
  'ID': 0.18, // Indonesia — world's largest archipelago
  'TH': 0.19, // Thailand — elephant-head shape
  'NG': 0.20, // Nigeria — Africa's most populous
  'SE': 0.20, // Sweden — Scandinavian peninsula
  'NO': 0.21, // Norway — fjord coast
  'PL': 0.22, // Poland — central Europe
  'GR': 0.22, // Greece — peninsula + islands, ancient history
  'NZ': 0.23, // New Zealand — two-island shape
  'CO': 0.23, // Colombia — northwest South America
  'PH': 0.24, // Philippines — archipelago, well-known
  'PK': 0.24, // Pakistan — large South Asian nation
  'IR': 0.25, // Iran — large Middle East nation
  'PE': 0.25, // Peru — western South America
  'UA': 0.26, // Ukraine — large European nation
  'CL': 0.26, // Chile — ultra-long thin strip
  'VE': 0.27, // Venezuela — northern South America
  'CU': 0.27, // Cuba — Caribbean's largest island
  'IE': 0.28, // Ireland — island, culturally prominent
  'IL': 0.28, // Israel — small but very well-known
  'FI': 0.28, // Finland — distinctive Scandinavian shape
  'PT': 0.29, // Portugal — western Iberian strip
  'CH': 0.29, // Switzerland — Alpine crossroads
  'DK': 0.30, // Denmark — Jutland peninsula
  'AT': 0.30, // Austria — Alpine central Europe
  // ── Medium (0.30–0.50) — Moderately known ─────────────────────────
  'BE': 0.31, // Belgium — small but culturally known
  'NL': 0.31, // Netherlands — flat, tulips, distinctive
  'CZ': 0.32, // Czech Republic — central Europe
  'RO': 0.33, // Romania — Balkans
  'HU': 0.33, // Hungary — central Europe
  'KE': 0.34, // Kenya — East Africa, safari icon
  'ET': 0.34, // Ethiopia — Horn of Africa
  'MA': 0.35, // Morocco — northwest Africa
  'IQ': 0.35, // Iraq — Mesopotamia, well-known
  'AF': 0.36, // Afghanistan — frequently in news
  'MY': 0.36, // Malaysia — Southeast Asia
  'KP': 0.37, // North Korea — peninsula, very well-known
  'SG': 0.37, // Singapore — city-state, economically prominent
  'VN': 0.38, // Vietnam — S-shaped, historically significant
  'TZ': 0.38, // Tanzania — Kilimanjaro, East Africa
  'GL': 0.39, // Greenland — massive island
  'BD': 0.39, // Bangladesh — South Asia
  'LK': 0.39, // Sri Lanka — teardrop island
  'KZ': 0.40, // Kazakhstan — vast Central Asian nation
  'MM': 0.40, // Myanmar — Southeast Asia
  'DZ': 0.40, // Algeria — largest African country
  'SD': 0.41, // Sudan — large northeast Africa
  'GH': 0.41, // Ghana — West Africa, well-known
  'CR': 0.42, // Costa Rica — Central America
  'PA': 0.42, // Panama — canal, isthmus
  'EC': 0.42, // Ecuador — western South America
  'UY': 0.43, // Uruguay — small South American nation
  'JM': 0.43, // Jamaica — Caribbean island, culturally known
  'NP': 0.43, // Nepal — Himalayas, non-rectangular flag
  'LY': 0.44, // Libya — large North Africa
  'JO': 0.44, // Jordan — Middle East
  'CD': 0.44, // DR Congo — huge Central Africa
  'SY': 0.45, // Syria — Middle East, frequently in news
  'LB': 0.45, // Lebanon — cedar flag, small Middle East
  'HK': 0.45, // Hong Kong — city-territory
  'IS': 0.45, // Iceland — North Atlantic island
  'RS': 0.46, // Serbia — Balkans
  'PR': 0.46, // Puerto Rico — Caribbean US territory
  'HR': 0.46, // Croatia — Adriatic coast
  'TN': 0.47, // Tunisia — small North Africa
  'BO': 0.47, // Bolivia — landlocked South America
  'PY': 0.47, // Paraguay — landlocked South America
  'GT': 0.48, // Guatemala — Central America
  'DO': 0.48, // Dominican Republic — Caribbean
  'HN': 0.48, // Honduras — Central America
  'SV': 0.49, // El Salvador — smallest Central America
  'NI': 0.49, // Nicaragua — Central America
  'TW': 0.49, // Taiwan — island nation
  'BG': 0.50, // Bulgaria — Balkans
  // ── Hard (0.50–0.70) — Smaller / less-covered nations ─────────────
  'CM': 0.50, // Cameroon — West-Central Africa
  'AE': 0.50, // UAE — Persian Gulf, well-funded
  'KH': 0.51, // Cambodia — Southeast Asia
  'QA': 0.51, // Qatar — small Gulf state
  'UZ': 0.52, // Uzbekistan — Central Asia
  'LT': 0.52, // Lithuania — Baltic state
  'LV': 0.53, // Latvia — Baltic state
  'EE': 0.53, // Estonia — Baltic state
  'SI': 0.53, // Slovenia — small Alpine nation
  'SK': 0.54, // Slovakia — central Europe
  'BA': 0.54, // Bosnia — Balkans
  'AL': 0.55, // Albania — Balkans
  'MK': 0.55, // North Macedonia — Balkans
  'ME': 0.56, // Montenegro — Balkans
  'XK': 0.56, // Kosovo — Balkans
  'CY': 0.56, // Cyprus — Mediterranean island
  'MN': 0.57, // Mongolia — vast steppe
  'LA': 0.57, // Laos — landlocked Southeast Asia
  'OM': 0.57, // Oman — Arabian peninsula
  'KW': 0.58, // Kuwait — small Gulf state
  'BH': 0.58, // Bahrain — tiny Gulf island
  'PS': 0.58, // Palestine — small Middle East
  'LU': 0.58, // Luxembourg — tiny European state
  'MG': 0.59, // Madagascar — large island
  'ML': 0.59, // Mali — large West Africa
  'BF': 0.59, // Burkina Faso — West Africa
  'SN': 0.60, // Senegal — West Africa
  'NE': 0.60, // Niger — large Sahel
  'TD': 0.60, // Chad — large Central Africa
  'CI': 0.61, // Ivory Coast — West Africa
  'MZ': 0.61, // Mozambique — southeast Africa
  'MW': 0.62, // Malawi — small southeast Africa
  'ZM': 0.62, // Zambia — southern Africa
  'ZW': 0.62, // Zimbabwe — southern Africa
  'BW': 0.63, // Botswana — southern Africa
  'NA': 0.63, // Namibia — southwest Africa
  'AO': 0.63, // Angola — southwest Africa
  'UG': 0.64, // Uganda — East Africa
  'RW': 0.64, // Rwanda — small East Africa
  'TJ': 0.64, // Tajikistan — Central Asia
  'KG': 0.64, // Kyrgyzstan — Central Asia
  'TM': 0.65, // Turkmenistan — Central Asia
  'GE': 0.65, // Georgia — Caucasus
  'AM': 0.65, // Armenia — Caucasus
  'AZ': 0.66, // Azerbaijan — Caucasus
  'MD': 0.66, // Moldova — small Eastern Europe
  'BY': 0.66, // Belarus — Eastern Europe
  'PG': 0.67, // Papua New Guinea — large Pacific island
  'FJ': 0.67, // Fiji — Pacific islands
  'HT': 0.67, // Haiti — Caribbean
  'TT': 0.68, // Trinidad and Tobago — Caribbean
  'BS': 0.68, // Bahamas — Caribbean archipelago
  'GY': 0.68, // Guyana — northeast South America
  'SR': 0.68, // Suriname — northeast South America
  'BZ': 0.69, // Belize — Central America
  'BB': 0.69, // Barbados — Caribbean island
  'GN': 0.69, // Guinea — West Africa
  'SL': 0.70, // Sierra Leone — West Africa
  'LR': 0.70, // Liberia — West Africa
  // ── Very Hard (0.70–0.85) — Small / island states, micro-nations ──
  'MT': 0.70, // Malta — tiny Mediterranean island
  'CG': 0.71, // Congo Republic — Central Africa
  'DJ': 0.71, // Djibouti — Horn of Africa
  'ER': 0.71, // Eritrea — Horn of Africa
  'CF': 0.72, // Central African Republic
  'SO': 0.72, // Somalia — Horn of Africa
  'SS': 0.72, // South Sudan — newest country
  'BI': 0.73, // Burundi — tiny East Africa
  'MR': 0.73, // Mauritania — large Saharan
  'TG': 0.73, // Togo — thin West Africa strip
  'BJ': 0.73, // Benin — thin West Africa strip
  'GA': 0.74, // Gabon — Central Africa
  'GQ': 0.74, // Equatorial Guinea — tiny Central Africa
  'LS': 0.74, // Lesotho — enclave in South Africa
  'SZ': 0.75, // Eswatini — tiny southern Africa
  'GM': 0.75, // Gambia — river enclave in Senegal
  'GW': 0.75, // Guinea-Bissau — tiny West Africa
  'CV': 0.76, // Cape Verde — Atlantic island chain
  'MU': 0.76, // Mauritius — Indian Ocean island
  'EH': 0.76, // Western Sahara — disputed territory
  'BT': 0.77, // Bhutan — tiny Himalayan kingdom
  'MV': 0.77, // Maldives — Indian Ocean atolls
  'TL': 0.77, // Timor-Leste — half-island Southeast Asia
  'WS': 0.78, // Samoa — Pacific island
  'BN': 0.78, // Brunei — tiny Borneo enclave
  'GD': 0.78, // Grenada — Caribbean spice island
  'AG': 0.79, // Antigua and Barbuda — Caribbean
  'DM': 0.79, // Dominica — Caribbean (often confused with DR)
  'LC': 0.79, // Saint Lucia — Caribbean
  'KN': 0.80, // Saint Kitts and Nevis — Caribbean
  'VC': 0.80, // Saint Vincent — Caribbean
  'SC': 0.80, // Seychelles — Indian Ocean
  'AW': 0.80, // Aruba — Caribbean island
  'CW': 0.81, // Curaçao — Caribbean island
  'MO': 0.81, // Macau — tiny Chinese territory
  'GI': 0.81, // Gibraltar — tiny British peninsula
  'SM': 0.82, // San Marino — micro-state in Italy
  'LI': 0.82, // Liechtenstein — tiny Alpine state
  'MC': 0.82, // Monaco — tiny Mediterranean state
  'AD': 0.83, // Andorra — tiny Pyrenees state
  'IM': 0.83, // Isle of Man — British Crown dependency
  'GG': 0.83, // Guernsey — Channel Island
  'JE': 0.83, // Jersey — Channel Island
  'FO': 0.84, // Faroe Islands — North Atlantic
  'AX': 0.84, // Åland Islands — Baltic Finnish
  'BM': 0.84, // Bermuda — Atlantic island
  'FK': 0.84, // Falkland Islands — South Atlantic
  // ── Extreme (0.85–1.00) — Truly obscure ──────────────────────────
  'NC': 0.85, // New Caledonia — French Pacific
  'GU': 0.85, // Guam — US Pacific territory
  'VA': 0.85, // Vatican City — micro-state
  'CK': 0.86, // Cook Islands — Pacific
  'KI': 0.87, // Kiribati — scattered Pacific atolls
  'TO': 0.87, // Tonga — Pacific kingdom
  'FM': 0.88, // Micronesia — Pacific
  'MH': 0.88, // Marshall Islands — Pacific atolls
  'SB': 0.88, // Solomon Islands — Pacific
  'VU': 0.89, // Vanuatu — Pacific
  'NR': 0.90, // Nauru — smallest island republic
  'TV': 0.91, // Tuvalu — tiny Pacific
  'PW': 0.92, // Palau — Pacific (confusable)
  'KM': 0.92, // Comoros — Indian Ocean
  'ST': 0.93, // São Tomé and Príncipe — Gulf of Guinea
  // Non-playable excluded: AI, AQ, AS, MS, NF, NU, PM, PN, SH, UM, VG, WF

  // ── Regional / special codes ───────────────────────────────────────
  'XC': 0.80, // Cocos (Keeling) Islands
  'XS': 0.85, // Somaliland
};

// ─── Free-flight difficulty tiers ──────────────────────────────────────────

/// Difficulty tier for free flight mode filtering.
///
/// Maps the three [GameDifficulty] levels to country difficulty thresholds.
/// Countries whose rating falls within the range are included in the pool.

/// Maximum country difficulty for the "easy" (Clear Skies) pool.
const double easyThreshold = 0.35;

/// Maximum country difficulty for the "normal" (Crosswinds) pool.
/// (No minimum — includes easy countries too.)
const double normalThreshold = 0.70;

/// Minimum country difficulty for the "hard" (Headwinds) pool.
/// (No maximum — goes to 1.0.)
const double hardMinimum = 0.45;
