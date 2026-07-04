import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote feature flag service backed by the `feature_flags` table.
///
/// Flags are cached for 2 minutes. When offline, falls back to
/// the last-known values stored in SharedPreferences.
class FeatureFlagService {
  FeatureFlagService._();
  static final instance = FeatureFlagService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const _ttl = Duration(minutes: 2);
  Map<String, bool>? _cache;
  DateTime? _cacheTime;

  /// Server-side defaults (mirrors the seeded `feature_flags` rows). Used
  /// when a flag can't be fetched AND has no local cache — e.g. the very
  /// first launch offline. Failing closed there would silently hide Shop,
  /// Leaderboard, Matchmaking, and Daily Scramble on a fresh install.
  static const Map<String, bool> _defaults = {
    'shop_enabled': true,
    'leaderboard_enabled': true,
    'matchmaking_enabled': true,
    'daily_scramble_enabled': true,
    'gifting_enabled': true,
  };

  /// Whether a flag is enabled. Falls back to the known server default
  /// (or `false` for unknown flags) when neither the server nor a local
  /// cache has an answer.
  Future<bool> isEnabled(String flagKey) async {
    final flags = await fetchAll();
    return flags[flagKey] ?? _defaults[flagKey] ?? false;
  }

  /// Fetch all flags as a key→bool map.
  Future<Map<String, bool>> fetchAll() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      return _cache!;
    }

    try {
      final data =
          await _client.from('feature_flags').select('flag_key, enabled');
      final map = <String, bool>{};
      for (final row in data as List) {
        map[row['flag_key'] as String] = row['enabled'] as bool? ?? true;
      }
      _cache = map;
      _cacheTime = DateTime.now();
      await _persistLocal(map);
      return map;
    } catch (_) {
      return _cache ?? await _loadLocal();
    }
  }

  /// Admin: set a flag (owner-only).
  Future<void> setFlag({
    required String flagKey,
    required bool enabled,
    String? description,
  }) async {
    await _client.rpc(
      'admin_set_feature_flag',
      params: {
        'p_flag_key': flagKey,
        'p_enabled': enabled,
        'p_description': description,
      },
    );
    _cache = null;
    _cacheTime = null;
  }

  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }

  // ── Offline persistence ──

  static const _prefsKey = 'feature_flags_cache';

  Future<void> _persistLocal(Map<String, bool> flags) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = flags.entries.map((e) => '${e.key}=${e.value}').toList();
    await prefs.setStringList(_prefsKey, entries);
  }

  Future<Map<String, bool>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_prefsKey);
    if (entries == null) return {};
    final map = <String, bool>{};
    for (final entry in entries) {
      final parts = entry.split('=');
      if (parts.length == 2) {
        map[parts[0]] = parts[1] == 'true';
      }
    }
    return map;
  }
}
