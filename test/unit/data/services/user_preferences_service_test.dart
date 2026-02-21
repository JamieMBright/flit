import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/avatar_config.dart';
import 'package:flit/data/models/pilot_license.dart';
import 'package:flit/data/models/player.dart';
import 'package:flit/data/services/user_preferences_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal profile map that satisfies all required fields.
Map<String, dynamic> _baseProfile({
  String id = 'user-123',
  String? username,
  String? displayName,
}) => {
  'id': id,
  'username': username,
  'display_name': displayName,
  'avatar_url': null,
  'level': null,
  'xp': null,
  'coins': null,
  'games_played': null,
  'best_score': null,
  'best_time_ms': null,
  'total_flight_time_ms': null,
  'countries_found': null,
  'flags_correct': null,
  'capitals_correct': null,
  'outlines_correct': null,
  'borders_correct': null,
  'stats_correct': null,
  'best_streak': null,
  'created_at': null,
};

/// Full profile map with every field populated.
Map<String, dynamic> _fullProfile() => {
  'id': 'user-abc',
  'username': 'ace_pilot',
  'display_name': 'Ace Pilot',
  'avatar_url': 'https://example.com/avatar.png',
  'level': 7,
  'xp': 650,
  'coins': 1200,
  'games_played': 42,
  'best_score': 9500,
  'best_time_ms': 75000,
  'total_flight_time_ms': 3600000,
  'countries_found': 88,
  'flags_correct': 120,
  'capitals_correct': 95,
  'outlines_correct': 60,
  'borders_correct': 45,
  'stats_correct': 30,
  'best_streak': 14,
  'created_at': '2025-01-15T12:00:00.000Z',
};

/// Account state map containing a serialised PilotLicense.
Map<String, dynamic> _accountStateWithLicense() {
  const license = PilotLicense(
    coinBoost: 10,
    clueBoost: 15,
    clueChance: 5,
    fuelBoost: 20,
    preferredClueType: 'flag',
    nationality: 'GB',
  );
  return {
    'user_id': 'user-abc',
    'license_data': license.toJson(),
    'avatar_config': null,
    'unlocked_regions': ['europe', 'north_america'],
    'owned_avatar_parts': ['eyes_variant02'],
    'equipped_plane_id': 'plane_jet',
    'equipped_contrail_id': 'contrail_rainbow',
    'equipped_title_id': 'title_ace',
    'last_free_reroll_date': '2025-06-01',
    'last_daily_challenge_date': '2025-06-02',
  };
}

