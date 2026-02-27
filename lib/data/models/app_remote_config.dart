/// Remote app configuration from the `app_config` table.
///
/// Controls force-update gates and maintenance mode.
class AppRemoteConfig {
  const AppRemoteConfig({
    this.minAppVersion = 'v1.0',
    this.recommendedVersion = 'v1.0',
    this.maintenanceMode = false,
    this.maintenanceMessage,
  });

  /// App versions below this must update before continuing.
  final String minAppVersion;

  /// App versions below this see a soft-nag banner.
  final String recommendedVersion;

  /// When true, all users see a maintenance screen.
  final bool maintenanceMode;

  /// Optional message displayed during maintenance.
  final String? maintenanceMessage;

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) =>
      AppRemoteConfig(
        minAppVersion: json['min_app_version'] as String? ?? 'v1.0',
        recommendedVersion: json['recommended_version'] as String? ?? 'v1.0',
        maintenanceMode: json['maintenance_mode'] as bool? ?? false,
        maintenanceMessage: json['maintenance_message'] as String?,
      );
}

/// Result of comparing the current app version against the remote config.
enum AppCompatibility {
  /// App is up-to-date or above min version.
  ok,

  /// App is below recommended but above min — show a soft nag.
  updateRecommended,

  /// App is below min version — must update.
  updateRequired,

  /// Server is in maintenance mode.
  maintenance,
}
