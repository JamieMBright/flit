/// Runtime override loader for volatile country stats.
///
/// The baseline stats (population, head of state, etc.) live in the compile-time
/// `allStats` map in [clue_types.dart]. Two of those fields — `headOfState` and
/// `population` — go stale over time (elections, census updates), so a weekly
/// GitHub Action refreshes them from Wikidata (CC0) into
/// `assets/data/country_stats.json`.
///
/// This singleton preloads that JSON asset once at startup and exposes a
/// synchronous [overridesFor] lookup that the clue selection logic merges on top
/// of the baked-in Dart values. Consumers stay synchronous.
///
/// **Fail-safe:** any error (missing asset, malformed JSON, unexpected shape)
/// leaves the overrides empty and is swallowed — the game then behaves exactly
/// as if only the baked-in Dart baseline existed. The override can only ever
/// change stat *text*, never break the game.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Path to the override asset (declared in pubspec.yaml).
const _kAssetPath = 'assets/data/country_stats.json';

/// Loads and serves runtime overrides for volatile country stats.
class CountryStats {
  CountryStats._();

  /// Singleton instance.
  static final CountryStats instance = CountryStats._();

  /// Per-country override fields, keyed by ISO alpha-2 code. Each value maps a
  /// field name (`headOfState`, `population`) to its override string.
  Map<String, Map<String, String>> _overrides = {};

  bool _loaded = false;

  /// Load the override asset. Safe to call multiple times — subsequent calls are
  /// no-ops. On ANY error the overrides are left empty and the error swallowed,
  /// so the game falls back to the baked-in Dart baseline.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final raw = await rootBundle.loadString(_kAssetPath);
      final decoded = json.decode(raw);
      if (decoded is! Map) return;

      final countries = decoded['countries'];
      if (countries is! Map) return;

      final parsed = <String, Map<String, String>>{};
      countries.forEach((code, fields) {
        if (code is! String || fields is! Map) return;
        final entry = <String, String>{};
        fields.forEach((k, v) {
          if (k is String && v is String && v.isNotEmpty) {
            entry[k] = v;
          }
        });
        if (entry.isNotEmpty) parsed[code] = entry;
      });

      _overrides = parsed;
    } catch (e) {
      // Fail-safe: never let a bad asset break the game. Overrides stay empty
      // and consumers fall back to the baked-in Dart values.
      _overrides = {};
    }
  }

  /// Returns the override fields for [code], or `null` if none are present.
  ///
  /// Synchronous by design — the JSON is preloaded once in `main()`.
  Map<String, String>? overridesFor(String code) => _overrides[code];

  /// Test-only: inject overrides directly, bypassing asset loading.
  @visibleForTesting
  void setOverridesForTest(Map<String, Map<String, String>> overrides) {
    _overrides = overrides;
    _loaded = true;
  }

  /// Test-only: reset to the unloaded, empty state.
  @visibleForTesting
  void resetForTest() {
    _overrides = {};
    _loaded = false;
  }
}
