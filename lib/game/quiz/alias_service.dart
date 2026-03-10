/// Service for managing runtime country alias overrides.
///
/// The baseline aliases live in the compile-time [countryAliases] map.
/// This service stores user-added aliases and baseline removals in
/// SharedPreferences so they persist across sessions and are picked up
/// by the [FuzzyMatcher].
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/country_aliases.dart';

/// Key used in SharedPreferences to store runtime alias overrides.
const _kRuntimeAliasesKey = 'runtime_country_aliases';

/// Key used in SharedPreferences to store removed baseline aliases.
const _kRemovedBaselineKey = 'removed_baseline_aliases';

/// Manages country name aliases with runtime override support.
///
/// Merges the compile-time [countryAliases] with any user-added overrides
/// stored in SharedPreferences, minus any baseline aliases that have been
/// explicitly removed.
class AliasService {
  AliasService._();
  static final AliasService instance = AliasService._();

  /// Runtime overrides (loaded from SharedPreferences).
  Map<String, List<String>> _overrides = {};

  /// Baseline aliases that have been explicitly removed by admins.
  Map<String, List<String>> _removedBaseline = {};

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

    final removedJson = prefs.getString(_kRemovedBaselineKey);
    if (removedJson != null) {
      final decoded = jsonDecode(removedJson) as Map<String, dynamic>;
      _removedBaseline = decoded.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    }

    _loaded = true;
  }

  /// Save current overrides to disk.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRuntimeAliasesKey, jsonEncode(_overrides));
    await prefs.setString(_kRemovedBaselineKey, jsonEncode(_removedBaseline));
  }

  /// The effective baseline aliases for a name, with removals applied.
  List<String> _effectiveBaseline(String canonicalName) {
    final baseline = countryAliases[canonicalName] ?? <String>[];
    final removed = _removedBaseline[canonicalName] ?? <String>[];
    if (removed.isEmpty) return List<String>.of(baseline);
    return baseline.where((a) => !removed.contains(a)).toList();
  }

  /// Get merged aliases for a given canonical name (lowercase).
  ///
  /// Returns the union of (baseline minus removals) and runtime overrides.
  List<String> getAliases(String canonicalName) {
    final baseline = _effectiveBaseline(canonicalName);
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

  /// Whether a baseline alias has been removed.
  bool isBaselineRemoved(String canonicalName, String alias) {
    return _removedBaseline[canonicalName]?.contains(alias) ?? false;
  }

  /// Whether an alias is a baseline alias (regardless of removal state).
  bool isBaseline(String canonicalName, String alias) {
    return countryAliases[canonicalName]?.contains(alias) ?? false;
  }

  /// Add a runtime alias for [canonicalName].
  Future<void> addAlias(String canonicalName, String alias) async {
    final normalized = alias.toLowerCase().trim();
    if (normalized.isEmpty) return;

    // If this alias was previously a removed baseline, un-remove it instead.
    final removedList = _removedBaseline[canonicalName];
    if (removedList != null && removedList.contains(normalized)) {
      removedList.remove(normalized);
      if (removedList.isEmpty) _removedBaseline.remove(canonicalName);
      await _save();
      return;
    }

    _overrides.putIfAbsent(canonicalName, () => []);
    if (!_overrides[canonicalName]!.contains(normalized)) {
      _overrides[canonicalName]!.add(normalized);
      await _save();
    }
  }

  /// Remove an alias. Works for both runtime overrides and baseline aliases.
  ///
  /// For baseline aliases, the removal is stored so it persists across
  /// sessions. For runtime overrides, the override is simply deleted.
  Future<void> removeAlias(String canonicalName, String alias) async {
    // Check if it's a baseline alias.
    final baseline = countryAliases[canonicalName] ?? <String>[];
    if (baseline.contains(alias)) {
      _removedBaseline.putIfAbsent(canonicalName, () => []);
      if (!_removedBaseline[canonicalName]!.contains(alias)) {
        _removedBaseline[canonicalName]!.add(alias);
      }
      await _save();
      return;
    }

    // Otherwise it's a runtime override.
    final list = _overrides[canonicalName];
    if (list == null) return;
    list.remove(alias);
    if (list.isEmpty) _overrides.remove(canonicalName);
    await _save();
  }

  /// Restore a previously removed baseline alias.
  Future<void> restoreBaselineAlias(
    String canonicalName,
    String alias,
  ) async {
    final list = _removedBaseline[canonicalName];
    if (list == null) return;
    list.remove(alias);
    if (list.isEmpty) _removedBaseline.remove(canonicalName);
    await _save();
  }

  /// Get baseline aliases that have been removed for a canonical name.
  List<String> getRemovedBaseline(String canonicalName) {
    return List.unmodifiable(_removedBaseline[canonicalName] ?? <String>[]);
  }

  /// Get the full merged alias map (baseline − removals + overrides).
  Map<String, List<String>> get mergedAliases {
    final result = <String, List<String>>{};
    // Start with effective baseline (minus removals).
    for (final entry in countryAliases.entries) {
      result[entry.key] = _effectiveBaseline(entry.key);
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
