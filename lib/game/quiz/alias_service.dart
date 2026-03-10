/// Service for managing runtime country alias overrides.
///
/// The baseline aliases live in the compile-time [countryAliases] map.
/// This service stores user-added aliases in SharedPreferences so they
/// persist across sessions and are picked up by the [FuzzyMatcher].
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/country_aliases.dart';

/// Key used in SharedPreferences to store runtime alias overrides.
const _kRuntimeAliasesKey = 'runtime_country_aliases';

/// Manages country name aliases with runtime override support.
///
/// Merges the compile-time [countryAliases] with any user-added overrides
/// stored in SharedPreferences.
class AliasService {
  AliasService._();
  static final AliasService instance = AliasService._();

  /// Runtime overrides (loaded from SharedPreferences).
  Map<String, List<String>> _overrides = {};
  bool _loaded = false;

  /// Load overrides from disk. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kRuntimeAliasesKey);
    if (json != null) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _overrides = decoded.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    }
    _loaded = true;
  }

  /// Save current overrides to disk.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRuntimeAliasesKey, jsonEncode(_overrides));
  }

  /// Get merged aliases for a given canonical name (lowercase).
  ///
  /// Returns the union of compile-time aliases and runtime overrides.
  List<String> getAliases(String canonicalName) {
    final baseline = countryAliases[canonicalName] ?? <String>[];
    final overrides = _overrides[canonicalName] ?? <String>[];
    // Merge, removing duplicates.
    final merged = <String>{...baseline, ...overrides};
    return merged.toList()..sort();
  }

  /// Get only the runtime override aliases for a given canonical name.
  List<String> getOverrides(String canonicalName) {
    return List.unmodifiable(_overrides[canonicalName] ?? <String>[]);
  }

  /// Whether an alias is a runtime override (not in the baseline).
  bool isOverride(String canonicalName, String alias) {
    final baseline = countryAliases[canonicalName] ?? <String>[];
    return !baseline.contains(alias) &&
        (_overrides[canonicalName]?.contains(alias) ?? false);
  }

  /// Add a runtime alias for [canonicalName].
  Future<void> addAlias(String canonicalName, String alias) async {
    final normalized = alias.toLowerCase().trim();
    if (normalized.isEmpty) return;
    _overrides.putIfAbsent(canonicalName, () => []);
    if (!_overrides[canonicalName]!.contains(normalized)) {
      _overrides[canonicalName]!.add(normalized);
      await _save();
    }
  }

  /// Remove a runtime alias. Only overrides can be removed at runtime;
  /// baseline aliases are hardcoded.
  Future<void> removeAlias(String canonicalName, String alias) async {
    final list = _overrides[canonicalName];
    if (list == null) return;
    list.remove(alias);
    if (list.isEmpty) _overrides.remove(canonicalName);
    await _save();
  }

  /// Get the full merged alias map (baseline + overrides).
  Map<String, List<String>> get mergedAliases {
    final result = <String, List<String>>{};
    // Start with baseline.
    for (final entry in countryAliases.entries) {
      result[entry.key] = List<String>.from(entry.value);
    }
    // Merge in overrides.
    for (final entry in _overrides.entries) {
      result.putIfAbsent(entry.key, () => []);
      for (final alias in entry.value) {
        if (!result[entry.key]!.contains(alias)) {
          result[entry.key]!.add(alias);
        }
      }
    }
    return result;
  }

  /// All canonical names that have aliases (baseline + overrides).
  Set<String> get allCanonicalNames {
    return {...countryAliases.keys, ..._overrides.keys};
  }
}
