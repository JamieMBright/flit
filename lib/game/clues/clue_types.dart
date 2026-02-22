import 'dart:math';

import 'package:flame/components.dart';

import '../data/canada_clues.dart';
import '../data/ireland_clues.dart';
import '../data/uk_clues.dart';
import '../data/us_state_clues.dart';
import '../map/country_data.dart';
import '../map/region.dart';

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
      displayData: {'flagEmoji': _countryCodeToFlagEmoji(countryCode)},
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
  factory Clue.stats(String countryCode) {
    return Clue(
      type: ClueType.stats,
      targetCountryCode: countryCode,
      displayData: _getCountryStats(countryCode),
    );
  }

  /// Generate a random clue for a country, with validation to avoid "Unknown" data.
  ///
  /// When [allowedTypes] is provided (e.g. from a daily challenge theme),
  /// only those clue types will be considered. This overrides the
  /// [preferredClueType]/[clueBoost] mechanism.
  ///
  /// When [preferredClueType] and [clueBoost] are provided, the preferred
  /// type has [clueBoost]% more chance of being selected (e.g. clueBoost=5
  /// gives the preferred type a 5 percentage-point bonus).
  factory Clue.random(
    String countryCode, {
    String? preferredClueType,
    int clueBoost = 0,
    Set<String>? allowedTypes,
  }) {
    // Determine the pool of clue types to draw from.
    final List<ClueType> typePool;
    if (allowedTypes != null && allowedTypes.isNotEmpty) {
      typePool = ClueType.values
          .where((t) => allowedTypes.contains(t.name))
          .toList();
    } else {
      typePool = ClueType.values.toList();
    }
    // If the filter left nothing valid, fall back to all types.
    final types = typePool.isEmpty ? ClueType.values : typePool;
    final random = Random();
    final triedTypes = <ClueType>{};
    const maxRetries = 10;

    // Resolve preferred ClueType enum from the string name.
    ClueType? preferredType;
    if (preferredClueType != null && clueBoost > 0) {
      for (final t in types) {
        if (t.name == preferredClueType) {
          preferredType = t;
          break;
        }
      }
    }

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      // Get available types that haven't been tried yet
      final availableTypes = types
          .where((t) => !triedTypes.contains(t))
          .toList();
      if (availableTypes.isEmpty) break;

      ClueType randomType;
      // If we have a preferred type and it hasn't been tried, give it a
      // [clueBoost]% chance of being picked directly.
      if (preferredType != null &&
          availableTypes.contains(preferredType) &&
          random.nextInt(100) < clueBoost) {
        randomType = preferredType;
      } else {
        randomType = availableTypes[random.nextInt(availableTypes.length)];
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
          clue = Clue.stats(countryCode);
          break;
        // Regional types fallback to stats for world mode
        case ClueType.sportsTeam:
        case ClueType.leader:
        case ClueType.nickname:
        case ClueType.landmark:
        case ClueType.flagDescription:
          clue = Clue.stats(countryCode);
          break;
      }

      // Validate the clue - if valid, return it
      if (_isValidClue(clue)) {
        return clue;
      }
    }

    // Fallback: if all retries failed, return flag clue (most reliable)
    return Clue.flag(countryCode);
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
        return displayData['flagEmoji'] as String;
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
        // recognisable.  Countries with fewer than 10 total vertices look
        // like generic rectangles and are impossible to identify by shape.
        final polygons = clue.displayData['polygons'] as List?;
        final points = clue.displayData['points'] as List?;
        if (polygons != null && polygons.isNotEmpty) {
          var totalVertices = 0;
          for (final poly in polygons) {
            totalVertices += (poly as List).length;
          }
          return totalVertices >= 10;
        }
        if (points != null && points.length >= 10) return true;
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

  static String _countryCodeToFlagEmoji(String code) {
    // Convert country code to flag emoji
    // Each letter is converted to regional indicator symbol
    final codeUnits = code.toUpperCase().codeUnits;
    final flagCodeUnits = codeUnits.map((c) => c + 127397).toList();
    return String.fromCharCodes(flagCodeUnits);
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
    };
    // Return empty list if country not found - caller should handle by picking different clue type
    return neighbors[code] ?? <String>[];
  }

  /// Full stats database for each country. A random trio is selected at runtime.
  static Map<String, dynamic> _getCountryStats(String code) {
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
    };

    final countryStats = allStats[code];
    // Return empty map if country not found - caller should handle by picking different clue type
    if (countryStats == null) return <String, dynamic>{};

    // Pick a random trio of stats from all available keys
    final keys = countryStats.keys.toList()..shuffle(Random());
    final selectedKeys = keys.take(3).toList();

    final result = <String, dynamic>{};
    for (final key in selectedKeys) {
      result[key] = countryStats[key];
    }
    return result;
  }
}