/// Account state map containing a serialised AvatarConfig.
Map<String, dynamic> _accountStateWithAvatar() {
  const avatar = AvatarConfig(
    style: AvatarStyle.avataaars,
    eyes: AvatarEyes.variant05,
    glasses: AvatarGlasses.variant01,
  );
  return {
    'user_id': 'user-abc',
    'license_data': null,
    'avatar_config': avatar.toJson(),
    'unlocked_regions': <String>[],
    'owned_avatar_parts': <String>[],
    'equipped_plane_id': 'plane_default',
    'equipped_contrail_id': 'contrail_default',
    'equipped_title_id': null,
    'last_free_reroll_date': null,
    'last_daily_challenge_date': null,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // UserPreferencesService – hasPendingWrites
  // -------------------------------------------------------------------------

  group('UserPreferencesService - hasPendingWrites', () {
    test('starts with no pending writes', () {
      final service = UserPreferencesService.instance;
      service.clear();

      expect(service.hasPendingWrites, isFalse);
    });

    test('hasPendingWrites becomes true after saveProfile is called', () {
      final service = UserPreferencesService.instance;
      service.clear();

      const player = Player(id: 'u1', username: 'pilot');
      service.saveProfile(player);

      expect(service.hasPendingWrites, isTrue);

      service.clear();
    });

    test('hasPendingWrites returns false after clear()', () {
      final service = UserPreferencesService.instance;
      service.clear();

      const player = Player(id: 'u1', username: 'pilot');
      service.saveProfile(player);
      expect(service.hasPendingWrites, isTrue);

      service.clear();
      expect(service.hasPendingWrites, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot.toPlayer() – field mapping
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot.toPlayer() - full data', () {
    late UserPreferencesSnapshot snapshot;
    late Player player;

    setUp(() {
      snapshot = UserPreferencesSnapshot(profile: _fullProfile());
      player = snapshot.toPlayer();
    });

    test('maps id correctly', () {
      expect(player.id, equals('user-abc'));
    });

    test('maps username correctly', () {
      expect(player.username, equals('ace_pilot'));
    });

    test('maps displayName correctly', () {
      expect(player.displayName, equals('Ace Pilot'));
    });

    test('maps level correctly', () {
      expect(player.level, equals(7));
    });

    test('maps xp correctly', () {
      expect(player.xp, equals(650));
    });

    test('maps coins correctly', () {
      expect(player.coins, equals(1200));
    });

    test('maps gamesPlayed correctly', () {
      expect(player.gamesPlayed, equals(42));
    });

    test('maps bestScore correctly', () {
      expect(player.bestScore, equals(9500));
    });

    test('maps bestTime from milliseconds', () {
      expect(player.bestTime, equals(const Duration(milliseconds: 75000)));
    });

    test('maps totalFlightTime from milliseconds', () {
      expect(
        player.totalFlightTime,
        equals(const Duration(milliseconds: 3600000)),
      );
    });

    test('maps countriesFound correctly', () {
      expect(player.countriesFound, equals(88));
    });

    test('maps flagsCorrect correctly', () {
      expect(player.flagsCorrect, equals(120));
    });

    test('maps capitalsCorrect correctly', () {
      expect(player.capitalsCorrect, equals(95));
    });

    test('maps outlinesCorrect correctly', () {
      expect(player.outlinesCorrect, equals(60));
    });

    test('maps bordersCorrect correctly', () {
      expect(player.bordersCorrect, equals(45));
    });

    test('maps statsCorrect correctly', () {
      expect(player.statsCorrect, equals(30));
    });

    test('maps bestStreak correctly', () {
      expect(player.bestStreak, equals(14));
    });

    test('parses createdAt from ISO 8601 string', () {
      expect(player.createdAt, isNotNull);
      expect(player.createdAt!.year, equals(2025));
      expect(player.createdAt!.month, equals(1));
      expect(player.createdAt!.day, equals(15));
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot.toPlayer() – null / missing field defaults
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot.toPlayer() - null fields use defaults', () {
    late Player player;

    setUp(() {
      final snapshot = UserPreferencesSnapshot(profile: _baseProfile());
      player = snapshot.toPlayer();
    });

    test('level defaults to 1 when null', () {
      expect(player.level, equals(1));
    });

    test('xp defaults to 0 when null', () {
      expect(player.xp, equals(0));
    });

    test('coins defaults to 100 when null', () {
      expect(player.coins, equals(100));
    });

    test('gamesPlayed defaults to 0 when null', () {
      expect(player.gamesPlayed, equals(0));
    });

    test('bestScore is null when not present', () {
      expect(player.bestScore, isNull);
    });

    test('bestTime is null when best_time_ms is null', () {
      expect(player.bestTime, isNull);
    });

    test('totalFlightTime defaults to Duration.zero when null', () {
      expect(player.totalFlightTime, equals(Duration.zero));
    });

    test('countriesFound defaults to 0 when null', () {
      expect(player.countriesFound, equals(0));
    });

    test('flagsCorrect defaults to 0 when null', () {
      expect(player.flagsCorrect, equals(0));
    });

    test('capitalsCorrect defaults to 0 when null', () {
      expect(player.capitalsCorrect, equals(0));
    });

    test('outlinesCorrect defaults to 0 when null', () {
      expect(player.outlinesCorrect, equals(0));
    });

    test('bordersCorrect defaults to 0 when null', () {
      expect(player.bordersCorrect, equals(0));
    });

    test('statsCorrect defaults to 0 when null', () {
      expect(player.statsCorrect, equals(0));
    });

    test('bestStreak defaults to 0 when null', () {
      expect(player.bestStreak, equals(0));
    });

    test('createdAt is null when created_at is absent', () {
      expect(player.createdAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot.toPlayer() – username fallback chain
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot.toPlayer() - username fallbacks', () {
    test('uses username when provided', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(username: 'sky_racer'),
      );
      expect(snapshot.toPlayer().username, equals('sky_racer'));
    });

    test('falls back to id when username is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(id: 'fallback-id-42'),
      );
      expect(snapshot.toPlayer().username, equals('fallback-id-42'));
    });

    test('displayName matches username when display_name is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(username: 'navigator'),
      );
      final player = snapshot.toPlayer();
      expect(player.displayName, equals('navigator'));
    });

    test('displayName is used when both username and display_name are set', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(username: 'nav', displayName: 'The Navigator'),
      );
      final player = snapshot.toPlayer();
      expect(player.displayName, equals('The Navigator'));
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot.toPilotLicense()
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot.toPilotLicense() - valid data', () {
    test('deserialises all license fields from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      final license = snapshot.toPilotLicense();

      expect(license.coinBoost, equals(10));
      expect(license.clueBoost, equals(15));
      expect(license.clueChance, equals(5));
      expect(license.fuelBoost, equals(20));
      expect(license.preferredClueType, equals('flag'));
      expect(license.nationality, equals('GB'));
    });

    test('returns valid PilotLicense when account_state is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: null,
      );
      final license = snapshot.toPilotLicense();

      // Random license — just verify it is a valid PilotLicense instance
      // with stats in the allowed range [1, 25].
      expect(license.coinBoost, inInclusiveRange(1, 25));
      expect(license.clueBoost, inInclusiveRange(1, 25));
      expect(license.clueChance, inInclusiveRange(1, 25));
      expect(license.fuelBoost, inInclusiveRange(1, 25));
      expect(clueTypes, contains(license.preferredClueType));
    });

    test(
      'returns random license when license_data is null in account_state',
      () {
        final accountState = Map<String, dynamic>.from(
          _accountStateWithLicense(),
        )..['license_data'] = null;
        final snapshot = UserPreferencesSnapshot(
          profile: _baseProfile(),
          accountState: accountState,
        );
        final license = snapshot.toPilotLicense();

        expect(license.coinBoost, inInclusiveRange(1, 25));
        expect(clueTypes, contains(license.preferredClueType));
      },
    );

    test('returns random license when license_data is empty map', () {
      final accountState = Map<String, dynamic>.from(_accountStateWithLicense())
        ..['license_data'] = <String, dynamic>{};
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: accountState,
      );
      final license = snapshot.toPilotLicense();

      expect(license.coinBoost, inInclusiveRange(1, 25));
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot.toAvatarConfig()
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot.toAvatarConfig()', () {
    test('returns default AvatarConfig when account_state is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: null,
      );
      expect(snapshot.toAvatarConfig(), equals(const AvatarConfig()));
    });

    test('returns default AvatarConfig when avatar_config key is null', () {
      final accountState = Map<String, dynamic>.from(_accountStateWithAvatar())
        ..['avatar_config'] = null;
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: accountState,
      );
      expect(snapshot.toAvatarConfig(), equals(const AvatarConfig()));
    });

    test('deserialises AvatarConfig from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithAvatar(),
      );
      final avatar = snapshot.toAvatarConfig();

      expect(avatar.style, equals(AvatarStyle.avataaars));
      expect(avatar.eyes, equals(AvatarEyes.variant05));
      expect(avatar.glasses, equals(AvatarGlasses.variant01));
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot account state accessors
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot - account state accessors', () {
    test('equippedPlaneId defaults to plane_default when no account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: null,
      );
      expect(snapshot.equippedPlaneId, equals('plane_default'));
    });

    test(
      'equippedContrailId defaults to contrail_default when no account_state',
      () {
        final snapshot = UserPreferencesSnapshot(
          profile: _baseProfile(),
          accountState: null,
        );
        expect(snapshot.equippedContrailId, equals('contrail_default'));
      },
    );

    test('equippedPlaneId reads from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      expect(snapshot.equippedPlaneId, equals('plane_jet'));
    });

    test('equippedTitleId reads from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      expect(snapshot.equippedTitleId, equals('title_ace'));
    });

    test('equippedTitleId is null when not set in account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithAvatar(),
      );
      expect(snapshot.equippedTitleId, isNull);
    });

    test('unlockedRegions returns empty set when account_state is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: null,
      );
      expect(snapshot.unlockedRegions, isEmpty);
    });

    test('unlockedRegions reads from account_state correctly', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      expect(
        snapshot.unlockedRegions,
        containsAll(['europe', 'north_america']),
      );
    });

    test('ownedAvatarParts returns empty set when account_state is null', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: null,
      );
      expect(snapshot.ownedAvatarParts, isEmpty);
    });

    test('lastFreeRerollDate reads from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      expect(snapshot.lastFreeRerollDate, equals('2025-06-01'));
    });

    test('lastDailyChallengeDate reads from account_state', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: _accountStateWithLicense(),
      );
      expect(snapshot.lastDailyChallengeDate, equals('2025-06-02'));
    });
  });

  // -------------------------------------------------------------------------
  // License persistence — Supabase load guard
  // -------------------------------------------------------------------------

  group('License persistence guard', () {
    test('toPilotLicense preserves saved license from valid account_state', () {
      final license = const PilotLicense(
        coinBoost: 12,
        clueBoost: 18,
        clueChance: 7,
        fuelBoost: 22,
        preferredClueType: 'capital',
        nationality: 'US',
      );
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        accountState: {
          'user_id': 'user-123',
          'license_data': license.toJson(),
          'avatar_config': null,
          'unlocked_regions': <String>[],
          'owned_avatar_parts': <String>[],
          'equipped_plane_id': 'plane_default',
          'equipped_contrail_id': 'contrail_default',
          'equipped_title_id': null,
          'last_free_reroll_date': null,
          'last_daily_challenge_date': null,
        },
      );
      final restored = snapshot.toPilotLicense();

      expect(restored.coinBoost, equals(12));
      expect(restored.clueBoost, equals(18));
      expect(restored.clueChance, equals(7));
      expect(restored.fuelBoost, equals(22));
      expect(restored.preferredClueType, equals('capital'));
      expect(restored.nationality, equals('US'));
    });

    test(
      'toPilotLicense returns random when account_state has no license_data',
      () {
        final snapshot = UserPreferencesSnapshot(
          profile: _baseProfile(),
          accountState: {
            'user_id': 'user-123',
            'license_data': null,
            'avatar_config': null,
            'unlocked_regions': <String>[],
            'owned_avatar_parts': <String>[],
            'equipped_plane_id': 'plane_default',
            'equipped_contrail_id': 'contrail_default',
            'equipped_title_id': null,
            'last_free_reroll_date': null,
            'last_daily_challenge_date': null,
          },
        );
        final license = snapshot.toPilotLicense();

        // Should be a valid random license
        expect(license.coinBoost, inInclusiveRange(1, 25));
        expect(license.clueBoost, inInclusiveRange(1, 25));
        expect(license.fuelBoost, inInclusiveRange(1, 25));
      },
    );

    test('toPilotLicense nationality is preserved through serialization', () {
      const license = PilotLicense(
        coinBoost: 5,
        clueBoost: 5,
        clueChance: 5,
        fuelBoost: 5,
        preferredClueType: 'flag',
        nationality: 'JP',
      );
      final json = license.toJson();
      final restored = PilotLicense.fromJson(json);

      expect(restored.nationality, equals('JP'));
    });
  });

  // -------------------------------------------------------------------------
  // UserPreferencesSnapshot settings accessors
  // -------------------------------------------------------------------------

  group('UserPreferencesSnapshot - settings defaults', () {
    late UserPreferencesSnapshot snapshotNoSettings;

    setUp(() {
      snapshotNoSettings = UserPreferencesSnapshot(
        profile: _baseProfile(),
        settings: null,
      );
    });

    test('turnSensitivity defaults to 0.5 when no settings', () {
      expect(snapshotNoSettings.turnSensitivity, closeTo(0.5, 0.001));
    });

    test('invertControls defaults to false when no settings', () {
      expect(snapshotNoSettings.invertControls, isFalse);
    });

    test('enableNight defaults to true when no settings', () {
      expect(snapshotNoSettings.enableNight, isTrue);
    });

    test('mapStyle defaults to "topo" when no settings', () {
      expect(snapshotNoSettings.mapStyle, equals('topo'));
    });

    test('difficulty defaults to "normal" when no settings', () {
      expect(snapshotNoSettings.difficulty, equals('normal'));
    });

    test('soundEnabled defaults to true when no settings', () {
      expect(snapshotNoSettings.soundEnabled, isTrue);
    });

    test('notificationsEnabled defaults to true when no settings', () {
      expect(snapshotNoSettings.notificationsEnabled, isTrue);
    });

    test('hapticEnabled defaults to true when no settings', () {
      expect(snapshotNoSettings.hapticEnabled, isTrue);
    });

    test('settings values are read correctly when present', () {
      final snapshot = UserPreferencesSnapshot(
        profile: _baseProfile(),
        settings: {
          'turn_sensitivity': 0.8,
          'invert_controls': true,
          'enable_night': false,
          'map_style': 'satellite',
          'english_labels': false,
          'difficulty': 'hard',
          'sound_enabled': false,
          'notifications_enabled': false,
          'haptic_enabled': false,
        },
      );

      expect(snapshot.turnSensitivity, closeTo(0.8, 0.001));
      expect(snapshot.invertControls, isTrue);
      expect(snapshot.enableNight, isFalse);
      expect(snapshot.mapStyle, equals('satellite'));
      expect(snapshot.englishLabels, isFalse);
      expect(snapshot.difficulty, equals('hard'));
      expect(snapshot.soundEnabled, isFalse);
      expect(snapshot.notificationsEnabled, isFalse);
      expect(snapshot.hapticEnabled, isFalse);
    });
  });
}
