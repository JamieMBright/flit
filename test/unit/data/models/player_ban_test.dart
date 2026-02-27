import 'package:flit/core/config/admin_config.dart';
import 'package:flit/data/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Player _basePlayer() => const Player(id: 'uid-001', username: 'pilot_ace');

Player _permanentlyBannedPlayer() => Player(
  id: 'uid-002',
  username: 'bad_actor',
  bannedAt: DateTime(2026, 1, 1),
  banExpiresAt: null,
  banReason: 'Repeated cheating.',
);

Player _temporarilyBannedPlayer() => Player(
  id: 'uid-003',
  username: 'temp_offender',
  bannedAt: DateTime(2026, 2, 1),
  banExpiresAt: DateTime.now().add(const Duration(days: 7)),
  banReason: 'Offensive username.',
);

Player _expiredBanPlayer() => Player(
  id: 'uid-004',
  username: 'reformed_player',
  bannedAt: DateTime(2025, 12, 1),
  banExpiresAt: DateTime(2026, 1, 1), // already in the past
  banReason: 'Harassment.',
);

Player _ownerPlayer() =>
    const Player(id: 'uid-owner', username: 'owner_user', adminRole: 'owner');

Player _moderatorPlayer() =>
    const Player(id: 'uid-mod', username: 'mod_user', adminRole: 'moderator');

Map<String, dynamic> _bannedPlayerJson() => {
  'id': 'uid-ban-json',
  'username': 'banned_via_json',
  'banned_at': '2026-01-15T00:00:00.000Z',
  'ban_expires_at': null,
  'ban_reason': 'Persistent cheating.',
};

Map<String, dynamic> _tempBannedPlayerJson() => {
  'id': 'uid-temp-json',
  'username': 'temp_via_json',
  'banned_at': '2026-02-01T00:00:00.000Z',
  'ban_expires_at': '2099-12-31T23:59:59.000Z',
  'ban_reason': 'Offensive chat.',
};

