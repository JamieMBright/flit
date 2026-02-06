import 'dart:math';

import '../map/country_data.dart';
import '../map/region.dart';

/// Types of clues that can be shown to the player.
enum ClueType {
  flag,
  outline,
  borders,
  capital,
  stats,
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
      displayData: {
        'flagEmoji': _countryCodeToFlagEmoji(countryCode),
      },
    );
  }

  /// Create an outline clue (silhouette)
  factory Clue.outline(String countryCode) {
    final country = CountryData.getCountry(countryCode);
    return Clue(
      type: ClueType.outline,
      targetCountryCode: countryCode,
      displayData: {
        'points': country?.points ?? [],
      },
    );
  }

  /// Create a borders clue (list of neighboring countries)
  factory Clue.borders(String countryCode) {
    return Clue(
      type: ClueType.borders,
      targetCountryCode: countryCode,
      displayData: {
        'neighbors': _getNeighboringCountries(countryCode),
      },
    );
  }

  /// Create a capital clue
  factory Clue.capital(String countryCode) {
    final capital = CountryData.getCapital(countryCode);
    return Clue(
      type: ClueType.capital,
      targetCountryCode: countryCode,
      displayData: {
        'capitalName': capital?.name ?? 'Unknown',
      },
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

  /// Generate a random clue for a country
  factory Clue.random(String countryCode) {
    final types = ClueType.values;
    final randomType = types[Random().nextInt(types.length)];

    switch (randomType) {
      case ClueType.flag:
        return Clue.flag(countryCode);
      case ClueType.outline:
        return Clue.outline(countryCode);
      case ClueType.borders:
        return Clue.borders(countryCode);
      case ClueType.capital:
        return Clue.capital(countryCode);
      case ClueType.stats:
        return Clue.stats(countryCode);
    }
  }

  /// Create a clue for a regional area (state, county, island)
  factory Clue.regionalArea(RegionalArea area) {
    // For regional areas, randomly choose between available clue types
    final random = Random();
    final availableTypes = <ClueType>[ClueType.outline];

    // Add capital clue if area has a capital
    if (area.capital != null) {
      availableTypes.add(ClueType.capital);
    }

    // Add stats clue if area has population
    if (area.population != null) {
      availableTypes.add(ClueType.stats);
    }

    final selectedType = availableTypes[random.nextInt(availableTypes.length)];

    switch (selectedType) {
      case ClueType.outline:
        return Clue(
          type: ClueType.outline,
          targetCountryCode: area.code,
          displayData: {
            'points': area.points,
            'areaName': area.name,
          },
        );
      case ClueType.capital:
        return Clue(
          type: ClueType.capital,
          targetCountryCode: area.code,
          displayData: {
            'capitalName': area.capital ?? 'Unknown',
            'areaName': area.name,
          },
        );
      case ClueType.stats:
        final population = area.population ?? 0;
        String popString;
        if (population >= 1000000) {
          popString = '${(population / 1000000).toStringAsFixed(1)}M';
        } else if (population >= 1000) {
          popString = '${(population / 1000).toStringAsFixed(0)}K';
        } else {
          popString = population.toString();
        }
        return Clue(
          type: ClueType.stats,
          targetCountryCode: area.code,
          displayData: {
            'population': popString,
            'areaName': area.name,
            if (area.funFact != null) 'funFact': area.funFact,
          },
        );
      default:
        // Fallback to outline
        return Clue(
          type: ClueType.outline,
          targetCountryCode: area.code,
          displayData: {
            'points': area.points,
            'areaName': area.name,
          },
        );
    }
  }

  /// Get the display text for this clue
  String get displayText {
    switch (type) {
      case ClueType.flag:
        return displayData['flagEmoji'] as String;
      case ClueType.outline:
        return '🗺️ [Country Outline]';
      case ClueType.borders:
        final neighbors = displayData['neighbors'] as List<String>;
        return 'Borders: ${neighbors.join(', ')}';
      case ClueType.capital:
        return 'Capital: ${displayData['capitalName']}';
      case ClueType.stats:
        return _formatStats(displayData);
    }
  }

  String _formatStats(Map<String, dynamic> stats) {
    final lines = <String>[];
    if (stats['population'] != null) {
      lines.add('Pop: ${stats['population']}');
    }
    if (stats['continent'] != null) {
      lines.add('Continent: ${stats['continent']}');
    }
    if (stats['language'] != null) {
      lines.add('Language: ${stats['language']}');
    }
    return lines.join('\n');
  }

  static String _countryCodeToFlagEmoji(String code) {
    // Convert country code to flag emoji
    // Each letter is converted to regional indicator symbol
    final codeUnits = code.toUpperCase().codeUnits;
    final flagCodeUnits = codeUnits.map((c) => c + 127397).toList();
    return String.fromCharCodes(flagCodeUnits);
  }

  static List<String> _getNeighboringCountries(String code) {
    // Simplified neighbor data
    const Map<String, List<String>> neighbors = {
      'US': ['Canada', 'Mexico'],
      'CA': ['United States'],
      'MX': ['United States', 'Guatemala', 'Belize'],
      'BR': ['Argentina', 'Paraguay', 'Uruguay', 'Bolivia', 'Peru', 'Colombia', 'Venezuela'],
      'AR': ['Chile', 'Bolivia', 'Paraguay', 'Brazil', 'Uruguay'],
      'GB': ['Ireland'],
      'FR': ['Spain', 'Belgium', 'Germany', 'Switzerland', 'Italy'],
      'DE': ['France', 'Belgium', 'Netherlands', 'Poland', 'Czech Republic', 'Austria', 'Switzerland'],
      'IT': ['France', 'Switzerland', 'Austria', 'Slovenia'],
      'ES': ['France', 'Portugal', 'Andorra'],
      'EG': ['Libya', 'Sudan', 'Israel', 'Palestine'],
      'ZA': ['Namibia', 'Botswana', 'Zimbabwe', 'Mozambique', 'Eswatini', 'Lesotho'],
      'CN': ['Russia', 'Mongolia', 'North Korea', 'Vietnam', 'Laos', 'Myanmar', 'India', 'Nepal', 'Pakistan'],
      'IN': ['Pakistan', 'China', 'Nepal', 'Bangladesh', 'Myanmar'],
      'JP': <String>[],
      'RU': ['Norway', 'Finland', 'Estonia', 'Latvia', 'Belarus', 'Ukraine', 'Georgia', 'Azerbaijan', 'Kazakhstan', 'China', 'Mongolia', 'North Korea'],
      'AU': <String>[],
    };
    return neighbors[code] ?? ['Unknown'];
  }

  static Map<String, dynamic> _getCountryStats(String code) {
    // Simplified stats data
    const stats = {
      'US': {'population': '331M', 'continent': 'North America', 'language': 'English'},
      'CA': {'population': '38M', 'continent': 'North America', 'language': 'English/French'},
      'MX': {'population': '128M', 'continent': 'North America', 'language': 'Spanish'},
      'BR': {'population': '214M', 'continent': 'South America', 'language': 'Portuguese'},
      'AR': {'population': '45M', 'continent': 'South America', 'language': 'Spanish'},
      'GB': {'population': '67M', 'continent': 'Europe', 'language': 'English'},
      'FR': {'population': '67M', 'continent': 'Europe', 'language': 'French'},
      'DE': {'population': '83M', 'continent': 'Europe', 'language': 'German'},
      'IT': {'population': '60M', 'continent': 'Europe', 'language': 'Italian'},
      'ES': {'population': '47M', 'continent': 'Europe', 'language': 'Spanish'},
      'EG': {'population': '102M', 'continent': 'Africa', 'language': 'Arabic'},
      'ZA': {'population': '60M', 'continent': 'Africa', 'language': 'Many (11 official)'},
      'CN': {'population': '1.4B', 'continent': 'Asia', 'language': 'Mandarin'},
      'IN': {'population': '1.4B', 'continent': 'Asia', 'language': 'Hindi/English'},
      'JP': {'population': '125M', 'continent': 'Asia', 'language': 'Japanese'},
      'RU': {'population': '144M', 'continent': 'Europe/Asia', 'language': 'Russian'},
      'AU': {'population': '26M', 'continent': 'Oceania', 'language': 'English'},
    };
    return stats[code] ?? {'population': 'Unknown'};
  }
}
