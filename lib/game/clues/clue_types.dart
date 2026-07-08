import 'dart:math';

import 'package:flame/components.dart';

import '../data/canada_clues.dart';
import '../data/ireland_clues.dart';
import '../data/uk_clues.dart';
import '../data/us_state_clues.dart';
import '../map/country_data.dart';
import '../map/region.dart';
import 'country_stats_data.dart';

/// Types of clues that can be shown to the player.
enum ClueType {
  flag,
  outline,
  borders,
  capital,
  stats,
  // Regional clue types
  sportsTeam,
  leader,
  nickname,
  landmark,
  flagDescription,
}

/// A clue for the player to guess the target country.
class Clue {
  const Clue({
    required this.type,
    required this.targetCountryCode,
    required this.displayData,
  });

  final ClueType type;
  final String targetCountryCode;
  final Map<String, dynamic> displayData;

  /// Create a flag clue
  factory Clue.flag(String countryCode) {
    return Clue(
      type: ClueType.flag,
      targetCountryCode: countryCode,
      // The flag is drawn by the CountryFlag widget from targetCountryCode;
      // no emoji is stored here.
      displayData: const <String, dynamic>{},
    );
  }

  /// Create an outline clue (silhouette)
  factory Clue.outline(String countryCode) {
    final country = CountryData.getCountry(countryCode);
    return Clue(
      type: ClueType.outline,
      targetCountryCode: countryCode,
      displayData: {'polygons': country?.polygons ?? <List<Vector2>>[]},
    );
  }

  /// Create a borders clue (list of neighboring countries)
  factory Clue.borders(String countryCode) {
    return Clue(
      type: ClueType.borders,
      targetCountryCode: countryCode,
      displayData: {'neighbors': _getNeighboringCountries(countryCode)},
    );
  }

  /// Create a capital clue
  factory Clue.capital(String countryCode) {
    final capital = CountryData.getCapital(countryCode);
    // If no capital data available, this will be caught by validation
    return Clue(
      type: ClueType.capital,
      targetCountryCode: countryCode,
      displayData: {'capitalName': capital?.name ?? ''},
    );
  }

  /// Create a stats clue
  ///
  /// When [random] is provided (e.g. from a seeded H2H game), the same trio
  /// of stats will be selected deterministically for both players.
  factory Clue.stats(String countryCode, {Random? random}) {
    return Clue(
      type: ClueType.stats,
      targetCountryCode: countryCode,
      displayData: _getCountryStats(countryCode, random: random),
    );
  }

  /// Generate a random clue for a country, with validation to avoid "Unknown" data.
  ///
  /// When [allowedTypes] is provided (e.g. from a daily challenge theme),
  /// only those clue types will be considered. This overrides the
  /// [preferredClueType] mechanism.
  ///
  /// When [preferredClueType] is provided, the preferred type has a bonus
  /// chance of being selected.
  factory Clue.random(
    String countryCode, {
    String? preferredClueType,
    Set<String>? allowedTypes,
    Random? random,
    int clueChance = 0,
  }) {
    // Determine the pool of clue types to draw from.
    final List<ClueType> typePool;
    if (allowedTypes != null && allowedTypes.isNotEmpty) {
      typePool =
          ClueType.values.where((t) => allowedTypes.contains(t.name)).toList();
    } else {
      typePool = ClueType.values.toList();
    }
    // If the filter left nothing valid, fall back to all types.
    final types = typePool.isEmpty ? ClueType.values : typePool;
    final rng = random ?? Random();
    final triedTypes = <ClueType>{};
    const maxRetries = 10;

    // Resolve preferred ClueType enum from the string name.
    ClueType? preferredType;
    if (preferredClueType != null) {
      for (final t in types) {
        if (t.name == preferredClueType) {
          preferredType = t;
          break;
        }
      }
    }

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      // Get available types that haven't been tried yet
      final availableTypes =
          types.where((t) => !triedTypes.contains(t)).toList();
      if (availableTypes.isEmpty) break;

      ClueType randomType;
      // If we have a preferred type and it hasn't been tried, give it a
      // base 25% chance of being picked directly, boosted by the pilot
      // license's clueChance stat.
      final preferredPct = (25 + clueChance).clamp(0, 100);
      if (preferredType != null &&
          availableTypes.contains(preferredType) &&
          rng.nextInt(100) < preferredPct) {
        randomType = preferredType;
      } else {
        randomType = availableTypes[rng.nextInt(availableTypes.length)];
      }
      triedTypes.add(randomType);

      Clue clue;
      switch (randomType) {
        case ClueType.flag:
          clue = Clue.flag(countryCode);
          break;
        case ClueType.outline:
          clue = Clue.outline(countryCode);
          break;
        case ClueType.borders:
          clue = Clue.borders(countryCode);
          break;
        case ClueType.capital:
          clue = Clue.capital(countryCode);
          break;
        case ClueType.stats:
          clue = Clue.stats(countryCode, random: random);
          break;
        // Regional types fallback to stats for world mode
        case ClueType.sportsTeam:
        case ClueType.leader:
        case ClueType.nickname:
        case ClueType.landmark:
        case ClueType.flagDescription:
          clue = Clue.stats(countryCode, random: random);
          break;
      }

      // Validate the clue - if valid, return it
      if (_isValidClue(clue)) {
        return clue;
      }
    }