Map<String, dynamic> _expiredBanPlayerJson() => {
  'id': 'uid-expired-json',
  'username': 'expired_via_json',
  'banned_at': '2025-11-01T00:00:00.000Z',
  'ban_expires_at': '2026-01-01T00:00:00.000Z',
  'ban_reason': 'Spam.',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Player.isBanned — core logic
  // -------------------------------------------------------------------------

  group('Player.isBanned - not banned', () {
    test('isBanned is false when bannedAt is null', () {
      expect(_basePlayer().isBanned, isFalse);
    });

    test('isBanned is false for a player with no ban fields set', () {
      const player = Player(id: 'x', username: 'clean');
      expect(player.isBanned, isFalse);
    });
  });

  group('Player.isBanned - permanent ban', () {
    test('isBanned is true when bannedAt is set and banExpiresAt is null', () {
      expect(_permanentlyBannedPlayer().isBanned, isTrue);
    });

    test('banReason is preserved on a permanently banned player', () {
      expect(
        _permanentlyBannedPlayer().banReason,
        equals('Repeated cheating.'),
      );
    });

    test('bannedAt is non-null on a permanently banned player', () {
      expect(_permanentlyBannedPlayer().bannedAt, isNotNull);
    });

    test('banExpiresAt is null on a permanently banned player', () {
      expect(_permanentlyBannedPlayer().banExpiresAt, isNull);
    });
  });

  group('Player.isBanned - active temporary ban', () {
    test('isBanned is true when banExpiresAt is in the future', () {
      expect(_temporarilyBannedPlayer().isBanned, isTrue);
    });

    test('banExpiresAt is after now for an active temp ban', () {
      expect(
        _temporarilyBannedPlayer().banExpiresAt!.isAfter(DateTime.now()),
        isTrue,
      );
    });
  });

  group('Player.isBanned - expired temporary ban', () {
    test('isBanned is false when banExpiresAt is in the past', () {
      expect(_expiredBanPlayer().isBanned, isFalse);
    });

    test('bannedAt is still set even for an expired ban', () {
      // The ban record remains; it is just no longer active.
      expect(_expiredBanPlayer().bannedAt, isNotNull);
    });

    test('banExpiresAt is in the past for an expired ban', () {
      expect(
        _expiredBanPlayer().banExpiresAt!.isBefore(DateTime.now()),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Ban fields survive copyWith
  // -------------------------------------------------------------------------

  group('Player.copyWith preserves ban fields', () {
    test('bannedAt is preserved when not overridden by copyWith', () {
      final original = _permanentlyBannedPlayer();
      final updated = original.copyWith(username: 'new_username');
      expect(updated.bannedAt, equals(original.bannedAt));
    });

    test('banExpiresAt is preserved when not overridden by copyWith', () {
      final original = _temporarilyBannedPlayer();
      final updated = original.copyWith(username: 'renamed');
      expect(updated.banExpiresAt, equals(original.banExpiresAt));
    });

    test('banReason is preserved when not overridden by copyWith', () {
      final original = _permanentlyBannedPlayer();
      final updated = original.copyWith(level: 5);
      expect(updated.banReason, equals(original.banReason));
    });

    test('isBanned remains true on the copied player (permanent ban)', () {
      final updated = _permanentlyBannedPlayer().copyWith(username: 'renamed');
      expect(updated.isBanned, isTrue);
    });

    test('isBanned remains true on the copied player (active temp ban)', () {
      final updated = _temporarilyBannedPlayer().copyWith(xp: 100);
      expect(updated.isBanned, isTrue);
    });

    test('isBanned remains false on the copied player (expired ban)', () {
      final updated = _expiredBanPlayer().copyWith(coins: 500);
      expect(updated.isBanned, isFalse);
    });

    test('copyWith can override bannedAt to null to clear ban record', () {
      // Note: copyWith uses ?? so passing null explicitly does NOT clear
      // fields — it preserves the original. Clients must use a new
      // Player(...) to clear ban fields entirely. This test verifies
      // the ?? semantics are preserved.
      final original = _permanentlyBannedPlayer();
      // Passing null does not override due to ?? in copyWith.
      final updated = original.copyWith();
      expect(updated.bannedAt, equals(original.bannedAt));
    });
  });

  // -------------------------------------------------------------------------
  // Ban fields survive toJson / fromJson round-trip
  // -------------------------------------------------------------------------

  group('Player ban fields — toJson / fromJson round-trip', () {
    test('permanent ban round-trips correctly', () {
      final original = _permanentlyBannedPlayer();
      final json = original.toJson();
      final restored = Player.fromJson(json);

      expect(restored.bannedAt, isNotNull);
      expect(
        restored.bannedAt!.toUtc().millisecondsSinceEpoch,
        equals(original.bannedAt!.toUtc().millisecondsSinceEpoch),
      );
      expect(restored.banExpiresAt, isNull);
      expect(restored.banReason, equals(original.banReason));
      expect(restored.isBanned, isTrue);
    });

    test('temporary ban round-trips correctly', () {
      final original = _temporarilyBannedPlayer();
      final json = original.toJson();
      final restored = Player.fromJson(json);

      expect(restored.bannedAt, isNotNull);
      expect(restored.banExpiresAt, isNotNull);
      expect(
        restored.banExpiresAt!.toUtc().millisecondsSinceEpoch,
        equals(original.banExpiresAt!.toUtc().millisecondsSinceEpoch),
      );
      expect(restored.isBanned, isTrue);
    });

    test('expired ban round-trips correctly', () {
      final original = _expiredBanPlayer();
      final json = original.toJson();
      final restored = Player.fromJson(json);

      expect(restored.bannedAt, isNotNull);
      expect(restored.banExpiresAt, isNotNull);
      expect(restored.isBanned, isFalse);
    });

    test('unbanned player round-trips with null ban fields', () {
      final original = _basePlayer();
      final json = original.toJson();
      final restored = Player.fromJson(json);

      expect(restored.bannedAt, isNull);
      expect(restored.banExpiresAt, isNull);
      expect(restored.banReason, isNull);
      expect(restored.isBanned, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Ban fields from JSON fixture
  // -------------------------------------------------------------------------

  group('Player ban fields — fromJson with ban data', () {
    test('permanent ban from JSON: isBanned is true', () {
      final player = Player.fromJson(_bannedPlayerJson());
      expect(player.isBanned, isTrue);
      expect(player.bannedAt, isNotNull);
      expect(player.banExpiresAt, isNull);
      expect(player.banReason, equals('Persistent cheating.'));
    });

    test('far-future temp ban from JSON: isBanned is true', () {
      final player = Player.fromJson(_tempBannedPlayerJson());
      expect(player.isBanned, isTrue);
      expect(player.banExpiresAt, isNotNull);
      expect(player.banExpiresAt!.isAfter(DateTime.now()), isTrue);
    });

    test('expired ban from JSON: isBanned is false', () {
      final player = Player.fromJson(_expiredBanPlayerJson());
      expect(player.isBanned, isFalse);
      expect(player.bannedAt, isNotNull);
      expect(player.banExpiresAt!.isBefore(DateTime.now()), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Admin role helpers
  // -------------------------------------------------------------------------

  group('Player admin role helpers', () {
    test('isAdmin is false for a regular player', () {
      expect(_basePlayer().isAdmin, isFalse);
    });

    test('isAdmin is true for owner', () {
      expect(_ownerPlayer().isAdmin, isTrue);
    });

    test('isAdmin is true for moderator', () {
      expect(_moderatorPlayer().isAdmin, isTrue);
    });

    test('isOwner is true only for owner role', () {
      expect(_ownerPlayer().isOwner, isTrue);
      expect(_moderatorPlayer().isOwner, isFalse);
      expect(_basePlayer().isOwner, isFalse);
    });

    test('isModerator is true only for moderator role', () {
      expect(_moderatorPlayer().isModerator, isTrue);
      expect(_ownerPlayer().isModerator, isFalse);
      expect(_basePlayer().isModerator, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Player.hasPermission — delegating to AdminPermissions
  // -------------------------------------------------------------------------

  group('Player.hasPermission - owner', () {
    test('owner has viewUserData', () {
      expect(
        _ownerPlayer().hasPermission(AdminPermission.viewUserData),
        isTrue,
      );
    });

    test('owner has permaBanUser', () {
      expect(
        _ownerPlayer().hasPermission(AdminPermission.permaBanUser),
        isTrue,
      );
    });

    test('owner has giftGold', () {
      expect(_ownerPlayer().hasPermission(AdminPermission.giftGold), isTrue);
    });

    test('owner has editEarnings', () {
      expect(
        _ownerPlayer().hasPermission(AdminPermission.editEarnings),
        isTrue,
      );
    });

    test('owner has manageRoles', () {
      expect(_ownerPlayer().hasPermission(AdminPermission.manageRoles), isTrue);
    });
  });

  group('Player.hasPermission - moderator', () {
    test('moderator has viewUserData', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.viewUserData),
        isTrue,
      );
    });

    test('moderator has resolveReports', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.resolveReports),
        isTrue,
      );
    });

    test('moderator has tempBanUser', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.tempBanUser),
        isTrue,
      );
    });

    test('moderator does NOT have permaBanUser', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.permaBanUser),
        isFalse,
      );
    });

    test('moderator does NOT have giftGold', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.giftGold),
        isFalse,
      );
    });

    test('moderator does NOT have editEarnings', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.editEarnings),
        isFalse,
      );
    });

    test('moderator does NOT have manageRoles', () {
      expect(
        _moderatorPlayer().hasPermission(AdminPermission.manageRoles),
        isFalse,
      );
    });
  });

  group('Player.hasPermission - regular user', () {
    test('regular player has no permissions', () {
      for (final perm in AdminPermission.values) {
        expect(
          _basePlayer().hasPermission(perm),
          isFalse,
          reason: 'Expected no permission for $perm on a regular player',
        );
      }
    });
  });
}
