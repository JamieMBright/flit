import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_version.dart';
import '../models/app_remote_config.dart';

/// Fetches and caches the remote app configuration.
class AppConfigService {
  AppConfigService._();
  static final instance = AppConfigService._();

  SupabaseClient get _client => Supabase.instance.client;

  // 5-minute TTL cache.
  static const _ttl = Duration(minutes: 5);
  AppRemoteConfig? _cache;
  DateTime? _cacheTime;

  /// Fetch the remote config (cached).
  Future<AppRemoteConfig> fetchConfig() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      return _cache!;
    }

    try {
      final data = await _client
          .from('app_config')
          .select('*')
          .eq('id', 1)
          .maybeSingle();
      if (data != null) {
        _cache = AppRemoteConfig.fromJson(data);
      } else {
        _cache = const AppRemoteConfig();
      }
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (_) {
      return _cache ?? const AppRemoteConfig();
    }
  }

  /// Check if the current app version is compatible.
  Future<AppCompatibility> checkCompatibility() async {
    final config = await fetchConfig();

    if (config.maintenanceMode) {
      return AppCompatibility.maintenance;
    }

    final currentNum = _versionToNumber(appVersion);
    final minNum = _versionToNumber(config.minAppVersion);
    final recommendedNum = _versionToNumber(config.recommendedVersion);

    if (currentNum < minNum) {
      return AppCompatibility.updateRequired;
    }
    if (currentNum < recommendedNum) {
      return AppCompatibility.updateRecommended;
    }
    return AppCompatibility.ok;
  }

  /// Update app config (admin, owner-only).
  Future<void> updateConfig({
    String? minVersion,
    String? recommendedVersion,
    bool? maintenanceMode,
    String? maintenanceMessage,
  }) async {
    await _client.rpc(
      'admin_update_app_config',
      params: {
        'p_min_version': minVersion,
        'p_recommended_version': recommendedVersion,
        'p_maintenance_mode': maintenanceMode,
        'p_maintenance_message': maintenanceMessage,
      },
    );
    _cache = null;
    _cacheTime = null;
  }

  /// Parse a version string like 'v1.228' into a comparable number.
  /// Returns 1228 for 'v1.228', 0 for unparseable.
  static int _versionToNumber(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    if (parts.isEmpty) return 0;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return major * 10000 + minor;
  }
}