    // Fallback: try each allowed type in order (flag is most reliable).
    // If allowedTypes restricts the pool, try those first before flag.
    for (final fallbackType in types) {
      final fallbackClue = _buildClue(fallbackType, countryCode, random);
      if (_isValidClue(fallbackClue)) return fallbackClue;
    }
    // Absolute last resort.
    return Clue.flag(countryCode);
  }

  /// Build a [Clue] from a [ClueType] for the given country.
  static Clue _buildClue(ClueType type, String code, Random? random) {
    switch (type) {
      case ClueType.flag:
        return Clue.flag(code);
      case ClueType.outline:
        return Clue.outline(code);
      case ClueType.borders:
        return Clue.borders(code);
      case ClueType.capital:
        return Clue.capital(code);
      case ClueType.stats:
        return Clue.stats(code, random: random);
      case ClueType.sportsTeam:
      case ClueType.leader:
      case ClueType.nickname:
      case ClueType.landmark:
      case ClueType.flagDescription:
        return Clue.stats(code, random: random);
    }
  }

  /// Create a clue for a regional area (state, county, island).
  ///
  /// Uses rich data from regional clue databases when available. Randomly
  /// selects from all available clue types for the region.
  factory Clue.regionalArea(RegionalArea area, {GameRegion? region}) {
    final random = Random();
    final availableClues = <Clue>[];

    // Always available: outline and capital
    availableClues.add(
      Clue(
        type: ClueType.outline,
        targetCountryCode: area.code,
        displayData: {'points': area.points, 'areaName': area.name},
      ),
    );

    if (area.capital != null &&
        area.capital!.isNotEmpty &&
        !area.capital!.toLowerCase().contains('unknown')) {
      availableClues.add(
        Clue(
          type: ClueType.capital,
          targetCountryCode: area.code,
          displayData: {
            'capitalName': area.capital ?? '',
            'areaName': area.name,
          },
        ),
      );
    }

    if (area.population != null && area.population! > 0) {
      final pop = area.population!;
      final popString = pop >= 1000000
          ? '${(pop / 1000000).toStringAsFixed(1)}M'
          : pop >= 1000
              ? '${(pop / 1000).toStringAsFixed(0)}K'
              : pop.toString();
      availableClues.add(
        Clue(
          type: ClueType.stats,
          targetCountryCode: area.code,
          displayData: {
            'population': popString,
            'areaName': area.name,
            if (area.funFact != null) 'funFact': area.funFact,
          },
        ),
      );
    }

    // Rich regional clue data from data files
    if (region == GameRegion.usStates) {
      _addUsStateClues(area.code, availableClues);
    } else if (region == GameRegion.ireland) {
      _addIrelandClues(area.code, availableClues);
    } else if (region == GameRegion.ukCounties) {
      _addUkClues(area.code, availableClues);
    } else if (region == GameRegion.canadianProvinces) {
      _addCanadaClues(area.code, availableClues);
    }

    return availableClues[random.nextInt(availableClues.length)];
  }

  /// Add US state-specific clues from the data file.
  static void _addUsStateClues(String code, List<Clue> clues) {
    final data = UsStateClues.data[code];
    if (data == null) return;

    if (data.sportsTeams.isNotEmpty) {
      final team = data.sportsTeams[Random().nextInt(data.sportsTeams.length)];
      clues.add(
        Clue(
          type: ClueType.sportsTeam,
          targetCountryCode: code,
          displayData: {'team': team},
        ),
      );
    }
    if (data.senators.isNotEmpty) {
      clues.add(
        Clue(
          type: ClueType.leader,
          targetCountryCode: code,
          displayData: {'leader': 'Senator: ${data.senators.join(', ')}'},
        ),
      );
    }
    clues.add(
      Clue(
        type: ClueType.nickname,
        targetCountryCode: code,
        displayData: {'nickname': data.nickname},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.landmark,
        targetCountryCode: code,
        displayData: {'landmark': data.famousLandmark},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.flagDescription,
        targetCountryCode: code,
        displayData: {'flagDesc': data.flag},
      ),
    );
  }

  /// Add Ireland county-specific clues.
  static void _addIrelandClues(String code, List<Clue> clues) {
    final data = IrelandClues.data[code];
    if (data == null) return;

    clues.add(
      Clue(
        type: ClueType.nickname,
        targetCountryCode: code,
        displayData: {'nickname': '${data.nickname} (${data.province})'},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.landmark,
        targetCountryCode: code,
        displayData: {'landmark': data.famousLandmark},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.sportsTeam,
        targetCountryCode: code,
        displayData: {'team': 'GAA: ${data.gaaTeam}'},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.leader,
        targetCountryCode: code,
        displayData: {'leader': data.famousPerson},
      ),
    );
  }

  /// Add UK county-specific clues.
  static void _addUkClues(String code, List<Clue> clues) {
    final data = UkClues.data[code];
    if (data == null) return;

    clues.add(
      Clue(
        type: ClueType.sportsTeam,
        targetCountryCode: code,
        displayData: {'team': data.footballTeam},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.landmark,
        targetCountryCode: code,
        displayData: {'landmark': data.famousLandmark},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.leader,
        targetCountryCode: code,
        displayData: {'leader': data.famousPerson},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.nickname,
        targetCountryCode: code,
        displayData: {'nickname': '${data.nickname} (${data.country})'},
      ),
    );
  }

  /// Add Canadian province-specific clues.
  static void _addCanadaClues(String code, List<Clue> clues) {
    final data = CanadaClues.data[code];
    if (data == null) return;

    if (data.sportsTeams.isNotEmpty) {
      final team = data.sportsTeams[Random().nextInt(data.sportsTeams.length)];
      clues.add(
        Clue(
          type: ClueType.sportsTeam,
          targetCountryCode: code,
          displayData: {'team': team},
        ),
      );
    }
    clues.add(
      Clue(
        type: ClueType.leader,
        targetCountryCode: code,
        displayData: {'leader': 'Premier: ${data.premier}'},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.nickname,
        targetCountryCode: code,
        displayData: {'nickname': data.nickname},
      ),
    );
    clues.add(
      Clue(
        type: ClueType.landmark,
        targetCountryCode: code,
        displayData: {'landmark': data.famousLandmark},
      ),
    );
  }

  /// Get the display text for this clue
  String get displayText {
    switch (type) {
      case ClueType.flag:
        // Flag is rendered by the CountryFlag widget; this text is a latent
        // label only, never an emoji.
        return CountryData.getCountry(targetCountryCode)?.name ?? '';
      case ClueType.outline:
        return '[Country Outline]';
      case ClueType.borders:
        final neighbors = displayData['neighbors'] as List<String>;
        return 'Borders: ${neighbors.join(', ')}';
      case ClueType.capital:
        return 'Capital: ${displayData['capitalName']}';
      case ClueType.stats:
        return _formatStats(displayData);
      case ClueType.sportsTeam:
        return displayData['team'] as String;
      case ClueType.leader:
        return displayData['leader'] as String;
      case ClueType.nickname:
        return displayData['nickname'] as String;
      case ClueType.landmark:
        return displayData['landmark'] as String;
      case ClueType.flagDescription:
        return displayData['flagDesc'] as String;
    }
  }

  String _formatStats(Map<String, dynamic> stats) {
    final labels = <String, String>{
      'population': 'Pop',
      'continent': 'Continent',
      'language': 'Predominant language',
      'currency': 'Currency',
      'religion': 'Predominant religion',
      'headOfState': 'Leader',
      'sport': 'Sport',
      'celebrity': 'Celebrity',
      'funFact': 'Fun fact',
      'areaName': 'Area',
    };
    final lines = <String>[];
    for (final entry in stats.entries) {
      if (entry.key == 'areaName') continue; // skip internal key
      final label = labels[entry.key] ?? entry.key;
      lines.add('$label: ${entry.value}');
    }
    return lines.join('\n');
  }

  /// Validates that a clue has proper data and doesn't contain "Unknown" or empty values
  static bool _isValidClue(Clue clue) {
    switch (clue.type) {
      case ClueType.flag:
        // Flag clues are always valid
        return true;
      case ClueType.outline:
        // Check if polygons/points exist and have enough vertices to be
        // recognisable. Below ~50 total vertices a silhouette is a featureless
        // blob (San Marino 19, Aruba 25, Barbados 28, Malta 43 — unguessable
        // ovals), while genuinely simple-but-recognisable large countries sit
        // safely above it (Somalia 71, Libya 105). Countries failing the bar
        // fall back to their other clue types via the capability filter —
        // strictly better than serving an unidentifiable landmass.
        const minOutlineVertices = 50;
        final polygons = clue.displayData['polygons'] as List?;
        final points = clue.displayData['points'] as List?;
        if (polygons != null && polygons.isNotEmpty) {
          var totalVertices = 0;
          for (final poly in polygons) {
            totalVertices += (poly as List).length;
          }
          return totalVertices >= minOutlineVertices;
        }
        if (points != null && points.length >= minOutlineVertices) return true;
        return false;
      case ClueType.borders:
        // Check if neighbors list exists and is not empty
        final neighbors = clue.displayData['neighbors'] as List<String>?;
        if (neighbors == null || neighbors.isEmpty) return false;
        // Ensure no "Unknown" values in neighbor names
        return !neighbors.any((n) => n.toLowerCase().contains('unknown'));
      case ClueType.capital:
        // Check if capital name exists and is not empty or "Unknown"
        final capitalName = clue.displayData['capitalName'] as String?;
        if (capitalName == null || capitalName.isEmpty) return false;
        return !capitalName.toLowerCase().contains('unknown');
      case ClueType.stats:
        // Check if stats map exists and is not empty
        if (clue.displayData.isEmpty) return false;
        // Ensure no "Unknown" values in stats
        for (final value in clue.displayData.values) {
          if (value == null) return false;
          final strValue = value.toString().toLowerCase();
          if (strValue.isEmpty || strValue.contains('unknown')) return false;
        }
        return true;
      case ClueType.sportsTeam:
        final team = clue.displayData['team'] as String?;
        return team != null && team.isNotEmpty;
      case ClueType.leader:
        final leader = clue.displayData['leader'] as String?;
        return leader != null && leader.isNotEmpty;
      case ClueType.nickname:
        final nick = clue.displayData['nickname'] as String?;
        return nick != null && nick.isNotEmpty;
      case ClueType.landmark:
        final lm = clue.displayData['landmark'] as String?;
        return lm != null && lm.isNotEmpty;
      case ClueType.flagDescription:
        final desc = clue.displayData['flagDesc'] as String?;
        return desc != null && desc.isNotEmpty;
    }
  }

  /// Whether [code] can honestly produce a clue of type [clueType].
  ///
  /// This is the public capability predicate used by the daily target selector
  /// to filter the candidate pool BEFORE the seeded pick, so a themed daily can
  /// never seed a target that can't satisfy its clue type (e.g. an island
  /// nation with no neighbours on Border Day, or the Vatican — a 7-vertex
  /// speck — on Outline Day). Without this filter, [Clue.random] silently falls
  /// back to a flag clue, a theme mismatch the player can't explain.
  ///
  /// It shares ONE source of truth with [_isValidClue]: it builds the real
  /// clue via [_buildClue] and validates it, so the two can never drift.
  /// Requirements per type therefore exactly mirror [_isValidClue]:
  ///   * `borders` → the country has at least one (non-"unknown") neighbour
  ///   * `outline` → the country's polygon has ≥10 total vertices
  ///   * `flag`    → always true
  ///   * `capital` → a non-empty, non-"unknown" capital exists
  ///   * `stats`   → the country has a populated stats entry
  ///
  /// The result is deterministic per (code, clueType) for the five world clue
  /// types: `flag`/`outline`/`borders`/`capital` build from static data, and
  /// while a `stats` clue draws a random trio, every field of a populated
  /// entry is valid, so validity itself is stable. Returns false for an
  /// unrecognised [clueType].
  static bool canProduceClueType(String code, String clueType) {
    ClueType? type;
    for (final t in ClueType.values) {
      if (t.name == clueType) {
        type = t;
        break;
      }
    }
    if (type == null) return false;
    return _isValidClue(_buildClue(type, code, null));
  }

  static List<String> _getNeighboringCountries(String code) {
    // Comprehensive neighbor data for ~85 countries
    const Map<String, List<String>> neighbors = {
      // ─── North America ───
      'US': ['Canada', 'Mexico'],
      'CA': ['United States'],
      'MX': ['United States', 'Guatemala', 'Belize'],
      'CU': <String>[],
      'GT': ['Mexico', 'Belize', 'Honduras', 'El Salvador'],
      'PA': ['Costa Rica', 'Colombia'],

      // ─── South America ───
      'BR': [
        'Argentina',
        'Paraguay',
        'Uruguay',
        'Bolivia',
        'Peru',
        'Colombia',
        'Venezuela',
        'Guyana',
        'Suriname',
        'French Guiana',
      ],
      'AR': ['Chile', 'Bolivia', 'Paraguay', 'Brazil', 'Uruguay'],
      'CO': ['Venezuela', 'Brazil', 'Peru', 'Ecuador', 'Panama'],
      'PE': ['Ecuador', 'Colombia', 'Brazil', 'Bolivia', 'Chile'],
      'CL': ['Peru', 'Bolivia', 'Argentina'],
      'VE': ['Colombia', 'Brazil', 'Guyana'],
      'EC': ['Colombia', 'Peru'],
      'UY': ['Argentina', 'Brazil'],
      'PY': ['Argentina', 'Brazil', 'Bolivia'],

      // ─── Western Europe ───
      'GB': ['Ireland'],
      'FR': [
        'Spain',
        'Belgium',
        'Luxembourg',
        'Germany',
        'Switzerland',
        'Italy',
        'Monaco',
        'Andorra',
      ],
      'DE': [
        'France',
        'Belgium',
        'Netherlands',
        'Luxembourg',
        'Poland',
        'Czech Republic',
        'Austria',
        'Switzerland',
        'Denmark',
      ],
      'IT': [
        'France',
        'Switzerland',
        'Austria',
        'Slovenia',
        'San Marino',
        'Vatican City',
      ],
      'ES': ['France', 'Portugal', 'Andorra', 'Gibraltar'],
      'PT': ['Spain'],
      'NL': ['Belgium', 'Germany'],
      'BE': ['France', 'Netherlands', 'Germany', 'Luxembourg'],
      'CH': ['Germany', 'France', 'Italy', 'Austria', 'Liechtenstein'],
      'AT': [
        'Germany',
        'Czech Republic',
        'Slovakia',
        'Hungary',
        'Slovenia',
        'Italy',
        'Switzerland',
        'Liechtenstein',
      ],
      'IE': ['United Kingdom'],

      // ─── Northern Europe ───
      'SE': ['Norway', 'Finland'],
      'NO': ['Sweden', 'Finland', 'Russia'],
      'FI': ['Sweden', 'Norway', 'Russia'],
      'DK': ['Germany'],

      // ─── Central & Eastern Europe ───
      'PL': [
        'Germany',
        'Czech Republic',
        'Slovakia',
        'Ukraine',
        'Belarus',
        'Lithuania',
        'Russia',
      ],
      'CZ': ['Germany', 'Poland', 'Slovakia', 'Austria'],
      'HU': [
        'Austria',
        'Slovakia',
        'Ukraine',
        'Romania',
        'Serbia',
        'Croatia',
        'Slovenia',
      ],
      'RO': ['Ukraine', 'Moldova', 'Hungary', 'Serbia', 'Bulgaria'],
      'BG': ['Romania', 'Serbia', 'North Macedonia', 'Greece', 'Turkey'],
      'HR': [
        'Slovenia',
        'Hungary',
        'Serbia',
        'Bosnia and Herzegovina',
        'Montenegro',
      ],
      'RS': [
        'Hungary',
        'Romania',
        'Bulgaria',
        'North Macedonia',
        'Kosovo',
        'Montenegro',
        'Bosnia and Herzegovina',
        'Croatia',
      ],
      'UA': [
        'Poland',
        'Slovakia',
        'Hungary',
        'Romania',
        'Moldova',
        'Russia',
        'Belarus',
      ],

      // ─── Southern Europe & Turkey ───
      'GR': ['Albania', 'North Macedonia', 'Bulgaria', 'Turkey'],
      'TR': [
        'Greece',
        'Bulgaria',
        'Georgia',
        'Armenia',
        'Azerbaijan',
        'Iran',
        'Iraq',
        'Syria',
      ],

      // ─── Russia ───
      'RU': [
        'Norway',
        'Finland',
        'Estonia',
        'Latvia',
        'Belarus',
        'Ukraine',
        'Georgia',
        'Azerbaijan',
        'Kazakhstan',
        'China',
        'Mongolia',
        'North Korea',
      ],

      // ─── North Africa ───
      'EG': ['Libya', 'Sudan', 'Israel', 'Palestine'],
      'MA': ['Algeria', 'Mauritania'],
      'DZ': ['Morocco', 'Tunisia', 'Libya', 'Niger', 'Mali', 'Mauritania'],
      'TN': ['Algeria', 'Libya'],
      'LY': ['Tunisia', 'Algeria', 'Niger', 'Chad', 'Sudan', 'Egypt'],

      // ─── East Africa ───
      'SD': [
        'Egypt',
        'Libya',
        'Chad',
        'Central African Republic',
        'South Sudan',
        'Ethiopia',
        'Eritrea',
      ],
      'ET': ['Eritrea', 'Djibouti', 'Somalia', 'Kenya', 'South Sudan', 'Sudan'],
      'KE': ['Tanzania', 'Uganda', 'South Sudan', 'Ethiopia', 'Somalia'],
      'TZ': [
        'Kenya',
        'Uganda',
        'Rwanda',
        'Burundi',
        'Democratic Republic of the Congo',
        'Zambia',
        'Malawi',
        'Mozambique',
      ],
      'UG': [
        'South Sudan',
        'Kenya',
        'Tanzania',
        'Rwanda',
        'Democratic Republic of the Congo',
      ],
      'MG': <String>[],

      // ─── West Africa ───
      'NG': ['Benin', 'Niger', 'Chad', 'Cameroon'],
      'GH': ["Côte d'Ivoire", 'Burkina Faso', 'Togo'],
      'CI': ['Liberia', 'Guinea', 'Mali', 'Burkina Faso', 'Ghana'],
      'SN': ['Mauritania', 'Mali', 'Guinea', 'Guinea-Bissau', 'The Gambia'],

      // ─── Central Africa ───
      'CM': [
        'Nigeria',
        'Chad',
        'Central African Republic',
        'Republic of the Congo',
        'Gabon',
        'Equatorial Guinea',
      ],
      'CD': [
        'Republic of the Congo',
        'Central African Republic',
        'South Sudan',
        'Uganda',
        'Rwanda',
        'Burundi',
        'Tanzania',
        'Zambia',
        'Angola',
      ],

      // ─── Southern Africa ───
      'ZA': [
        'Namibia',
        'Botswana',
        'Zimbabwe',
        'Mozambique',
        'Eswatini',
        'Lesotho',
      ],
      'AO': [
        'Democratic Republic of the Congo',
        'Republic of the Congo',
        'Zambia',
        'Namibia',
      ],
      'MZ': [
        'Tanzania',
        'Malawi',
        'Zambia',
        'Zimbabwe',
        'South Africa',
        'Eswatini',
      ],
      'ZW': ['Zambia', 'Mozambique', 'South Africa', 'Botswana'],
      'NA': ['Angola', 'Zambia', 'Botswana', 'South Africa'],

      // ─── East Asia ───
      'CN': [
        'Russia',
        'Mongolia',
        'North Korea',
        'Vietnam',
        'Laos',
        'Myanmar',
        'India',
        'Nepal',
        'Bhutan',
        'Pakistan',
        'Afghanistan',
        'Tajikistan',
        'Kyrgyzstan',
        'Kazakhstan',
      ],
      'JP': <String>[],
      'KR': ['North Korea'],

      // ─── Southeast Asia ───
      'TH': ['Myanmar', 'Laos', 'Cambodia', 'Malaysia'],
      'VN': ['China', 'Laos', 'Cambodia'],
      'ID': ['Malaysia', 'Papua New Guinea', 'Timor-Leste'],
      'PH': <String>[],
      'MY': ['Thailand', 'Brunei', 'Indonesia'],
      'SG': ['Malaysia'],

      // ─── South Asia ───
      'IN': ['Pakistan', 'China', 'Nepal', 'Bhutan', 'Bangladesh', 'Myanmar'],
      'PK': ['India', 'China', 'Afghanistan', 'Iran'],
      'BD': ['India', 'Myanmar'],

      // ─── Middle East ───
      'SA': [
        'Jordan',
        'Iraq',
        'Kuwait',
        'Qatar',
        'United Arab Emirates',
        'Oman',
        'Yemen',
      ],
      'AE': ['Saudi Arabia', 'Oman'],
      'IR': [
        'Turkey',
        'Iraq',
        'Pakistan',
        'Afghanistan',
        'Turkmenistan',
        'Azerbaijan',
        'Armenia',
      ],
      'IQ': ['Turkey', 'Iran', 'Kuwait', 'Saudi Arabia', 'Jordan', 'Syria'],
      'IL': ['Lebanon', 'Syria', 'Jordan', 'Egypt', 'Palestine'],

      // ─── Central Asia ───
      'KZ': ['Russia', 'China', 'Kyrgyzstan', 'Uzbekistan', 'Turkmenistan'],

      // ─── Oceania ───
      'AU': <String>[],
      'NZ': <String>[],
      'PG': ['Indonesia'],
      'FJ': <String>[],

      // ─── Expanded coverage — every playable country ───
      'BF': ['Mali', 'Niger', 'Benin', 'Togo', 'Ghana', "Cote d'Ivoire"],
      'BI': ['Rwanda', 'Tanzania', 'Congo DR'],
      'BJ': ['Togo', 'Burkina Faso', 'Niger', 'Nigeria'],
      'BW': ['Namibia', 'Zambia', 'Zimbabwe', 'South Africa'],
      'CF': [
        'Chad',
        'Sudan',
        'South Sudan',
        'Congo DR',
        'Congo (Republic)',
        'Cameroon'
      ],
      'CG': [
        'Gabon',
        'Cameroon',
        'Central African Republic',
        'Congo DR',
        'Angola'
      ],
      'CV': <String>[],
      'DJ': ['Eritrea', 'Ethiopia', 'Somaliland'],
      'EH': ['Morocco', 'Mauritania', 'Algeria'],
      'ER': ['Sudan', 'Ethiopia', 'Djibouti'],
      'GA': ['Equatorial Guinea', 'Cameroon', 'Congo (Republic)'],
      'GM': ['Senegal'],
      'GN': [
        'Guinea-Bissau',
        'Senegal',
        'Mali',
        "Cote d'Ivoire",
        'Liberia',
        'Sierra Leone'
      ],
      'GQ': ['Cameroon', 'Gabon'],
      'GW': ['Senegal', 'Guinea'],
      'KM': <String>[],
      'LR': ['Sierra Leone', 'Guinea', "Cote d'Ivoire"],
      'LS': ['South Africa'],
      'ML': [
        'Algeria',
        'Niger',
        'Burkina Faso',
        "Cote d'Ivoire",
        'Guinea',
        'Senegal',
        'Mauritania'
      ],
      'MR': ['Western Sahara', 'Algeria', 'Mali', 'Senegal'],
      'MU': <String>[],
      'MW': ['Tanzania', 'Mozambique', 'Zambia'],
      'NE': [
        'Algeria',
        'Libya',
        'Chad',
        'Nigeria',
        'Benin',
        'Burkina Faso',
        'Mali'
      ],
      'RW': ['Uganda', 'Tanzania', 'Burundi', 'Congo DR'],
      'SC': <String>[],
      'SL': ['Guinea', 'Liberia'],
      'SO': ['Ethiopia', 'Kenya', 'Somaliland'],
      'SS': [
        'Sudan',
        'Ethiopia',
        'Kenya',
        'Uganda',
        'Congo DR',
        'Central African Republic'
      ],
      'ST': <String>[],
      'SZ': ['South Africa', 'Mozambique'],
      'TD': [
        'Libya',
        'Sudan',
        'Central African Republic',
        'Cameroon',
        'Nigeria',
        'Niger'
      ],
      'TG': ['Burkina Faso', 'Benin', 'Ghana'],
      'XS': ['Djibouti', 'Ethiopia', 'Somalia'],
      'ZM': [
        'Congo DR',
        'Tanzania',
        'Malawi',
        'Mozambique',
        'Zimbabwe',
        'Botswana',
        'Namibia',
        'Angola'
      ],
      'AF': [
        'Iran',
        'Pakistan',
        'Turkmenistan',
        'Uzbekistan',
        'Tajikistan',
        'China'
      ],
      'AM': ['Georgia', 'Azerbaijan', 'Turkey', 'Iran'],
      'AZ': ['Russia', 'Georgia', 'Armenia', 'Iran', 'Turkey'],
      'BH': <String>[],
      'BN': ['Malaysia'],
      'BT': ['China', 'India'],
      'GE': ['Russia', 'Azerbaijan', 'Armenia', 'Turkey'],
      'HK': ['China'],
      'JO': ['Israel', 'Syria', 'Iraq', 'Saudi Arabia', 'Palestine'],
      'KG': ['Kazakhstan', 'Uzbekistan', 'Tajikistan', 'China'],
      'KH': ['Thailand', 'Laos', 'Vietnam'],
      'KP': ['China', 'South Korea', 'Russia'],
      'KW': ['Iraq', 'Saudi Arabia'],
      'LA': ['China', 'Vietnam', 'Cambodia', 'Thailand', 'Myanmar'],
      'LB': ['Syria', 'Israel'],
      'LK': <String>[],
      'MM': ['China', 'India', 'Bangladesh', 'Thailand', 'Laos'],
      'MN': ['Russia', 'China'],
      'MO': ['China'],
      'MV': <String>[],
      'NP': ['China', 'India'],
      'OM': ['Saudi Arabia', 'United Arab Emirates', 'Yemen'],
      'PS': ['Israel', 'Egypt', 'Jordan'],
      'QA': ['Saudi Arabia'],
      'SY': ['Turkey', 'Iraq', 'Jordan', 'Israel', 'Lebanon'],
      'TJ': ['Afghanistan', 'China', 'Kyrgyzstan', 'Uzbekistan'],
      'TL': ['Indonesia'],
      'TM': ['Kazakhstan', 'Uzbekistan', 'Afghanistan', 'Iran'],
      'TW': <String>[],
      'UZ': [
        'Kazakhstan',
        'Turkmenistan',
        'Afghanistan',
        'Tajikistan',
        'Kyrgyzstan'
      ],
      'XC': ['Cyprus'],
      'YE': ['Saudi Arabia', 'Oman'],
      'AD': ['France', 'Spain'],
      'AL': ['Greece', 'Kosovo', 'Montenegro', 'North Macedonia'],
      'AX': <String>[],
      'BA': ['Croatia', 'Montenegro', 'Serbia'],
      'BY': ['Latvia', 'Lithuania', 'Poland', 'Russia', 'Ukraine'],
      'CY': ['Northern Cyprus'],
      'EE': ['Latvia', 'Russia'],
      'FO': <String>[],
      'GG': <String>[],
      'GI': ['Spain'],
      'GL': <String>[],
      'IM': <String>[],
      'IS': <String>[],
      'JE': <String>[],
      'LI': ['Austria', 'Switzerland'],
      'LT': ['Belarus', 'Latvia', 'Poland', 'Russia'],
      'LU': ['Belgium', 'France', 'Germany'],
      'LV': ['Belarus', 'Estonia', 'Lithuania', 'Russia'],
      'MC': ['France'],
      'MD': ['Romania', 'Ukraine'],
      'ME': [
        'Albania',
        'Bosnia and Herzegovina',
        'Croatia',
        'Kosovo',
        'Serbia'
      ],
      'MK': ['Albania', 'Bulgaria', 'Greece', 'Kosovo', 'Serbia'],
      'MT': <String>[],
      'SI': ['Austria', 'Croatia', 'Hungary', 'Italy'],
      'SK': ['Austria', 'Czech Republic', 'Hungary', 'Poland', 'Ukraine'],
      'SM': ['Italy'],
      'VA': ['Italy'],
      'XK': ['Albania', 'Montenegro', 'North Macedonia', 'Serbia'],
      'AG': <String>[],
      'AQ': <String>[],
      'AW': <String>[],
      'BB': <String>[],
      'BM': <String>[],
      'BO': ['Peru', 'Chile', 'Argentina', 'Paraguay', 'Brazil'],
      'BS': <String>[],
      'BZ': ['Mexico', 'Guatemala'],
      'CK': <String>[],
      'CR': ['Nicaragua', 'Panama'],
      'CW': <String>[],
      'DM': <String>[],
      'DO': ['Haiti'],
      'FK': <String>[],
      'FM': <String>[],
      'GD': <String>[],
      'GU': <String>[],
      'GY': ['Venezuela', 'Brazil', 'Suriname'],
      'HN': ['Guatemala', 'El Salvador', 'Nicaragua'],
      'HT': ['Dominican Republic'],
      'JM': <String>[],
      'KI': <String>[],
      'KN': <String>[],
      'LC': <String>[],
      'MH': <String>[],
      'NC': <String>[],
      'NI': ['Honduras', 'Costa Rica'],
      'NR': <String>[],
      'PR': <String>[],
      'PW': <String>[],
      'SB': <String>[],
      'SR': ['Guyana', 'Brazil', 'French Guiana'],
      'SV': ['Guatemala', 'Honduras'],
      'TO': <String>[],
      'TT': <String>[],
      'TV': <String>[],
      'VC': <String>[],
      'VU': <String>[],
      'WS': <String>[],
    };
    // Return empty list if country not found - caller should handle by picking different clue type
    return neighbors[code] ?? <String>[];
  }

  /// Full stats database for each country. A random trio is selected at runtime.
  ///
  /// When [random] is provided the selection is deterministic, ensuring both
  /// H2H players see the same three facts.
  /// Returns **all** stats for a country (not a random trio).
  /// Used by the Country Clues browser so players can see every fact.
  static Map<String, String> getAllCountryStats(String code) {
    final stats = _getCountryStats(code, returnAll: true);
    return stats.map((k, v) => MapEntry(k, v.toString()));
  }

  /// Returns all neighboring country names for a given code.
  static List<String> getNeighbors(String code) {
    return _getNeighboringCountries(code);
  }

  static Map<String, dynamic> _getCountryStats(
    String code, {
    Random? random,
    bool returnAll = false,
  }) {
    const allStats = <String, Map<String, String>>{
      // ═══════════════════════════════════════════
      // NORTH AMERICA
      // ═══════════════════════════════════════════
      'US': {
        'population': '331M',
        'continent': 'North America',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Donald Trump',
        'sport': 'American Football',
        'language': 'English',
        'celebrity': 'Beyoncé',
      },
      'CA': {
        'population': '38M',
        'continent': 'North America',
        'currency': 'Canadian Dollar (CAD)',
        'religion': 'Christianity',
        'headOfState': 'Mark Carney',
        'sport': 'Ice Hockey',
        'language': 'English/French',
        'celebrity': 'Drake',
      },
      'MX': {
        'population': '128M',
        'continent': 'North America',
        'currency': 'Mexican Peso (MXN)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Claudia Sheinbaum',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Salma Hayek',
      },
      'CU': {
        'population': '11M',
        'continent': 'North America',
        'currency': 'Cuban Peso (CUP)',
        'religion': 'Christianity / Santería',
        'headOfState': 'Miguel Díaz-Canel',
        'sport': 'Baseball / Boxing',
        'language': 'Spanish',
        'celebrity': 'Celia Cruz',
      },
      'GT': {
        'population': '18M',
        'continent': 'North America',
        'currency': 'Guatemalan Quetzal (GTQ)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Bernardo Arévalo',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Rigoberta Menchú',
      },
      'PA': {
        'population': '4M',
        'continent': 'North America',
        'currency': 'Balboa / US Dollar (PAB/USD)',
        'religion': 'Roman Catholicism',
        'headOfState': 'José Raúl Mulino',
        'sport': 'Baseball / Boxing',
        'language': 'Spanish',
        'celebrity': 'Rubén Blades',
      },

      // ═══════════════════════════════════════════
      // SOUTH AMERICA
      // ═══════════════════════════════════════════
      'BR': {
        'population': '214M',
        'continent': 'South America',
        'currency': 'Brazilian Real (BRL)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Lula da Silva',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Pelé',
      },
      'AR': {
        'population': '45M',
        'continent': 'South America',
        'currency': 'Argentine Peso (ARS)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Javier Milei',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Lionel Messi',
      },
      'CO': {
        'population': '51M',
        'continent': 'South America',
        'currency': 'Colombian Peso (COP)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Gustavo Petro',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Shakira',
      },
      'PE': {
        'population': '34M',
        'continent': 'South America',
        'currency': 'Peruvian Sol (PEN)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Dina Boluarte',
        'sport': 'Football (Soccer)',
        'language': 'Spanish / Quechua',
        'celebrity': 'Mario Vargas Llosa',
      },
      'CL': {
        'population': '19M',
        'continent': 'South America',
        'currency': 'Chilean Peso (CLP)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Gabriel Boric',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Pablo Neruda',
      },
      'VE': {
        'population': '28M',
        'continent': 'South America',
        'currency': 'Venezuelan Bolívar (VES)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Nicolás Maduro',
        'sport': 'Baseball',
        'language': 'Spanish',
        'celebrity': 'Carolina Herrera',
      },
      'EC': {
        'population': '18M',
        'continent': 'South America',
        'currency': 'US Dollar (USD)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Daniel Noboa',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Christina Aguilera',
      },
      'UY': {
        'population': '4M',
        'continent': 'South America',
        'currency': 'Uruguayan Peso (UYU)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Yamandú Orsi',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Luis Suárez',
      },
      'PY': {
        'population': '7M',
        'continent': 'South America',
        'currency': 'Paraguayan Guaraní (PYG)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Santiago Peña',
        'sport': 'Football (Soccer)',
        'language': 'Spanish / Guaraní',
        'celebrity': 'Roque Santa Cruz',
      },

      // ═══════════════════════════════════════════
      // WESTERN EUROPE
      // ═══════════════════════════════════════════
      'GB': {
        'population': '67M',
        'continent': 'Europe',
        'currency': 'Pound Sterling (GBP)',
        'religion': 'Christianity',
        'headOfState': 'King Charles III',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Adele',
      },
      'FR': {
        'population': '67M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Emmanuel Macron',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Zinedine Zidane',
      },
      'DE': {
        'population': '83M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Christianity',
        'headOfState': 'Friedrich Merz',
        'sport': 'Football (Soccer)',
        'language': 'German',
        'celebrity': 'Albert Einstein',
      },
      'IT': {
        'population': '60M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Giorgia Meloni',
        'sport': 'Football (Soccer)',
        'language': 'Italian',
        'celebrity': 'Leonardo da Vinci',
      },
      'ES': {
        'population': '47M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'King Felipe VI',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Rafael Nadal',
      },
      'PT': {
        'population': '10M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Luís Montenegro',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Cristiano Ronaldo',
      },
      'NL': {
        'population': '18M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Christianity',
        'headOfState': 'King Willem-Alexander',
        'sport': 'Football (Soccer)',
        'language': 'Dutch',
        'celebrity': 'Vincent van Gogh',
      },
      'BE': {
        'population': '12M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'King Philippe',
        'sport': 'Football / Cycling',
        'language': 'Dutch / French / German',
        'celebrity': 'Audrey Hepburn',
      },
      'CH': {
        'population': '9M',
        'continent': 'Europe',
        'currency': 'Swiss Franc (CHF)',
        'religion': 'Christianity',
        'headOfState': 'Karin Keller-Sutter',
        'sport': 'Skiing / Tennis',
        'language': 'German / French / Italian / Romansh',
        'celebrity': 'Roger Federer',
      },
      'AT': {
        'population': '9M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Alexander Schallenberg',
        'sport': 'Alpine Skiing',
        'language': 'German',
        'celebrity': 'Arnold Schwarzenegger',
      },
      'IE': {
        'population': '5M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Micheál Martin',
        'sport': 'Gaelic Football / Hurling',
        'language': 'Irish / English',
        'celebrity': 'Conor McGregor',
      },

      // ═══════════════════════════════════════════
      // NORTHERN EUROPE
      // ═══════════════════════════════════════════
      'SE': {
        'population': '10M',
        'continent': 'Europe',
        'currency': 'Swedish Krona (SEK)',
        'religion': 'Christianity (Lutheran)',
        'headOfState': 'King Carl XVI Gustaf',
        'sport': 'Ice Hockey',
        'language': 'Swedish',
        'celebrity': 'ABBA',
      },
      'NO': {
        'population': '5M',
        'continent': 'Europe',
        'currency': 'Norwegian Krone (NOK)',
        'religion': 'Christianity (Lutheran)',
        'headOfState': 'King Harald V',
        'sport': 'Cross-Country Skiing',
        'language': 'Norwegian',
        'celebrity': 'Edvard Munch',
      },
      'FI': {
        'population': '6M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Christianity (Lutheran)',
        'headOfState': 'Alexander Stubb',
        'sport': 'Ice Hockey',
        'language': 'Finnish / Swedish',
        'celebrity': 'Linus Torvalds',
      },
      'DK': {
        'population': '6M',
        'continent': 'Europe',
        'currency': 'Danish Krone (DKK)',
        'religion': 'Christianity (Lutheran)',
        'headOfState': 'King Frederik X',
        'sport': 'Football (Soccer)',
        'language': 'Danish',
        'celebrity': 'Hans Christian Andersen',
      },

      // ═══════════════════════════════════════════
      // CENTRAL & EASTERN EUROPE
      // ═══════════════════════════════════════════
      'PL': {
        'population': '38M',
        'continent': 'Europe',
        'currency': 'Polish Zloty (PLN)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Andrzej Duda',
        'sport': 'Football (Soccer)',
        'language': 'Polish',
        'celebrity': 'Frédéric Chopin',
      },
      'CZ': {
        'population': '11M',
        'continent': 'Europe',
        'currency': 'Czech Koruna (CZK)',
        'religion': 'Christianity (largely secular)',
        'headOfState': 'Petr Pavel',
        'sport': 'Ice Hockey',
        'language': 'Czech',
        'celebrity': 'Franz Kafka',
      },
      'HU': {
        'population': '10M',
        'continent': 'Europe',
        'currency': 'Hungarian Forint (HUF)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Viktor Orbán',
        'sport': 'Water Polo',
        'language': 'Hungarian',
        'celebrity': 'Ernő Rubik',
      },
      'RO': {
        'population': '19M',
        'continent': 'Europe',
        'currency': 'Romanian Leu (RON)',
        'religion': 'Romanian Orthodoxy',
        'headOfState': 'Klaus Iohannis',
        'sport': 'Football (Soccer)',
        'language': 'Romanian',
        'celebrity': 'Nadia Comăneci',
      },
      'BG': {
        'population': '7M',
        'continent': 'Europe',
        'currency': 'Bulgarian Lev (BGN)',
        'religion': 'Bulgarian Orthodoxy',
        'headOfState': 'Dimitar Glavchev',
        'sport': 'Football (Soccer)',
        'language': 'Bulgarian',
        'celebrity': 'Hristo Stoichkov',
      },
      'HR': {
        'population': '4M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Zoran Milanović',
        'sport': 'Football (Soccer)',
        'language': 'Croatian',
        'celebrity': 'Luka Modrić',
      },
      'RS': {
        'population': '7M',
        'continent': 'Europe',
        'currency': 'Serbian Dinar (RSD)',
        'religion': 'Serbian Orthodoxy',
        'headOfState': 'Aleksandar Vučić',
        'sport': 'Tennis / Basketball',
        'language': 'Serbian',
        'celebrity': 'Novak Djokovic',
      },
      'UA': {
        'population': '44M',
        'continent': 'Europe',
        'currency': 'Ukrainian Hryvnia (UAH)',
        'religion': 'Christianity (Orthodox)',
        'headOfState': 'Volodymyr Zelenskyy',
        'sport': 'Football (Soccer)',
        'language': 'Ukrainian',
        'celebrity': 'Andriy Shevchenko',
      },

      // ═══════════════════════════════════════════
      // SOUTHERN EUROPE & TURKEY
      // ═══════════════════════════════════════════
      'GR': {
        'population': '11M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Greek Orthodoxy',
        'headOfState': 'Kyriakos Mitsotakis',
        'sport': 'Football (Soccer)',
        'language': 'Greek',
        'celebrity': 'Giannis Antetokounmpo',
      },
      'TR': {
        'population': '85M',
        'continent': 'Europe / Asia',
        'currency': 'Turkish Lira (TRY)',
        'religion': 'Islam',
        'headOfState': 'Recep Tayyip Erdoğan',
        'sport': 'Football (Soccer)',
        'language': 'Turkish',
        'celebrity': 'Orhan Pamuk',
      },

      // ═══════════════════════════════════════════
      // RUSSIA & CENTRAL ASIA
      // ═══════════════════════════════════════════
      'RU': {
        'population': '144M',
        'continent': 'Europe/Asia',
        'currency': 'Russian Ruble (RUB)',
        'religion': 'Russian Orthodoxy',
        'headOfState': 'Vladimir Putin',
        'sport': 'Ice Hockey',
        'language': 'Russian',
        'celebrity': 'Yuri Gagarin',
      },
      'KZ': {
        'population': '19M',
        'continent': 'Asia',
        'currency': 'Kazakhstani Tenge (KZT)',
        'religion': 'Islam',
        'headOfState': 'Kassym-Jomart Tokayev',
        'sport': 'Boxing / Wrestling',
        'language': 'Kazakh / Russian',
        'celebrity': 'Gennady Golovkin',
      },

      // ═══════════════════════════════════════════
      // NORTH AFRICA
      // ═══════════════════════════════════════════
      'EG': {
        'population': '102M',
        'continent': 'Africa',
        'currency': 'Egyptian Pound (EGP)',
        'religion': 'Islam',
        'headOfState': 'Abdel Fattah el-Sisi',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'Mohamed Salah',
      },
      'MA': {
        'population': '37M',
        'continent': 'Africa',
        'currency': 'Moroccan Dirham (MAD)',
        'religion': 'Islam',
        'headOfState': 'King Mohammed VI',
        'sport': 'Football (Soccer)',
        'language': 'Arabic / Berber / French',
        'celebrity': 'Gad Elmaleh',
      },
      'DZ': {
        'population': '45M',
        'continent': 'Africa',
        'currency': 'Algerian Dinar (DZD)',
        'religion': 'Islam',
        'headOfState': 'Abdelmadjid Tebboune',
        'sport': 'Football (Soccer)',
        'language': 'Arabic / Berber / French',
        'celebrity': 'Khaled',
      },
      'TN': {
        'population': '12M',
        'continent': 'Africa',
        'currency': 'Tunisian Dinar (TND)',
        'religion': 'Islam',
        'headOfState': 'Kais Saied',
        'sport': 'Football (Soccer)',
        'language': 'Arabic / French',
        'celebrity': 'Ons Jabeur',
      },
      'LY': {
        'population': '7M',
        'continent': 'Africa',
        'currency': 'Libyan Dinar (LYD)',
        'religion': 'Islam',
        'headOfState': 'Abdul Hamid Dbeibeh',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'Omar Mukhtar',
      },
      'SD': {
        'population': '45M',
        'continent': 'Africa',
        'currency': 'Sudanese Pound (SDG)',
        'religion': 'Islam',
        'headOfState': 'Abdel Fattah al-Burhan',
        'sport': 'Football (Soccer)',
        'language': 'Arabic / English',
        'celebrity': 'Alek Wek',
      },

      // ═══════════════════════════════════════════
      // EAST AFRICA
      // ═══════════════════════════════════════════
      'ET': {
        'population': '120M',
        'continent': 'Africa',
        'currency': 'Ethiopian Birr (ETB)',
        'religion': 'Christianity / Islam',
        'headOfState': 'Abiy Ahmed',
        'sport': 'Athletics',
        'language': 'Amharic',
        'celebrity': 'Haile Gebrselassie',
      },
      'KE': {
        'population': '54M',
        'continent': 'Africa',
        'currency': 'Kenyan Shilling (KES)',
        'religion': 'Christianity',
        'headOfState': 'William Ruto',
        'sport': 'Athletics',
        'language': 'Swahili / English',
        'celebrity': "Lupita Nyong'o",
      },
      'TZ': {
        'population': '62M',
        'continent': 'Africa',
        'currency': 'Tanzanian Shilling (TZS)',
        'religion': 'Christianity / Islam',
        'headOfState': 'Samia Suluhu Hassan',
        'sport': 'Football (Soccer)',
        'language': 'Swahili / English',
        'celebrity': 'Freddie Mercury',
      },
      'UG': {
        'population': '46M',
        'continent': 'Africa',
        'currency': 'Ugandan Shilling (UGX)',
        'religion': 'Christianity',
        'headOfState': 'Yoweri Museveni',
        'sport': 'Football (Soccer)',
        'language': 'English / Swahili',
        'celebrity': 'Bobi Wine',
      },
      'MG': {
        'population': '29M',
        'continent': 'Africa',
        'currency': 'Malagasy Ariary (MGA)',
        'religion': 'Christianity / Traditional',
        'headOfState': 'Andry Rajoelina',
        'sport': 'Football (Soccer)',
        'language': 'Malagasy / French',
        'celebrity': 'Eric Rabesandratana',
      },

      // ═══════════════════════════════════════════
      // WEST AFRICA
      // ═══════════════════════════════════════════
      'NG': {
        'population': '213M',
        'continent': 'Africa',
        'currency': 'Nigerian Naira (NGN)',
        'religion': 'Islam / Christianity',
        'headOfState': 'Bola Tinubu',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Burna Boy',
      },
      'GH': {
        'population': '33M',
        'continent': 'Africa',
        'currency': 'Ghanaian Cedi (GHS)',
        'religion': 'Christianity',
        'headOfState': 'John Mahama',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Kofi Annan',
      },
      'CI': {
        'population': '27M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam / Christianity',
        'headOfState': 'Alassane Ouattara',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Didier Drogba',
      },
      'SN': {
        'population': '17M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam',
        'headOfState': 'Bassirou Diomaye Faye',
        'sport': 'Football / Wrestling',
        'language': 'French / Wolof',
        'celebrity': 'Sadio Mané',
      },

      // ═══════════════════════════════════════════
      // CENTRAL AFRICA
      // ═══════════════════════════════════════════
      'CM': {
        'population': '27M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Christianity / Islam',
        'headOfState': 'Paul Biya',
        'sport': 'Football (Soccer)',
        'language': 'French / English',
        'celebrity': "Samuel Eto'o",
      },
      'CD': {
        'population': '100M',
        'continent': 'Africa',
        'currency': 'Congolese Franc (CDF)',
        'religion': 'Christianity',
        'headOfState': 'Félix Tshisekedi',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Dikembe Mutombo',
      },

      // ═══════════════════════════════════════════
      // SOUTHERN AFRICA
      // ═══════════════════════════════════════════
      'ZA': {
        'population': '60M',
        'continent': 'Africa',
        'currency': 'South African Rand (ZAR)',
        'religion': 'Christianity',
        'headOfState': 'Cyril Ramaphosa',
        'sport': 'Rugby / Cricket',
        'language': 'Many (11 official)',
        'celebrity': 'Charlize Theron',
      },
      'AO': {
        'population': '34M',
        'continent': 'Africa',
        'currency': 'Angolan Kwanza (AOA)',
        'religion': 'Christianity',
        'headOfState': 'João Lourenço',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Nando Rafael',
      },
      'MZ': {
        'population': '32M',
        'continent': 'Africa',
        'currency': 'Mozambican Metical (MZN)',
        'religion': 'Christianity',
        'headOfState': 'Daniel Chapo',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Eusébio',
      },
      'ZW': {
        'population': '16M',
        'continent': 'Africa',
        'currency': 'Zimbabwe Dollar / US Dollar (ZWL/USD)',
        'religion': 'Christianity',
        'headOfState': 'Emmerson Mnangagwa',
        'sport': 'Football / Cricket',
        'language': 'English / Shona / Ndebele',
        'celebrity': 'Danai Gurira',
      },
      'NA': {
        'population': '3M',
        'continent': 'Africa',
        'currency': 'Namibian Dollar (NAD)',
        'religion': 'Christianity',
        'headOfState': 'Netumbo Nandi-Ndaitwah',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'The Dogg',
      },

      // ═══════════════════════════════════════════
      // EAST ASIA
      // ═══════════════════════════════════════════
      'CN': {
        'population': '1.4B',
        'continent': 'Asia',
        'currency': 'Renminbi Yuan (CNY)',
        'religion': 'Folk religion / Buddhism',
        'headOfState': 'Xi Jinping',
        'sport': 'Table Tennis',
        'language': 'Mandarin',
        'celebrity': 'Jackie Chan',
      },
      'JP': {
        'population': '125M',
        'continent': 'Asia',
        'currency': 'Japanese Yen (JPY)',
        'religion': 'Shinto / Buddhism',
        'headOfState': 'Shigeru Ishiba',
        'sport': 'Baseball',
        'language': 'Japanese',
        'celebrity': 'Hayao Miyazaki',
      },
      'KR': {
        'population': '52M',
        'continent': 'Asia',
        'currency': 'South Korean Won (KRW)',
        'religion': 'Christianity / Buddhism',
        'headOfState': 'Han Duck-soo',
        'sport': 'Baseball / Esports',
        'language': 'Korean',
        'celebrity': 'BTS',
      },

      // ═══════════════════════════════════════════
      // SOUTHEAST ASIA
      // ═══════════════════════════════════════════
      'TH': {
        'population': '72M',
        'continent': 'Asia',
        'currency': 'Thai Baht (THB)',
        'religion': 'Buddhism',
        'headOfState': 'Paetongtarn Shinawatra',
        'sport': 'Muay Thai',
        'language': 'Thai',
        'celebrity': 'Tony Jaa',
      },
      'VN': {
        'population': '98M',
        'continent': 'Asia',
        'currency': 'Vietnamese Dong (VND)',
        'religion': 'Buddhism / Folk religion',
        'headOfState': 'Lương Cường',
        'sport': 'Football (Soccer)',
        'language': 'Vietnamese',
        'celebrity': 'Ho Chi Minh',
      },
      'ID': {
        'population': '276M',
        'continent': 'Asia',
        'currency': 'Indonesian Rupiah (IDR)',
        'religion': 'Islam',
        'headOfState': 'Prabowo Subianto',
        'sport': 'Badminton',
        'language': 'Indonesian',
        'celebrity': 'Iko Uwais',
      },
      'PH': {
        'population': '113M',
        'continent': 'Asia',
        'currency': 'Philippine Peso (PHP)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Bongbong Marcos',
        'sport': 'Basketball / Boxing',
        'language': 'Filipino / English',
        'celebrity': 'Manny Pacquiao',
      },
      'MY': {
        'population': '33M',
        'continent': 'Asia',
        'currency': 'Malaysian Ringgit (MYR)',
        'religion': 'Islam',
        'headOfState': 'Anwar Ibrahim',
        'sport': 'Badminton',
        'language': 'Malay / English',
        'celebrity': 'Michelle Yeoh',
      },
      'SG': {
        'population': '6M',
        'continent': 'Asia',
        'currency': 'Singapore Dollar (SGD)',
        'religion': 'Buddhism / Christianity / Islam',
        'headOfState': 'Lawrence Wong',
        'sport': 'Football / Swimming',
        'language': 'English / Malay / Mandarin / Tamil',
        'celebrity': 'Joseph Schooling',
      },

      // ═══════════════════════════════════════════
      // SOUTH ASIA
      // ═══════════════════════════════════════════
      'IN': {
        'population': '1.4B',
        'continent': 'Asia',
        'currency': 'Indian Rupee (INR)',
        'religion': 'Hinduism',
        'headOfState': 'Narendra Modi',
        'sport': 'Cricket',
        'language': 'Hindi/English',
        'celebrity': 'Shah Rukh Khan',
      },
      'PK': {
        'population': '230M',
        'continent': 'Asia',
        'currency': 'Pakistani Rupee (PKR)',
        'religion': 'Islam',
        'headOfState': 'Shehbaz Sharif',
        'sport': 'Cricket',
        'language': 'Urdu / English',
        'celebrity': 'Malala Yousafzai',
      },
      'BD': {
        'population': '170M',
        'continent': 'Asia',
        'currency': 'Bangladeshi Taka (BDT)',
        'religion': 'Islam',
        'headOfState': 'Muhammad Yunus',
        'sport': 'Cricket',
        'language': 'Bengali',
        'celebrity': 'Muhammad Yunus',
      },

      // ═══════════════════════════════════════════
      // MIDDLE EAST
      // ═══════════════════════════════════════════
      'SA': {
        'population': '36M',
        'continent': 'Asia',
        'currency': 'Saudi Riyal (SAR)',
        'religion': 'Islam',
        'headOfState': 'Mohammed bin Salman',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'Hamzah Idris',
      },
      'AE': {
        'population': '10M',
        'continent': 'Asia',
        'currency': 'UAE Dirham (AED)',
        'religion': 'Islam',
        'headOfState': 'Sheikh Mohamed bin Zayed',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'DJ Bliss',
      },
      'IR': {
        'population': '87M',
        'continent': 'Asia',
        'currency': 'Iranian Rial (IRR)',
        'religion': 'Islam (Shia)',
        'headOfState': 'Ali Khamenei',
        'sport': 'Football / Wrestling',
        'language': 'Persian (Farsi)',
        'celebrity': 'Asghar Farhadi',
      },
      'IQ': {
        'population': '42M',
        'continent': 'Asia',
        'currency': 'Iraqi Dinar (IQD)',
        'religion': 'Islam',
        'headOfState': 'Mohammed Shia al-Sudani',
        'sport': 'Football (Soccer)',
        'language': 'Arabic / Kurdish',
        'celebrity': 'Zaha Hadid',
      },
      'IL': {
        'population': '9M',
        'continent': 'Asia',
        'currency': 'Israeli New Shekel (ILS)',
        'religion': 'Judaism',
        'headOfState': 'Benjamin Netanyahu',
        'sport': 'Football / Basketball',
        'language': 'Hebrew / Arabic',
        'celebrity': 'Gal Gadot',
      },

      // ═══════════════════════════════════════════
      // OCEANIA
      // ═══════════════════════════════════════════
      'AU': {
        'population': '26M',
        'continent': 'Oceania',
        'currency': 'Australian Dollar (AUD)',
        'religion': 'Christianity',
        'headOfState': 'Anthony Albanese',
        'sport': 'Cricket / AFL',
        'language': 'English',
        'celebrity': 'Hugh Jackman',
      },
      'NZ': {
        'population': '5M',
        'continent': 'Oceania',
        'currency': 'New Zealand Dollar (NZD)',
        'religion': 'Christianity',
        'headOfState': 'Christopher Luxon',
        'sport': 'Rugby',
        'language': 'English / Māori',
        'celebrity': 'Peter Jackson',
      },
      'PG': {
        'population': '10M',
        'continent': 'Oceania',
        'currency': 'Papua New Guinean Kina (PGK)',
        'religion': 'Christianity',
        'headOfState': 'James Marape',
        'sport': 'Rugby League',
        'language': 'English / Tok Pisin / Hiri Motu',
        'celebrity': 'Don Bradman (cricket icon)',
      },
      'FJ': {
        'population': '900K',
        'continent': 'Oceania',
        'currency': 'Fijian Dollar (FJD)',
        'religion': 'Christianity / Hinduism',
        'headOfState': 'Sitiveni Rabuka',
        'sport': 'Rugby Sevens',
        'language': 'English / Fijian / Hindi',
        'celebrity': 'Vijay Singh',
      },

      // ═══════════════════════════════════════════
      // EXPANDED COVERAGE — every playable country
      // (leaders current as of Jan 2026)
      // ═══════════════════════════════════════════
      'BF': {
        'population': '23M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam',
        'headOfState': 'Ibrahim Traoré',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Bertrand Traoré',
      },
      'BI': {
        'population': '13M',
        'continent': 'Africa',
        'currency': 'Burundian Franc (BIF)',
        'religion': 'Christianity',
        'headOfState': 'Évariste Ndayishimiye',
        'sport': 'Football (Soccer)',
        'language': 'Kirundi',
        'celebrity': 'Vénuste Niyongabo',
      },
      'BJ': {
        'population': '14M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Christianity',
        'headOfState': 'Patrice Talon',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Angélique Kidjo',
      },
      'BW': {
        'population': '2.5M',
        'continent': 'Africa',
        'currency': 'Botswana Pula (BWP)',
        'religion': 'Christianity',
        'headOfState': 'Duma Boko',
        'sport': 'Football (Soccer)',
        'language': 'Setswana',
        'celebrity': 'Letsile Tebogo',
      },
      'CF': {
        'population': '5.6M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Christianity',
        'headOfState': 'Faustin-Archange Touadéra',
        'sport': 'Football (Soccer)',
        'language': 'Sango',
        'celebrity': 'Barthélemy Boganda',
      },
      'CG': {
        'population': '6.1M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Christianity',
        'headOfState': 'Denis Sassou Nguesso',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Alain Mabanckou',
      },
      'CV': {
        'population': '600K',
        'continent': 'Africa',
        'currency': 'Cape Verdean Escudo (CVE)',
        'religion': 'Christianity',
        'headOfState': 'José Maria Neves',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Cesária Évora',
      },
      'DJ': {
        'population': '1.1M',
        'continent': 'Africa',
        'currency': 'Djiboutian Franc (DJF)',
        'religion': 'Islam',
        'headOfState': 'Ismaïl Omar Guelleh',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Ayanleh Souleiman',
      },
      'EH': {
        'population': '600K',
        'continent': 'Africa',
        'currency': 'Moroccan Dirham (MAD)',
        'religion': 'Islam',
        'headOfState': 'Brahim Ghali',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'Aziza Brahim',
      },
      'ER': {
        'population': '3.7M',
        'continent': 'Africa',
        'currency': 'Eritrean Nakfa (ERN)',
        'religion': 'Christianity',
        'headOfState': 'Isaias Afwerki',
        'sport': 'Cycling',
        'language': 'Tigrinya',
        'celebrity': 'Biniam Girmay',
      },
      'GA': {
        'population': '2.4M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Christianity',
        'headOfState': 'Brice Oligui Nguema',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Pierre-Emerick Aubameyang',
      },
      'GM': {
        'population': '2.8M',
        'continent': 'Africa',
        'currency': 'Gambian Dalasi (GMD)',
        'religion': 'Islam',
        'headOfState': 'Adama Barrow',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Jaliba Kuyateh',
      },
      'GN': {
        'population': '14M',
        'continent': 'Africa',
        'currency': 'Guinean Franc (GNF)',
        'religion': 'Islam',
        'headOfState': 'Mamady Doumbouya',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Mory Kanté',
      },
      'GQ': {
        'population': '1.7M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Christianity',
        'headOfState': 'Teodoro Obiang Nguema Mbasogo',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Eric Moussambani',
      },
      'GW': {
        'population': '2.1M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam',
        'headOfState': 'General Horta Inta-A Na Man',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Ansu Fati',
      },
      'KM': {
        'population': '900K',
        'continent': 'Africa',
        'currency': 'Comorian Franc (KMF)',
        'religion': 'Islam',
        'headOfState': 'Azali Assoumani',
        'sport': 'Football (Soccer)',
        'language': 'Comorian',
        'celebrity': 'El Fardou Ben Mohadji',
      },
      'LR': {
        'population': '5.4M',
        'continent': 'Africa',
        'currency': 'Liberian Dollar (LRD)',
        'religion': 'Christianity',
        'headOfState': 'Joseph Boakai',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'George Weah',
      },
      'LS': {
        'population': '2.3M',
        'continent': 'Africa',
        'currency': 'Lesotho Loti (LSL)',
        'religion': 'Christianity',
        'headOfState': 'Sam Matekane',
        'sport': 'Football (Soccer)',
        'language': 'Sesotho',
        'celebrity': 'Thomas Mofolo',
      },
      'ML': {
        'population': '23M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam',
        'headOfState': 'Assimi Goïta',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Salif Keita',
      },
      'MR': {
        'population': '4.9M',
        'continent': 'Africa',
        'currency': 'Mauritanian Ouguiya (MRU)',
        'religion': 'Islam',
        'headOfState': 'Mohamed Ould Ghazouani',
        'sport': 'Football (Soccer)',
        'language': 'Arabic',
        'celebrity': 'Dimi Mint Abba',
      },
      'MU': {
        'population': '1.3M',
        'continent': 'Africa',
        'currency': 'Mauritian Rupee (MUR)',
        'religion': 'Hinduism',
        'headOfState': 'Navin Ramgoolam',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Kaya',
      },
      'MW': {
        'population': '21M',
        'continent': 'Africa',
        'currency': 'Malawian Kwacha (MWK)',
        'religion': 'Christianity',
        'headOfState': 'Peter Mutharika',
        'sport': 'Football (Soccer)',
        'language': 'Chichewa',
        'celebrity': 'Joyce Banda',
      },
      'NE': {
        'population': '27M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Islam',
        'headOfState': 'Abdourahamane Tchiani',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Mdou Moctar',
      },
      'RW': {
        'population': '14M',
        'continent': 'Africa',
        'currency': 'Rwandan Franc (RWF)',
        'religion': 'Christianity',
        'headOfState': 'Paul Kagame',
        'sport': 'Football (Soccer)',
        'language': 'Kinyarwanda',
        'celebrity': 'Adrien Niyonshuti',
      },
      'SC': {
        'population': '100K',
        'continent': 'Africa',
        'currency': 'Seychellois Rupee (SCR)',
        'religion': 'Christianity',
        'headOfState': 'Wavel Ramkalawan',
        'sport': 'Football (Soccer)',
        'language': 'Seychellois Creole',
        'celebrity': 'Patrick Victor',
      },
      'SL': {
        'population': '8.6M',
        'continent': 'Africa',
        'currency': 'Sierra Leonean Leone (SLE)',
        'religion': 'Islam',
        'headOfState': 'Julius Maada Bio',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Idris Elba',
      },
      'SO': {
        'population': '18M',
        'continent': 'Africa',
        'currency': 'Somali Shilling (SOS)',
        'religion': 'Islam',
        'headOfState': 'Hassan Sheikh Mohamud',
        'sport': 'Football (Soccer)',
        'language': 'Somali',
        'celebrity': 'Iman',
      },
      'SS': {
        'population': '11M',
        'continent': 'Africa',
        'currency': 'South Sudanese Pound (SSP)',
        'religion': 'Christianity',
        'headOfState': 'Salva Kiir Mayardit',
        'sport': 'Basketball',
        'language': 'English',
        'celebrity': 'Luol Deng',
      },
      'ST': {
        'population': '230K',
        'continent': 'Africa',
        'currency': 'São Tomé and Príncipe Dobra (STN)',
        'religion': 'Christianity',
        'headOfState': 'Carlos Vila Nova',
        'sport': 'Football (Soccer)',
        'language': 'Portuguese',
        'celebrity': 'Alda Espírito Santo',
      },
      'SZ': {
        'population': '1.2M',
        'continent': 'Africa',
        'currency': 'Swazi Lilangeni (SZL)',
        'religion': 'Christianity',
        'headOfState': 'King Mswati III',
        'sport': 'Football (Soccer)',
        'language': 'Swati',
        'celebrity': 'King Sobhuza II',
      },
      'TD': {
        'population': '18M',
        'continent': 'Africa',
        'currency': 'Central African CFA Franc (XAF)',
        'religion': 'Islam',
        'headOfState': 'Mahamat Déby',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': "Ezechiel N'Douassel",
      },
      'TG': {
        'population': '9M',
        'continent': 'Africa',
        'currency': 'West African CFA Franc (XOF)',
        'religion': 'Christianity',
        'headOfState': 'Faure Gnassingbé',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Emmanuel Adebayor',
      },
      'XS': {
        'population': '5.7M',
        'continent': 'Africa',
        'currency': 'Somaliland Shilling (SLS)',
        'religion': 'Islam',
        'headOfState': 'Abdirahman Mohamed Abdullahi',
        'sport': 'Football (Soccer)',
        'language': 'Somali',
        'celebrity': 'Hadraawi',
      },
      'ZM': {
        'population': '20M',
        'continent': 'Africa',
        'currency': 'Zambian Kwacha (ZMW)',
        'religion': 'Christianity',
        'headOfState': 'Hakainde Hichilema',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Kalusha Bwalya',
      },
      'AF': {
        'population': '41M',
        'continent': 'Asia',
        'currency': 'Afghan Afghani (AFN)',
        'religion': 'Islam',
        'headOfState': 'Hibatullah Akhundzada',
        'sport': 'Cricket',
        'language': 'Pashto/Dari',
        'celebrity': 'Khaled Hosseini',
      },
      'AM': {
        'population': '3M',
        'continent': 'Asia',
        'currency': 'Armenian Dram (AMD)',
        'religion': 'Christianity',
        'headOfState': 'Nikol Pashinyan',
        'sport': 'Football',
        'language': 'Armenian',
        'celebrity': 'Charles Aznavour',
      },
      'AZ': {
        'population': '10M',
        'continent': 'Asia',
        'currency': 'Azerbaijani Manat (AZN)',
        'religion': 'Islam',
        'headOfState': 'Ilham Aliyev',
        'sport': 'Football',
        'language': 'Azerbaijani',
        'celebrity': 'Garry Kasparov',
      },
      'BH': {
        'population': '1.5M',
        'continent': 'Asia',
        'currency': 'Bahraini Dinar (BHD)',
        'religion': 'Islam',
        'headOfState': 'King Hamad bin Isa Al Khalifa',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Ruth Jebet',
      },
      'BN': {
        'population': '450K',
        'continent': 'Asia',
        'currency': 'Brunei Dollar (BND)',
        'religion': 'Islam',
        'headOfState': 'Sultan Hassanal Bolkiah',
        'sport': 'Football',
        'language': 'Malay',
        'celebrity': 'Prince Abdul Mateen',
      },
      'BT': {
        'population': '800K',
        'continent': 'Asia',
        'currency': 'Bhutanese Ngultrum (BTN)',
        'religion': 'Buddhism',
        'headOfState': 'King Jigme Khesar Namgyel Wangchuck',
        'sport': 'Archery',
        'language': 'Dzongkha',
        'celebrity': 'Ugyen Wangchuck',
      },
      'GE': {
        'population': '3.7M',
        'continent': 'Asia',
        'currency': 'Georgian Lari (GEL)',
        'religion': 'Christianity',
        'headOfState': 'Irakli Kobakhidze',
        'sport': 'Rugby',
        'language': 'Georgian',
        'celebrity': 'Katie Melua',
      },
      'HK': {
        'population': '7.5M',
        'continent': 'Asia',
        'currency': 'Hong Kong Dollar (HKD)',
        'religion': 'Buddhism',
        'headOfState': 'John Lee',
        'sport': 'Football',
        'language': 'Cantonese',
        'celebrity': 'Jackie Chan',
      },
      'JO': {
        'population': '11M',
        'continent': 'Asia',
        'currency': 'Jordanian Dinar (JOD)',
        'religion': 'Islam',
        'headOfState': 'King Abdullah II',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Queen Rania',
      },
      'KG': {
        'population': '7M',
        'continent': 'Asia',
        'currency': 'Kyrgyzstani Som (KGS)',
        'religion': 'Islam',
        'headOfState': 'Sadyr Japarov',
        'sport': 'Football',
        'language': 'Kyrgyz',
        'celebrity': 'Chinghiz Aitmatov',
      },
      'KH': {
        'population': '17M',
        'continent': 'Asia',
        'currency': 'Cambodian Riel (KHR)',
        'religion': 'Buddhism',
        'headOfState': 'Hun Manet',
        'sport': 'Football',
        'language': 'Khmer',
        'celebrity': 'Norodom Sihanouk',
      },
      'KP': {
        'population': '26M',
        'continent': 'Asia',
        'currency': 'North Korean Won (KPW)',
        'religion': 'None (state atheism)',
        'headOfState': 'Kim Jong Un',
        'sport': 'Football',
        'language': 'Korean',
        'celebrity': 'Kim Yo Jong',
      },
      'KW': {
        'population': '4.3M',
        'continent': 'Asia',
        'currency': 'Kuwaiti Dinar (KWD)',
        'religion': 'Islam',
        'headOfState': 'Emir Meshal Al-Ahmad Al-Jaber Al-Sabah',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Mishari Rashid Alafasy',
      },
      'LA': {
        'population': '7.7M',
        'continent': 'Asia',
        'currency': 'Lao Kip (LAK)',
        'religion': 'Buddhism',
        'headOfState': 'Thongloun Sisoulith',
        'sport': 'Football',
        'language': 'Lao',
        'celebrity': 'Sisavang Vong',
      },
      'LB': {
        'population': '5.5M',
        'continent': 'Asia',
        'currency': 'Lebanese Pound (LBP)',
        'religion': 'Islam',
        'headOfState': 'Joseph Aoun',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Fairuz',
      },
      'LK': {
        'population': '22M',
        'continent': 'Asia',
        'currency': 'Sri Lankan Rupee (LKR)',
        'religion': 'Buddhism',
        'headOfState': 'Anura Kumara Dissanayake',
        'sport': 'Cricket',
        'language': 'Sinhala/Tamil',
        'celebrity': 'Muttiah Muralitharan',
      },
      'MM': {
        'population': '54M',
        'continent': 'Asia',
        'currency': 'Myanmar Kyat (MMK)',
        'religion': 'Buddhism',
        'headOfState': 'Min Aung Hlaing',
        'sport': 'Football',
        'language': 'Burmese',
        'celebrity': 'Aung San Suu Kyi',
      },
      'MN': {
        'population': '3.4M',
        'continent': 'Asia',
        'currency': 'Mongolian Tögrög (MNT)',
        'religion': 'Buddhism',
        'headOfState': 'Ukhnaagiin Khürelsükh',
        'sport': 'Wrestling',
        'language': 'Mongolian',
        'celebrity': 'Genghis Khan',
      },
      'MO': {
        'population': '700K',
        'continent': 'Asia',
        'currency': 'Macanese Pataca (MOP)',
        'religion': 'Buddhism',
        'headOfState': 'Sam Hou Fai',
        'sport': 'Football',
        'language': 'Cantonese',
        'celebrity': 'Stanley Ho',
      },
      'MV': {
        'population': '520K',
        'continent': 'Asia',
        'currency': 'Maldivian Rufiyaa (MVR)',
        'religion': 'Islam',
        'headOfState': 'Mohamed Muizzu',
        'sport': 'Football',
        'language': 'Dhivehi',
        'celebrity': 'Mohamed Nasheed',
      },
      'NP': {
        'population': '30M',
        'continent': 'Asia',
        'currency': 'Nepalese Rupee (NPR)',
        'religion': 'Hinduism',
        'headOfState': 'Sushila Karki',
        'sport': 'Volleyball',
        'language': 'Nepali',
        'celebrity': 'Tenzing Norgay',
      },
      'OM': {
        'population': '4.6M',
        'continent': 'Asia',
        'currency': 'Omani Rial (OMR)',
        'religion': 'Islam',
        'headOfState': 'Sultan Haitham bin Tariq',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Sultan Qaboos',
      },
      'PS': {
        'population': '5.4M',
        'continent': 'Asia',
        'currency': 'Israeli New Shekel (ILS)',
        'religion': 'Islam',
        'headOfState': 'Mahmoud Abbas',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Mahmoud Darwish',
      },
      'QA': {
        'population': '2.9M',
        'continent': 'Asia',
        'currency': 'Qatari Riyal (QAR)',
        'religion': 'Islam',
        'headOfState': 'Emir Tamim bin Hamad Al Thani',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Sheikha Moza bint Nasser',
      },
      'SY': {
        'population': '23M',
        'continent': 'Asia',
        'currency': 'Syrian Pound (SYP)',
        'religion': 'Islam',
        'headOfState': 'Ahmed al-Sharaa',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Asmahan',
      },
      'TJ': {
        'population': '10M',
        'continent': 'Asia',
        'currency': 'Tajikistani Somoni (TJS)',
        'religion': 'Islam',
        'headOfState': 'Emomali Rahmon',
        'sport': 'Football',
        'language': 'Tajik',
        'celebrity': 'Rudaki',
      },
      'TL': {
        'population': '1.3M',
        'continent': 'Asia',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'José Ramos-Horta',
        'sport': 'Football',
        'language': 'Tetum/Portuguese',
        'celebrity': 'Xanana Gusmão',
      },
      'TM': {
        'population': '6.3M',
        'continent': 'Asia',
        'currency': 'Turkmenistan Manat (TMT)',
        'religion': 'Islam',
        'headOfState': 'Serdar Berdimuhamedow',
        'sport': 'Football',
        'language': 'Turkmen',
        'celebrity': 'Saparmurat Niyazov',
      },
      'TW': {
        'population': '23.5M',
        'continent': 'Asia',
        'currency': 'New Taiwan Dollar (TWD)',
        'religion': 'Buddhism',
        'headOfState': 'Lai Ching-te',
        'sport': 'Baseball',
        'language': 'Mandarin',
        'celebrity': 'Ang Lee',
      },
      'UZ': {
        'population': '36M',
        'continent': 'Asia',
        'currency': 'Uzbekistani Som (UZS)',
        'religion': 'Islam',
        'headOfState': 'Shavkat Mirziyoyev',
        'sport': 'Football',
        'language': 'Uzbek',
        'celebrity': 'Islam Karimov',
      },
      'XC': {
        'population': '380K',
        'continent': 'Asia',
        'currency': 'Turkish Lira (TRY)',
        'religion': 'Islam',
        'headOfState': 'Tufan Erhürman',
        'sport': 'Football',
        'language': 'Turkish',
        'celebrity': 'Rauf Denktaş',
      },
      'YE': {
        'population': '34M',
        'continent': 'Asia',
        'currency': 'Yemeni Rial (YER)',
        'religion': 'Islam',
        'headOfState': 'Rashad al-Alimi',
        'sport': 'Football',
        'language': 'Arabic',
        'celebrity': 'Ali Abdullah Saleh',
      },
      'AD': {
        'population': '80K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Xavier Espot Zamora',
        'sport': 'Football (Soccer)',
        'language': 'Catalan',
        'celebrity': 'Charlemagne',
      },
      'AL': {
        'population': '2.8M',
        'continent': 'Europe',
        'currency': 'Albanian Lek (ALL)',
        'religion': 'Islam',
        'headOfState': 'Edi Rama',
        'sport': 'Football (Soccer)',
        'language': 'Albanian',
        'celebrity': 'Ismail Kadare',
      },
      'AX': {
        'population': '30K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Lutheranism',
        'headOfState': 'Veronica Thörnroos',
        'sport': 'Sailing',
        'language': 'Swedish',
        'celebrity': 'Gustaf Erikson',
      },
      'BA': {
        'population': '3.2M',
        'continent': 'Europe',
        'currency': 'Bosnia-Herzegovina Convertible Mark (BAM)',
        'religion': 'Islam',
        'headOfState': 'Borjana Krišto',
        'sport': 'Football (Soccer)',
        'language': 'Bosnian',
        'celebrity': 'Emir Kusturica',
      },
      'BY': {
        'population': '9.1M',
        'continent': 'Europe',
        'currency': 'Belarusian Ruble (BYN)',
        'religion': 'Eastern Orthodoxy',
        'headOfState': 'Alexander Lukashenko',
        'sport': 'Ice Hockey',
        'language': 'Belarusian',
        'celebrity': 'Victoria Azarenka',
      },
      'CY': {
        'population': '1.2M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Greek Orthodox Christianity',
        'headOfState': 'Nikos Christodoulides',
        'sport': 'Football (Soccer)',
        'language': 'Greek',
        'celebrity': 'Marcos Baghdatis',
      },
      'EE': {
        'population': '1.3M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Lutheranism',
        'headOfState': 'Kristen Michal',
        'sport': 'Basketball',
        'language': 'Estonian',
        'celebrity': 'Paul Keres',
      },
      'FO': {
        'population': '54K',
        'continent': 'Europe',
        'currency': 'Danish Krone (DKK)',
        'religion': 'Lutheranism',
        'headOfState': 'Aksel V. Johannesen',
        'sport': 'Football (Soccer)',
        'language': 'Faroese',
        'celebrity': 'Eivør Pálsdóttir',
      },
      'GG': {
        'population': '63K',
        'continent': 'Europe',
        'currency': 'Guernsey Pound (GGP)',
        'religion': 'Anglican Christianity',
        'headOfState': 'Lyndon Trott',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Victor Hugo',
      },
      'GI': {
        'population': '33K',
        'continent': 'Europe',
        'currency': 'Gibraltar Pound (GIP)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Fabian Picardo',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'John Galliano',
      },
      'GL': {
        'population': '56K',
        'continent': 'North America',
        'currency': 'Danish Krone (DKK)',
        'religion': 'Lutheranism',
        'headOfState': 'Jens-Frederik Nielsen',
        'sport': 'Handball',
        'language': 'Greenlandic',
        'celebrity': 'Knud Rasmussen',
      },
      'IM': {
        'population': '84K',
        'continent': 'Europe',
        'currency': 'Manx Pound (IMP)',
        'religion': 'Anglican Christianity',
        'headOfState': 'Alfred Cannan',
        'sport': 'Motorcycle Racing (Isle of Man TT)',
        'language': 'English',
        'celebrity': 'Barry Gibb',
      },
      'IS': {
        'population': '390K',
        'continent': 'Europe',
        'currency': 'Icelandic Króna (ISK)',
        'religion': 'Lutheranism',
        'headOfState': 'Kristrún Frostadóttir',
        'sport': 'Football (Soccer)',
        'language': 'Icelandic',
        'celebrity': 'Björk',
      },
      'JE': {
        'population': '103K',
        'continent': 'Europe',
        'currency': 'Jersey Pound (JEP)',
        'religion': 'Anglican Christianity',
        'headOfState': 'Lyndon Farnham',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Lillie Langtry',
      },
      'LI': {
        'population': '40K',
        'continent': 'Europe',
        'currency': 'Swiss Franc (CHF)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Prince Hans-Adam II',
        'sport': 'Football (Soccer)',
        'language': 'German',
        'celebrity': 'Hanni Wenzel',
      },
      'LT': {
        'population': '2.7M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Gitanas Nausėda',
        'sport': 'Basketball',
        'language': 'Lithuanian',
        'celebrity': 'Arvydas Sabonis',
      },
      'LU': {
        'population': '660K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Luc Frieden',
        'sport': 'Football (Soccer)',
        'language': 'Luxembourgish',
        'celebrity': 'Andy Schleck',
      },
      'LV': {
        'population': '1.8M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Lutheranism',
        'headOfState': 'Edgars Rinkēvičs',
        'sport': 'Ice Hockey',
        'language': 'Latvian',
        'celebrity': 'Kristaps Porziņģis',
      },
      'MC': {
        'population': '39K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Prince Albert II',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Grace Kelly',
      },
      'MD': {
        'population': '2.5M',
        'continent': 'Europe',
        'currency': 'Moldovan Leu (MDL)',
        'religion': 'Eastern Orthodoxy',
        'headOfState': 'Maia Sandu',
        'sport': 'Football (Soccer)',
        'language': 'Romanian',
        'celebrity': 'Dan Bălan',
      },
      'ME': {
        'population': '620K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Eastern Orthodoxy',
        'headOfState': 'Jakov Milatović',
        'sport': 'Water Polo',
        'language': 'Montenegrin',
        'celebrity': 'Nikola Vučević',
      },
      'MK': {
        'population': '1.8M',
        'continent': 'Europe',
        'currency': 'Macedonian Denar (MKD)',
        'religion': 'Eastern Orthodoxy',
        'headOfState': 'Gordana Siljanovska-Davkova',
        'sport': 'Handball',
        'language': 'Macedonian',
        'celebrity': 'Mother Teresa',
      },
      'MT': {
        'population': '540K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Robert Abela',
        'sport': 'Football (Soccer)',
        'language': 'Maltese',
        'celebrity': 'Joseph Calleja',
      },
      'SI': {
        'population': '2.1M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Nataša Pirc Musar',
        'sport': 'Basketball',
        'language': 'Slovenian',
        'celebrity': 'Luka Dončić',
      },
      'SK': {
        'population': '5.4M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Robert Fico',
        'sport': 'Ice Hockey',
        'language': 'Slovak',
        'celebrity': 'Peter Sagan',
      },
      'SM': {
        'population': '34K',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Captains Regent',
        'sport': 'Football (Soccer)',
        'language': 'Italian',
        'celebrity': 'Saint Marinus',
      },
      'VA': {
        'population': '800',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Roman Catholicism',
        'headOfState': 'Pope Leo XIV',
        'sport': 'Football (Soccer)',
        'language': 'Italian',
        'celebrity': 'Pope John Paul II',
      },
      'XK': {
        'population': '1.6M',
        'continent': 'Europe',
        'currency': 'Euro (EUR)',
        'religion': 'Islam',
        'headOfState': 'Albin Kurti',
        'sport': 'Judo',
        'language': 'Albanian',
        'celebrity': 'Dua Lipa',
      },
      'AG': {
        'population': '100K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Gaston Browne',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Viv Richards',
      },
      'AW': {
        'population': '100K',
        'continent': 'North America',
        'currency': 'Aruban Florin (AWG)',
        'religion': 'Christianity',
        'headOfState': 'Evelyn Wever-Croes',
        'sport': 'Baseball',
        'language': 'Dutch',
        'celebrity': 'Xander Bogaerts',
      },
      'BB': {
        'population': '300K',
        'continent': 'North America',
        'currency': 'Barbadian Dollar (BBD)',
        'religion': 'Christianity',
        'headOfState': 'Mia Mottley',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Rihanna',
      },
      'BM': {
        'population': '60K',
        'continent': 'North America',
        'currency': 'Bermudian Dollar (BMD)',
        'religion': 'Christianity',
        'headOfState': 'David Burt',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Flora Duffy',
      },
      'BO': {
        'population': '12M',
        'continent': 'South America',
        'currency': 'Boliviano (BOB)',
        'religion': 'Christianity',
        'headOfState': 'Rodrigo Paz',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Evo Morales',
      },
      'BS': {
        'population': '400K',
        'continent': 'North America',
        'currency': 'Bahamian Dollar (BSD)',
        'religion': 'Christianity',
        'headOfState': 'Philip Davis',
        'sport': 'Athletics (Track and Field)',
        'language': 'English',
        'celebrity': 'Sidney Poitier',
      },
      'BZ': {
        'population': '400K',
        'continent': 'North America',
        'currency': 'Belize Dollar (BZD)',
        'religion': 'Christianity',
        'headOfState': 'John Briceño',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Andy Palacio',
      },
      'CK': {
        'population': '15K',
        'continent': 'Oceania',
        'currency': 'New Zealand Dollar (NZD)',
        'religion': 'Christianity',
        'headOfState': 'Mark Brown',
        'sport': 'Rugby Union',
        'language': 'English',
        'celebrity': 'Kevin Iro',
      },
      'CR': {
        'population': '5M',
        'continent': 'North America',
        'currency': 'Costa Rican Colón (CRC)',
        'religion': 'Christianity',
        'headOfState': 'Rodrigo Chaves',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Keylor Navas',
      },
      'CW': {
        'population': '150K',
        'continent': 'North America',
        'currency': 'Netherlands Antillean Guilder (ANG)',
        'religion': 'Christianity',
        'headOfState': 'Gilmar Pisas',
        'sport': 'Baseball',
        'language': 'Dutch',
        'celebrity': 'Andruw Jones',
      },
      'DM': {
        'population': '70K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Roosevelt Skerrit',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Jean Rhys',
      },
      'DO': {
        'population': '11M',
        'continent': 'North America',
        'currency': 'Dominican Peso (DOP)',
        'religion': 'Christianity',
        'headOfState': 'Luis Abinader',
        'sport': 'Baseball',
        'language': 'Spanish',
        'celebrity': 'David Ortiz',
      },
      'FK': {
        'population': '4K',
        'continent': 'South America',
        'currency': 'Falkland Islands Pound (FKP)',
        'religion': 'Christianity',
        'headOfState': 'Alison Blake',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Rex Hunt',
      },
      'FM': {
        'population': '100K',
        'continent': 'Oceania',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Wesley Simina',
        'sport': 'Basketball',
        'language': 'English',
        'celebrity': 'Manny Minginfel',
      },
      'GD': {
        'population': '100K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Dickon Mitchell',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Kirani James',
      },
      'GU': {
        'population': '200K',
        'continent': 'Oceania',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Lou Leon Guerrero',
        'sport': 'Basketball',
        'language': 'English',
        'celebrity': 'Frank Camacho',
      },
      'GY': {
        'population': '800K',
        'continent': 'South America',
        'currency': 'Guyanese Dollar (GYD)',
        'religion': 'Christianity',
        'headOfState': 'Irfaan Ali',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Shivnarine Chanderpaul',
      },
      'HN': {
        'population': '10M',
        'continent': 'North America',
        'currency': 'Honduran Lempira (HNL)',
        'religion': 'Christianity',
        'headOfState': 'Xiomara Castro',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'America Ferrera',
      },
      'HT': {
        'population': '12M',
        'continent': 'North America',
        'currency': 'Haitian Gourde (HTG)',
        'religion': 'Christianity',
        'headOfState': 'Alix Didier Fils-Aimé',
        'sport': 'Football (Soccer)',
        'language': 'Haitian Creole',
        'celebrity': 'Wyclef Jean',
      },
      'JM': {
        'population': '3M',
        'continent': 'North America',
        'currency': 'Jamaican Dollar (JMD)',
        'religion': 'Christianity',
        'headOfState': 'Andrew Holness',
        'sport': 'Athletics (Track and Field)',
        'language': 'English',
        'celebrity': 'Usain Bolt',
      },
      'KI': {
        'population': '100K',
        'continent': 'Oceania',
        'currency': 'Australian Dollar (AUD)',
        'religion': 'Christianity',
        'headOfState': 'Taneti Maamau',
        'sport': 'Weightlifting',
        'language': 'English',
        'celebrity': 'David Katoatau',
      },
      'KN': {
        'population': '50K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Terrance Drew',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Kim Collins',
      },
      'LC': {
        'population': '200K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Philip J. Pierre',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Derek Walcott',
      },
      'MH': {
        'population': '40K',
        'continent': 'Oceania',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Hilda Heine',
        'sport': 'Basketball',
        'language': 'Marshallese',
        'celebrity': 'Kathy Jetnil-Kijiner',
      },
      'NC': {
        'population': '300K',
        'continent': 'Oceania',
        'currency': 'CFP Franc (XPF)',
        'religion': 'Christianity',
        'headOfState': 'Alcide Ponga',
        'sport': 'Football (Soccer)',
        'language': 'French',
        'celebrity': 'Christian Karembeu',
      },
      'NI': {
        'population': '7M',
        'continent': 'North America',
        'currency': 'Nicaraguan Córdoba (NIO)',
        'religion': 'Christianity',
        'headOfState': 'Daniel Ortega',
        'sport': 'Baseball',
        'language': 'Spanish',
        'celebrity': 'Rubén Darío',
      },
      'NR': {
        'population': '10K',
        'continent': 'Oceania',
        'currency': 'Australian Dollar (AUD)',
        'religion': 'Christianity',
        'headOfState': 'David Adeang',
        'sport': 'Australian Rules Football',
        'language': 'Nauruan',
        'celebrity': 'Marcus Stephen',
      },
      'PR': {
        'population': '3M',
        'continent': 'North America',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Jenniffer González-Colón',
        'sport': 'Baseball',
        'language': 'Spanish',
        'celebrity': 'Bad Bunny',
      },
      'PW': {
        'population': '20K',
        'continent': 'Oceania',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Surangel Whipps Jr.',
        'sport': 'Basketball',
        'language': 'Palauan',
        'celebrity': 'Tommy Remengesau Jr.',
      },
      'SB': {
        'population': '700K',
        'continent': 'Oceania',
        'currency': 'Solomon Islands Dollar (SBD)',
        'religion': 'Christianity',
        'headOfState': 'Jeremiah Manele',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Sir Peter Kenilorea',
      },
      'SR': {
        'population': '600K',
        'continent': 'South America',
        'currency': 'Surinamese Dollar (SRD)',
        'religion': 'Christianity',
        'headOfState': 'Jennifer Geerlings-Simons',
        'sport': 'Football (Soccer)',
        'language': 'Dutch',
        'celebrity': 'Ruud Gullit',
      },
      'SV': {
        'population': '6M',
        'continent': 'North America',
        'currency': 'US Dollar (USD)',
        'religion': 'Christianity',
        'headOfState': 'Nayib Bukele',
        'sport': 'Football (Soccer)',
        'language': 'Spanish',
        'celebrity': 'Jorge "El Mágico" González',
      },
      'TO': {
        'population': '100K',
        'continent': 'Oceania',
        'currency': 'Tongan Paʻanga (TOP)',
        'religion': 'Christianity',
        'headOfState': 'Aisake Eke',
        'sport': 'Rugby Union',
        'language': 'Tongan',
        'celebrity': 'Pita Taufatofua',
      },
      'TT': {
        'population': '1.5M',
        'continent': 'North America',
        'currency': 'Trinidad and Tobago Dollar (TTD)',
        'religion': 'Christianity',
        'headOfState': 'Kamla Persad-Bissessar',
        'sport': 'Football (Soccer)',
        'language': 'English',
        'celebrity': 'Nicki Minaj',
      },
      'TV': {
        'population': '10K',
        'continent': 'Oceania',
        'currency': 'Australian Dollar (AUD)',
        'religion': 'Christianity',
        'headOfState': 'Feleti Teo',
        'sport': 'Football (Soccer)',
        'language': 'Tuvaluan',
        'celebrity': 'Simon Kofe',
      },
      'VC': {
        'population': '100K',
        'continent': 'North America',
        'currency': 'East Caribbean Dollar (XCD)',
        'religion': 'Christianity',
        'headOfState': 'Ralph Gonsalves',
        'sport': 'Cricket',
        'language': 'English',
        'celebrity': 'Kevin Lyttle',
      },
      'VU': {
        'population': '300K',
        'continent': 'Oceania',
        'currency': 'Vanuatu Vatu (VUV)',
        'religion': 'Christianity',
        'headOfState': 'Jotham Napat',
        'sport': 'Football (Soccer)',
        'language': 'Bislama',
        'celebrity': 'Walter Lini',
      },
      'WS': {
        'population': '200K',
        'continent': 'Oceania',
        'currency': 'Samoan Tala (WST)',
        'religion': 'Christianity',
        'headOfState': "La'auli Leuatea Schmidt",
        'sport': 'Rugby Union',
        'language': 'Samoan',
        'celebrity': 'Dwayne Johnson',
      },
      'AQ': {
        'population': '1-5K (researchers)',
        'continent': 'Antarctica',
        'currency': 'None (research stations)',
        'religion': 'None',
        'headOfState': 'Antarctic Treaty System',
        'sport': 'Skiing',
        'language': 'Multinational',
        'celebrity': 'Ernest Shackleton',
      },
    };

    // Celebrity pool — adds variety so the same person doesn't always appear.
    // When 'celebrity' is selected, one is picked at random from the pool.
    const celebrityPool = <String, List<String>>{
      'US': [
        'Beyoncé',
        'Taylor Swift',
        'LeBron James',
        'Oprah Winfrey',
        'Tom Hanks',
        'Elon Musk'
      ],
      'GB': [
        'David Beckham',
        'Adele',
        'Ed Sheeran',
        'Emma Watson',
        'Elton John',
        'David Attenborough'
      ],
      'FR': [
        'Zinedine Zidane',
        'Marion Cotillard',
        'Thierry Henry',
        'Brigitte Bardot',
        'Kylian Mbappé',
        'Coco Chanel'
      ],
      'DE': [
        'Albert Einstein',
        'Jürgen Klopp',
        'Heidi Klum',
        'Ludwig van Beethoven',
        'Michael Schumacher',
        'Boris Becker'
      ],
      'BR': [
        'Pelé',
        'Neymar',
        'Gisele Bündchen',
        'Ayrton Senna',
        'Ronaldinho',
        'Caetano Veloso'
      ],
      'IN': [
        'Shah Rukh Khan',
        'Sachin Tendulkar',
        'Priyanka Chopra',
        'Virat Kohli',
        'Amitabh Bachchan',
        'Sundar Pichai'
      ],
      'JP': [
        'Shohei Ohtani',
        'Hayao Miyazaki',
        'Naomi Osaka',
        'Yoko Ono',
        'Marie Kondo',
        'Akira Kurosawa'
      ],
      'AU': [
        'Hugh Jackman',
        'Nicole Kidman',
        'Steve Irwin',
        'Margot Robbie',
        'Kylie Minogue',
        'Chris Hemsworth'
      ],
      'CA': [
        'Drake',
        'Ryan Reynolds',
        'Céline Dion',
        'Justin Bieber',
        'Keanu Reeves',
        'Wayne Gretzky'
      ],
      'IT': [
        'Leonardo da Vinci',
        'Andrea Bocelli',
        'Monica Bellucci',
        'Roberto Baggio',
        'Sophia Loren',
        'Valentino Rossi'
      ],
      'ES': [
        'Rafael Nadal',
        'Penélope Cruz',
        'Andrés Iniesta',
        'Antonio Banderas',
        'Pablo Picasso',
        'Enrique Iglesias'
      ],
      'MX': [
        'Salma Hayek',
        'Guillermo del Toro',
        'Frida Kahlo',
        'Canelo Álvarez',
        'Carlos Slim',
        'Octavio Paz'
      ],
      'AR': [
        'Lionel Messi',
        'Diego Maradona',
        'Pope Francis',
        'Eva Perón',
        'Che Guevara',
        'Jorge Luis Borges'
      ],
      'NG': [
        'Wizkid',
        'Burna Boy',
        'Chimamanda Ngozi Adichie',
        'Tiwa Savage',
        'Davido',
        'Wole Soyinka'
      ],
      'KR': [
        'BTS',
        'Son Heung-min',
        'BLACKPINK',
        'Bong Joon-ho',
        'Park Ji-sung',
        'PSY'
      ],
      'ZA': [
        'Nelson Mandela',
        'Trevor Noah',
        'Charlize Theron',
        'Elon Musk',
        'Siya Kolisi',
        'Desmond Tutu'
      ],
      'EG': [
        'Mohamed Salah',
        'Omar Sharif',
        'Cleopatra',
        'Naguib Mahfouz',
        'Ahmed Zewail',
        'Tutankhamun'
      ],
      'CN': [
        'Jackie Chan',
        'Yao Ming',
        'Jack Ma',
        'Jet Li',
        'Fan Bingbing',
        'Zhang Yimou'
      ],
      'RU': [
        'Maria Sharapova',
        'Leo Tolstoy',
        'Garry Kasparov',
        'Anna Pavlova',
        'Yuri Gagarin',
        'Pyotr Tchaikovsky'
      ],
      'CO': [
        'Shakira',
        'James Rodríguez',
        'Gabriel García Márquez',
        'Sofía Vergara',
        'Juan Valdez',
        'Maluma'
      ],
    };

    final countryStats = allStats[code];
    // Return empty map if country not found - caller should handle by picking different clue type
    if (countryStats == null) return <String, dynamic>{};

    // Build a mutable copy so we can swap in a random celebrity.
    final stats = Map<String, dynamic>.from(countryStats);

    // Merge runtime overrides (headOfState/population) refreshed weekly from
    // Wikidata into assets/data/country_stats.json. JSON wins when present.
    // When the override asset never loaded (offline/tests/failure), this is a
    // no-op and the baked-in Dart baseline is used unchanged. This only ever
    // changes stat *text* — never the deterministic clue-type selection.
    final overrides = CountryStats.instance.overridesFor(code);
    if (overrides != null) {
      for (final entry in overrides.entries) {
        if (entry.value.isNotEmpty) stats[entry.key] = entry.value;
      }
    }

    final pool = celebrityPool[code];
    if (pool != null && pool.isNotEmpty) {
      final rng = random ?? Random();
      stats['celebrity'] = pool[rng.nextInt(pool.length)];
    }

    // Return all stats when requested (e.g. for the clues browser).
    if (returnAll) return stats;

    // Pick a random trio of stats from all available keys.
    // Use the provided seeded RNG when available so H2H players see the same
    // three facts; fall back to an unseeded Random for free-play.
    final keys = stats.keys.toList()..shuffle(random ?? Random());
    final selectedKeys = keys.take(3).toList();

    final result = <String, dynamic>{};
    for (final key in selectedKeys) {
      result[key] = stats[key];
    }
    return result;
  }
}
