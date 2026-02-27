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

  /// Whether a flag is enabled. Defaults to `true` if unknown.
  Future<bool> isEnabled(String flagKey) async {
    final flags = await fetchAll();
    return flags[flagKey] ?? true;
  }

  /// Fetch all flags as a key→bool map.
  Future<Map<String, bool>> fetchAll() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      return _cache!;
    }

    try {
      final data = await _client
          .from('feature_flags')
          .select('flag_key, enabled');
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
