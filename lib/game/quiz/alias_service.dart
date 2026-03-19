/// Service for managing runtime country alias overrides.
///
/// The baseline aliases live in the compile-time [countryAliases] map.
/// This service stores admin-added aliases and baseline removals in both
/// Supabase (source of truth) and SharedPreferences (local cache / offline
/// fallback), and they are picked up by the [FuzzyMatcher].
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/country_aliases.dart';

/// Key used in SharedPreferences to store runtime alias overrides.
const _kRuntimeAliasesKey = 'runtime_country_aliases';

/// Key used in SharedPreferences to store removed baseline aliases.
const _kRemovedBaselineKey = 'removed_baseline_aliases';

/// Supabase table that persists admin alias changes.
const _kTable = 'country_aliases';

/// Manages country name aliases with runtime override support.
///
/// Merges the compile-time [countryAliases] with any admin-added overrides
/// persisted in Supabase (and cached in SharedPreferences), minus any baseline
/// aliases that have been explicitly removed.
///
/// Load order on [load]:
///   1. Try Supabase — apply rows into in-memory state and write to cache.
///   2. Fall back to SharedPreferences cache if Supabase is unreachable.
class AliasService {
  AliasService._();
  static final AliasService instance = AliasService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Runtime overrides (loaded from Supabase / SharedPreferences).
  Map<String, List<String>> _overrides = {};

  /// Baseline aliases that have been explicitly removed by admins.
  Map<String, List<String>> _removedBaseline = {};

  bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Load overrides. Tries Supabase first, falls back to SharedPreferences.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;

    bool loadedFromSupabase = false;

    try {
      final rows = await _client
          .from(_kTable)
          .select('canonical_name, alias, is_removal')
          .order('created_at');

      final newOverrides = <String, List<String>>{};
      final newRemoved = <String, List<String>>{};

      for (final row in (rows as List)) {
        final canonical = row['canonical_name'] as String;
        final alias = row['alias'] as String;
        final isRemoval = (row['is_removal'] as bool?) ?? false;

        if (isRemoval) {
          newRemoved.putIfAbsent(canonical, () => []);
          if (!newRemoved[canonical]!.contains(alias)) {
            newRemoved[canonical]!.add(alias);
          }
        } else {
          newOverrides.putIfAbsent(canonical, () => []);
          if (!newOverrides[canonical]!.contains(alias)) {
            newOverrides[canonical]!.add(alias);
          }
        }
      }

      _overrides = newOverrides;
      _removedBaseline = newRemoved;
      loadedFromSupabase = true;

      // Update the local cache so the next offline session is warm.
      await _saveToPrefs();
    } catch (_) {
      // Supabase unreachable — fall through to SharedPreferences cache.
    }

    if (!loadedFromSupabase) {
      await _loadFromPrefs();
    }

    _loaded = true;
  }

  // ---------------------------------------------------------------------------
  // SharedPreferences helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadFromPrefs() async {
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
  }

  /// Persist current in-memory state to SharedPreferences.
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRuntimeAliasesKey, jsonEncode(_overrides));
    await prefs.setString(_kRemovedBaselineKey, jsonEncode(_removedBaseline));
  }

  // ---------------------------------------------------------------------------
  // Supabase write helpers
  // ---------------------------------------------------------------------------

  /// Write a single alias/removal row to Supabase. Non-fatal on failure.
  Future<void> _supabaseUpsert(
    String canonicalName,
    String alias, {
    required bool isRemoval,
  }) async {
    try {
      await _client.rpc(
        'admin_upsert_country_alias',
        params: {
          'p_canonical_name': canonicalName,
          'p_alias': alias,
          'p_is_removal': isRemoval,
        },
      );
    } catch (_) {
      // Offline or not admin — local cache already updated; sync on next load.
    }
  }

  /// Delete a single alias/removal row from Supabase. Non-fatal on failure.
  Future<void> _supabaseDelete(
    String canonicalName,
    String alias, {
    required bool isRemoval,
  }) async {
    try {
      await _client.rpc(
        'admin_delete_country_alias',
        params: {
          'p_canonical_name': canonicalName,
          'p_alias': alias,
          'p_is_removal': isRemoval,
        },
      );
    } catch (_) {
      // Offline or not admin — local cache already updated; sync on next load.
    }
  }

  // ---------------------------------------------------------------------------
  // Read API (unchanged)
  // ---------------------------------------------------------------------------

  /// The effective baseline aliases for a name, with removals applied.
  ///
  /// Always returns a mutable copy — the source [countryAliases] map is
  /// `const`, so returning its lists directly would crash on mutation
  /// (e.g. on iOS Safari / Dart2JS where const lists are strictly immutable).
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

  // ---------------------------------------------------------------------------
  // Write API (Supabase + SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Add a runtime alias for [canonicalName].
  ///
  /// Writes to Supabase (source of truth) and updates the local cache.
  Future<void> addAlias(String canonicalName, String alias) async {
    final normalized = alias.toLowerCase().trim();
    if (normalized.isEmpty) return;

    // If this alias was previously a removed baseline, un-remove it instead.
    final removedList = _removedBaseline[canonicalName];
    if (removedList != null && removedList.contains(normalized)) {
      removedList.remove(normalized);
      if (removedList.isEmpty) _removedBaseline.remove(canonicalName);
      await _saveToPrefs();
      // Remove the removal row from Supabase.
      await _supabaseDelete(canonicalName, normalized, isRemoval: true);
      return;
    }

    _overrides.putIfAbsent(canonicalName, () => []);
    if (!_overrides[canonicalName]!.contains(normalized)) {
      _overrides[canonicalName]!.add(normalized);
      await _saveToPrefs();
      await _supabaseUpsert(canonicalName, normalized, isRemoval: false);
    }
  }

  /// Remove an alias. Works for both runtime overrides and baseline aliases.
  ///
  /// For baseline aliases, the removal is stored so it persists across
  /// sessions. For runtime overrides, the override is simply deleted.
  /// Changes are written to Supabase and the local cache.
  Future<void> removeAlias(String canonicalName, String alias) async {
    // Check if it's a baseline alias.
    final baseline = countryAliases[canonicalName] ?? <String>[];
    if (baseline.contains(alias)) {
      _removedBaseline.putIfAbsent(canonicalName, () => []);
      if (!_removedBaseline[canonicalName]!.contains(alias)) {
        _removedBaseline[canonicalName]!.add(alias);
      }
      await _saveToPrefs();
      await _supabaseUpsert(canonicalName, alias, isRemoval: true);
      return;
    }

    // Otherwise it's a runtime override.
    final list = _overrides[canonicalName];
    if (list == null) return;
    list.remove(alias);
    if (list.isEmpty) _overrides.remove(canonicalName);
    await _saveToPrefs();
    await _supabaseDelete(canonicalName, alias, isRemoval: false);
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
    await _saveToPrefs();
    await _supabaseDelete(canonicalName, alias, isRemoval: true);
  }

  /// Force a reload from Supabase on the next [load] call.
  ///
  /// Call this after any external change (e.g. another admin device writes
  /// to Supabase) to ensure the local state is refreshed.
  void invalidateCache() {
    _loaded = false;
  }
}
