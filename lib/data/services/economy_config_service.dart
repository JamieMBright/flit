import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/economy_config.dart';

/// Singleton service that fetches and caches economy configuration from
/// Supabase.
///
/// The config is stored in the `economy_config` table as a single JSONB row
/// with `id = 1`. Reads are backed by a 30-second in-memory TTL cache to
/// avoid redundant round-trips on rapid widget rebuilds.
///
/// Call [invalidateCache] after writing new config to force the next [getConfig]
/// call to fetch fresh data from the database.
class EconomyConfigService {
  EconomyConfigService._();

  static final EconomyConfigService instance = EconomyConfigService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const Duration _ttl = Duration(seconds: 30);

  EconomyConfig? _cachedConfig;
  DateTime? _cacheTime;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the current [EconomyConfig].
  ///
  /// Serves from the in-memory cache if the cached value is less than 30
  /// seconds old. Otherwise fetches from the `economy_config` Supabase table.
  /// Falls back to [EconomyConfig.defaults] on any error or missing row.
  Future<EconomyConfig> getConfig() async {
    if (_isCacheFresh()) {
      return _cachedConfig!;
    }

    try {
      final row = await _client
          .from('economy_config')
          .select('config')
          .eq('id', 1)
          .maybeSingle();

      EconomyConfig config;
      if (row != null) {
        config = EconomyConfig.fromJson(row['config'] as Map<String, dynamic>);
      } else {
        config = EconomyConfig.defaults();
      }

      _cachedConfig = config;
      _cacheTime = DateTime.now();
      return config;
    } catch (e) {
      debugPrint('[EconomyConfigService] getConfig failed: $e');
      final config = EconomyConfig.defaults();
      _cachedConfig = config;
      _cacheTime = DateTime.now();
      return config;
    }
  }

  /// Persists [config] to Supabase via the `upsert_economy_config` RPC and
  /// invalidates the local cache so the next [getConfig] call reflects the
  /// saved values.
  Future<void> saveConfig(EconomyConfig config) async {
    try {
      await _client.rpc(
        'upsert_economy_config',
        params: {'new_config': config.toJson()},
      );
      invalidateCache();
    } catch (e) {
      debugPrint('[EconomyConfigService] saveConfig failed: $e');
      rethrow;
    }
  }

  /// Clears the cached config so the next [getConfig] call fetches from the
  /// database.
  void invalidateCache() {
    _cachedConfig = null;
    _cacheTime = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Returns `true` when a cached value exists and is younger than [_ttl].
  bool _isCacheFresh() {
    if (_cachedConfig == null || _cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _ttl;
  }
}
