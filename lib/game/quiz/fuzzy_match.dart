/// Fuzzy string matching engine for the Uncharted game mode.
///
/// Supports Levenshtein distance matching, diacritic stripping, and
/// an alias lookup table for common alternative names and misspellings.
library;

import '../data/country_aliases.dart';
import 'alias_service.dart';

/// Result of a fuzzy match attempt.
class FuzzyMatchResult {
  const FuzzyMatchResult({
    required this.code,
    required this.canonicalName,
    required this.distance,
  });

  /// The area code that matched (e.g., 'FR', 'US-CA').
  final String code;

  /// The canonical name of the matched area.
  final String canonicalName;

  /// Levenshtein distance of the match (0 = exact).
  final int distance;

  bool get isExact => distance == 0;
}

/// Fuzzy string matcher for geographic names.
class FuzzyMatcher {
  /// Creates a matcher with the given candidates.
  ///
  /// [candidates] maps area code → canonical name (e.g., 'FR' → 'France').
  FuzzyMatcher(Map<String, String> candidates) {
    // Merge baseline aliases with any runtime overrides.
    final allAliases = AliasService.instance.mergedAliases;

    for (final entry in candidates.entries) {
      final code = entry.key;
      final name = entry.value;
      final normalized = _normalize(name);
      _normalizedToCode[normalized] = code;
      _codeToName[code] = name;

      // Also index alias → code mappings.
      final aliases = allAliases[normalized];
      if (aliases != null) {
        for (final alias in aliases) {
          _aliasToCode[_normalize(alias)] = code;
        }
      }
      // Reverse: check if the canonical name appears as a value in aliases.
      for (final entry in allAliases.entries) {
        for (final alias in entry.value) {
          if (_normalize(alias) == normalized) {
            _aliasToCode[entry.key] = code;
          }
        }
      }
    }
  }

  final Map<String, String> _normalizedToCode = {};
  final Map<String, String> _codeToName = {};
  final Map<String, String> _aliasToCode = {};

  /// Attempts to match [input] against the candidate names.
  ///
  /// Only matches against codes NOT in [excludeCodes] (already revealed).
  /// Returns null if no match is close enough.
  FuzzyMatchResult? bestMatch(
    String input, {
    Set<String> excludeCodes = const {},
  }) {
    final normalizedInput = _normalize(input);
    if (normalizedInput.isEmpty) return null;

    // 1. Exact alias match.
    final aliasCode = _aliasToCode[normalizedInput];
    if (aliasCode != null && !excludeCodes.contains(aliasCode)) {
      return FuzzyMatchResult(
        code: aliasCode,
        canonicalName: _codeToName[aliasCode]!,
        distance: 0,
      );
    }

    // 2. Exact normalized name match.
    final exactCode = _normalizedToCode[normalizedInput];
    if (exactCode != null && !excludeCodes.contains(exactCode)) {
      return FuzzyMatchResult(
        code: exactCode,
        canonicalName: _codeToName[exactCode]!,
        distance: 0,
      );
    }

    // 3. Levenshtein distance against all candidates + aliases.
    String? bestCode;
    int bestDist = 999;

    for (final entry in _normalizedToCode.entries) {
      final code = entry.value;
      if (excludeCodes.contains(code)) continue;
      final dist = _levenshtein(normalizedInput, entry.key);
      if (dist < bestDist) {
        bestDist = dist;
        bestCode = code;
      }
    }

    // Also check aliases.
    for (final entry in _aliasToCode.entries) {
      final code = entry.value;
      if (excludeCodes.contains(code)) continue;
      final dist = _levenshtein(normalizedInput, entry.key);
      if (dist < bestDist) {
        bestDist = dist;
        bestCode = code;
      }
    }

    if (bestCode == null) return null;

    // Threshold: allow more distance for longer names.
    final maxDist = _maxAllowedDistance(normalizedInput.length);
    if (bestDist > maxDist) return null;

    return FuzzyMatchResult(
      code: bestCode,
      canonicalName: _codeToName[bestCode]!,
      distance: bestDist,
    );
  }

  /// Maximum Levenshtein distance allowed for a given input length.
  static int _maxAllowedDistance(int inputLength) {
    if (inputLength <= 4) return 1;
    if (inputLength <= 8) return 2;
    return 3;
  }

  /// Normalize a string: lowercase, strip diacritics, remove punctuation.
  static String _normalize(String s) {
    var result = s.toLowerCase().trim();
    result = _stripDiacritics(result);
    // Remove common punctuation that varies across spellings.
    result = result.replaceAll(RegExp(r"['\-.,()]"), '');
    // Collapse whitespace.
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  /// Strip common diacritics to their ASCII equivalents.
  static String _stripDiacritics(String s) {
    const diacriticMap = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ð': 'd',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ø': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'þ': 'th',
      'ß': 'ss',
      'ł': 'l',
      'ś': 's',
      'ź': 'z',
      'ż': 'z',
      'ć': 'c',
      'ń': 'n',
      'ă': 'a',
      'ș': 's',
      'ț': 't',
      'č': 'c',
      'ď': 'd',
      'ě': 'e',
      'ň': 'n',
      'ř': 'r',
      'š': 's',
      'ť': 't',
      'ů': 'u',
      'ž': 'z',
      'ā': 'a',
      'ē': 'e',
      'ī': 'i',
      'ō': 'o',
      'ū': 'u',
      'İ': 'i',
      'ğ': 'g',
    };
    final buffer = StringBuffer();
    for (final char in s.split('')) {
      buffer.write(diacriticMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Standard Levenshtein distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Optimization: if length difference exceeds max possible threshold, skip.
    final lengthDiff = (a.length - b.length).abs();
    if (lengthDiff > 3) return lengthDiff;

    final m = a.length;
    final n = b.length;

    // Single-row DP for space efficiency.
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = _min3(
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[n];
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= c) return b;
    return c;
  }
}
