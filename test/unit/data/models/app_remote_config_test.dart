import 'package:flit/data/models/app_remote_config.dart';
import 'package:flit/data/services/app_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _defaultConfigJson() => {
  'min_app_version': 'v1.0',
  'recommended_version': 'v1.0',
  'maintenance_mode': false,
  'maintenance_message': null,
};

Map<String, dynamic> _maintenanceConfigJson() => {
  'min_app_version': 'v1.100',
  'recommended_version': 'v1.200',
  'maintenance_mode': true,
  'maintenance_message': 'Back soon — deploying hotfix.',
};

Map<String, dynamic> _gatedConfigJson() => {
  'min_app_version': 'v1.50',
  'recommended_version': 'v1.200',
  'maintenance_mode': false,
  'maintenance_message': null,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // AppRemoteConfig.fromJson — field mapping
  // -------------------------------------------------------------------------

  group('AppRemoteConfig.fromJson - default config', () {
    late AppRemoteConfig config;

    setUp(() {
      config = AppRemoteConfig.fromJson(_defaultConfigJson());
    });

    test('minAppVersion is parsed correctly', () {
      expect(config.minAppVersion, equals('v1.0'));
    });

    test('recommendedVersion is parsed correctly', () {
      expect(config.recommendedVersion, equals('v1.0'));
    });

    test('maintenanceMode is false', () {
      expect(config.maintenanceMode, isFalse);
    });

    test('maintenanceMessage is null', () {
      expect(config.maintenanceMessage, isNull);
    });
  });

  group('AppRemoteConfig.fromJson - maintenance config', () {
    late AppRemoteConfig config;

    setUp(() {
      config = AppRemoteConfig.fromJson(_maintenanceConfigJson());
    });

    test('maintenanceMode is true', () {
      expect(config.maintenanceMode, isTrue);
    });

    test('maintenanceMessage is parsed correctly', () {
      expect(
        config.maintenanceMessage,
        equals('Back soon — deploying hotfix.'),
      );
    });

    test('minAppVersion is parsed correctly', () {
      expect(config.minAppVersion, equals('v1.100'));
    });

    test('recommendedVersion is parsed correctly', () {
      expect(config.recommendedVersion, equals('v1.200'));
    });
  });

  // -------------------------------------------------------------------------
  // AppRemoteConfig.fromJson — default values when keys are missing
  // -------------------------------------------------------------------------

  group('AppRemoteConfig.fromJson - missing keys fall back to defaults', () {
    test('minAppVersion defaults to v1.0 when absent', () {
      final config = AppRemoteConfig.fromJson({});
      expect(config.minAppVersion, equals('v1.0'));
    });

    test('recommendedVersion defaults to v1.0 when absent', () {
      final config = AppRemoteConfig.fromJson({});
      expect(config.recommendedVersion, equals('v1.0'));
    });

    test('maintenanceMode defaults to false when absent', () {
      final config = AppRemoteConfig.fromJson({});
      expect(config.maintenanceMode, isFalse);
    });

    test('maintenanceMessage is null when absent', () {
      final config = AppRemoteConfig.fromJson({});
      expect(config.maintenanceMessage, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // AppRemoteConfig const constructor defaults
  // -------------------------------------------------------------------------

  group('AppRemoteConfig const constructor defaults', () {
    test('minAppVersion defaults to v1.0', () {
      const config = AppRemoteConfig();
      expect(config.minAppVersion, equals('v1.0'));
    });

    test('recommendedVersion defaults to v1.0', () {
      const config = AppRemoteConfig();
      expect(config.recommendedVersion, equals('v1.0'));
    });

    test('maintenanceMode defaults to false', () {
      const config = AppRemoteConfig();
      expect(config.maintenanceMode, isFalse);
    });

    test('maintenanceMessage defaults to null', () {
      const config = AppRemoteConfig();
      expect(config.maintenanceMessage, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // AppCompatibility enum values
  // -------------------------------------------------------------------------

  group('AppCompatibility enum', () {
    test('ok is a valid enum value', () {
      expect(AppCompatibility.values, contains(AppCompatibility.ok));
    });

    test('updateRecommended is a valid enum value', () {
      expect(
        AppCompatibility.values,
        contains(AppCompatibility.updateRecommended),
      );
    });

    test('updateRequired is a valid enum value', () {
      expect(
        AppCompatibility.values,
        contains(AppCompatibility.updateRequired),
      );
    });

    test('maintenance is a valid enum value', () {
      expect(AppCompatibility.values, contains(AppCompatibility.maintenance));
    });

    test('enum has exactly four values', () {
      expect(AppCompatibility.values, hasLength(4));
    });

    test('enum values are distinct', () {
      final values = AppCompatibility.values.toSet();
      expect(values, hasLength(AppCompatibility.values.length));
    });
  });

  // -------------------------------------------------------------------------
  // AppConfigService._versionToNumber (via exposed test helper)
  //
  // The private helper is exercised indirectly through the public
  // checkCompatibility logic which uses it for all comparisons. However,
  // since we cannot call Supabase in tests, we verify the parsing contract
  // through the service's public static-equivalent via direct integer
  // arithmetic matching the documented formula: major * 10000 + minor.
  // -------------------------------------------------------------------------

  group('AppConfigService version string parsing logic', () {
    // We use AppConfigService.versionToNumberForTest if exposed, or verify
    // the documented formula via expected compatibility outcomes.
    //
    // The formula: 'v1.228' → major=1, minor=228 → 1*10000+228 = 10228
    // We verify the formula holds by checking known version orderings.

    test('v1.0 parses to a smaller number than v1.1', () {
      // 1*10000+0=10000 < 1*10000+1=10001
      expect(
        AppConfigService.versionToNumberForTest('v1.0'),
        lessThan(AppConfigService.versionToNumberForTest('v1.1')),
      );
    });

    test('v1.100 parses to a smaller number than v1.200', () {
      expect(
        AppConfigService.versionToNumberForTest('v1.100'),
        lessThan(AppConfigService.versionToNumberForTest('v1.200')),
      );
    });

    test('v1.228 produces the expected numeric value', () {
      // Documented formula: 1*10000 + 228 = 10228
      expect(AppConfigService.versionToNumberForTest('v1.228'), equals(10228));
    });

    test('v2.0 is greater than v1.999', () {
      expect(
        AppConfigService.versionToNumberForTest('v2.0'),
        greaterThan(AppConfigService.versionToNumberForTest('v1.999')),
      );
    });

    test('identical versions produce identical numbers', () {
      expect(
        AppConfigService.versionToNumberForTest('v1.50'),
        equals(AppConfigService.versionToNumberForTest('v1.50')),
      );
    });

    test('unparseable string returns 0', () {
      expect(AppConfigService.versionToNumberForTest('garbage'), equals(0));
    });

    test('empty string returns 0', () {
      expect(AppConfigService.versionToNumberForTest(''), equals(0));
    });

    test('version with no minor part returns major * 10000', () {
      // 'v1' → major=1, minor=0 → 10000
      expect(AppConfigService.versionToNumberForTest('v1'), equals(10000));
    });
  });

  // -------------------------------------------------------------------------
  // maintenanceMode flag
  // -------------------------------------------------------------------------

  group('AppRemoteConfig maintenanceMode flag', () {
    test('maintenanceMode true is preserved through fromJson', () {
      final config = AppRemoteConfig.fromJson({
        'maintenance_mode': true,
        'maintenance_message': 'Under construction',
      });
      expect(config.maintenanceMode, isTrue);
      expect(config.maintenanceMessage, equals('Under construction'));
    });

    test('maintenanceMode false is preserved through fromJson', () {
      final config = AppRemoteConfig.fromJson({'maintenance_mode': false});
      expect(config.maintenanceMode, isFalse);
    });

    test('maintenanceMessage can be null even when mode is true', () {
      final config = AppRemoteConfig.fromJson({
        'maintenance_mode': true,
        'maintenance_message': null,
      });
      expect(config.maintenanceMode, isTrue);
      expect(config.maintenanceMessage, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Version string examples round-trip through fromJson
  // -------------------------------------------------------------------------

  group('AppRemoteConfig version strings round-trip through fromJson', () {
    test('non-standard patch version string is stored verbatim', () {
      final config = AppRemoteConfig.fromJson({
        'min_app_version': 'v1.42',
        'recommended_version': 'v1.99',
      });
      expect(config.minAppVersion, equals('v1.42'));
      expect(config.recommendedVersion, equals('v1.99'));
    });

    test('version without v prefix is stored verbatim', () {
      final config = AppRemoteConfig.fromJson({
        'min_app_version': '2.0',
        'recommended_version': '2.5',
      });
      expect(config.minAppVersion, equals('2.0'));
      expect(config.recommendedVersion, equals('2.5'));
    });
  });
}
