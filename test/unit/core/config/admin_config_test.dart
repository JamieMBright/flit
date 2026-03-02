import 'package:flit/core/config/admin_config.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // AdminPermissions.forRole — owner
  // -------------------------------------------------------------------------

  group('AdminPermissions.forRole - owner', () {
    late Set<AdminPermission> ownerPerms;

    setUp(() {
      ownerPerms = AdminPermissions.forRole('owner');
    });

    test('owner gets a non-empty permission set', () {
      expect(ownerPerms, isNotEmpty);
    });

    test('owner gets ALL defined permissions', () {
      expect(ownerPerms, containsAll(AdminPermission.values));
    });

    test('owner permission count matches total enum count', () {
      expect(ownerPerms.length, equals(AdminPermission.values.length));
    });

    test(
      'forRole(owner) returns the same reference as AdminPermissions.owner',
      () {
        expect(ownerPerms, equals(AdminPermissions.owner));
      },
    );
  });

  // -------------------------------------------------------------------------
  // AdminPermissions.forRole — moderator
  // -------------------------------------------------------------------------

  group('AdminPermissions.forRole - moderator', () {
    late Set<AdminPermission> modPerms;

    setUp(() {
      modPerms = AdminPermissions.forRole('moderator');
    });

    test('moderator gets a non-empty permission set', () {
      expect(modPerms, isNotEmpty);
    });

    test('moderator gets fewer permissions than owner', () {
      expect(
        modPerms.length,
        lessThan(AdminPermissions.forRole('owner').length),
      );
    });

    test(
      'forRole(moderator) returns the same reference as AdminPermissions.moderator',
      () {
        expect(modPerms, equals(AdminPermissions.moderator));
      },
    );

    // View permissions that moderator SHOULD have
    test('moderator CAN viewAnalytics', () {
      expect(modPerms, contains(AdminPermission.viewAnalytics));
    });

    test('moderator CAN viewUserData', () {
      expect(modPerms, contains(AdminPermission.viewUserData));
    });

    test('moderator CAN viewGameHistory', () {
      expect(modPerms, contains(AdminPermission.viewGameHistory));
    });

    test('moderator CAN viewCoinLedger', () {
      expect(modPerms, contains(AdminPermission.viewCoinLedger));
    });

    test('moderator CAN viewGameLog', () {
      expect(modPerms, contains(AdminPermission.viewGameLog));
    });

    test('moderator CAN viewDesignPreviews', () {
      expect(modPerms, contains(AdminPermission.viewDesignPreviews));
    });

    test('moderator CAN viewDifficulty', () {
      expect(modPerms, contains(AdminPermission.viewDifficulty));
    });

    test('moderator CAN viewAdConfig', () {
      expect(modPerms, contains(AdminPermission.viewAdConfig));
    });

    test('moderator CAN viewErrors', () {
      expect(modPerms, contains(AdminPermission.viewErrors));
    });

    test('moderator CAN viewReports', () {
      expect(modPerms, contains(AdminPermission.viewReports));
    });

    test('moderator CAN viewAnnouncements', () {
      expect(modPerms, contains(AdminPermission.viewAnnouncements));
    });

    test('moderator CAN viewFeatureFlags', () {
      expect(modPerms, contains(AdminPermission.viewFeatureFlags));
    });

    test('moderator CAN viewEconomyHealth', () {
      expect(modPerms, contains(AdminPermission.viewEconomyHealth));
    });

    test('moderator CAN viewSuspiciousActivity', () {
      expect(modPerms, contains(AdminPermission.viewSuspiciousActivity));
    });

    test('moderator CAN viewOwnAuditLog', () {
      expect(modPerms, contains(AdminPermission.viewOwnAuditLog));
    });

    // Moderation actions that moderator SHOULD have
    test('moderator CAN changeUsername', () {
      expect(modPerms, contains(AdminPermission.changeUsername));
    });

    test('moderator CAN resolveReports', () {
      expect(modPerms, contains(AdminPermission.resolveReports));
    });

    test('moderator CAN tempBanUser', () {
      expect(modPerms, contains(AdminPermission.tempBanUser));
    });

    test('moderator CAN triggerPasswordReset', () {
      expect(modPerms, contains(AdminPermission.triggerPasswordReset));
    });

    test('moderator CAN createInfoAnnouncements', () {
      expect(modPerms, contains(AdminPermission.createInfoAnnouncements));
    });

    // Owner-only permissions that moderator MUST NOT have
    test('moderator CANNOT selfServiceActions', () {
      expect(modPerms, isNot(contains(AdminPermission.selfServiceActions)));
    });

    test('moderator CANNOT giftGold', () {
      expect(modPerms, isNot(contains(AdminPermission.giftGold)));
    });

    test('moderator CANNOT giftLevels', () {
      expect(modPerms, isNot(contains(AdminPermission.giftLevels)));
    });

    test('moderator CANNOT giftFlights', () {
      expect(modPerms, isNot(contains(AdminPermission.giftFlights)));
    });

    test('moderator CANNOT setCoins', () {
      expect(modPerms, isNot(contains(AdminPermission.setCoins)));
    });

    test('moderator CANNOT setLevel', () {
      expect(modPerms, isNot(contains(AdminPermission.setLevel)));
    });

    test('moderator CANNOT setFlights', () {
      expect(modPerms, isNot(contains(AdminPermission.setFlights)));
    });

    test('moderator CANNOT giftCosmetic', () {
      expect(modPerms, isNot(contains(AdminPermission.giftCosmetic)));
    });

    test('moderator CANNOT setLicense', () {
      expect(modPerms, isNot(contains(AdminPermission.setLicense)));
    });

    test('moderator CANNOT setAvatar', () {
      expect(modPerms, isNot(contains(AdminPermission.setAvatar)));
    });

    test('moderator CANNOT unlockAll', () {
      expect(modPerms, isNot(contains(AdminPermission.unlockAll)));
    });

    test('moderator CANNOT manageRoles', () {
      expect(modPerms, isNot(contains(AdminPermission.manageRoles)));
    });

    test('moderator CANNOT editEarnings', () {
      expect(modPerms, isNot(contains(AdminPermission.editEarnings)));
    });

    test('moderator CANNOT editPromotions', () {
      expect(modPerms, isNot(contains(AdminPermission.editPromotions)));
    });

    test('moderator CANNOT editGoldPackages', () {
      expect(modPerms, isNot(contains(AdminPermission.editGoldPackages)));
    });

    test('moderator CANNOT editShopPrices', () {
      expect(modPerms, isNot(contains(AdminPermission.editShopPrices)));
    });

    test('moderator CANNOT editDifficulty', () {
      expect(modPerms, isNot(contains(AdminPermission.editDifficulty)));
    });

    test('moderator CANNOT permaBanUser', () {
      expect(modPerms, isNot(contains(AdminPermission.permaBanUser)));
    });

    test('moderator CANNOT unbanUser', () {
      expect(modPerms, isNot(contains(AdminPermission.unbanUser)));
    });

    test('moderator CANNOT editAppConfig', () {
      expect(modPerms, isNot(contains(AdminPermission.editAppConfig)));
    });

    test('moderator CANNOT editAnnouncements', () {
      expect(modPerms, isNot(contains(AdminPermission.editAnnouncements)));
    });

    test('moderator CANNOT editFeatureFlags', () {
      expect(modPerms, isNot(contains(AdminPermission.editFeatureFlags)));
    });

    test('moderator CANNOT viewAuditLog (full audit log — owner only)', () {
      expect(modPerms, isNot(contains(AdminPermission.viewAuditLog)));
    });
  });

  // -------------------------------------------------------------------------
  // AdminPermissions.forRole — null / unknown roles
  // -------------------------------------------------------------------------

  group('AdminPermissions.forRole - null role', () {
    test('null role returns an empty set', () {
      expect(AdminPermissions.forRole(null), isEmpty);
    });

    test('unknown string role returns an empty set', () {
      expect(AdminPermissions.forRole('super_admin'), isEmpty);
    });

    test('empty string role returns an empty set', () {
      expect(AdminPermissions.forRole(''), isEmpty);
    });

    test('null role result is constant — does not allow mutation', () {
      // forRole(null) returns const {} which is unmodifiable.
      final perms = AdminPermissions.forRole(null);
      expect(
        () => perms.add(AdminPermission.viewUserData),
        throwsUnsupportedError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // AdminPermissions.hasPermission
  // -------------------------------------------------------------------------

  group('AdminPermissions.hasPermission - owner', () {
    test('owner hasPermission(viewUserData) is true', () {
      expect(
        AdminPermissions.hasPermission('owner', AdminPermission.viewUserData),
        isTrue,
      );
    });

    test('owner hasPermission(permaBanUser) is true', () {
      expect(
        AdminPermissions.hasPermission('owner', AdminPermission.permaBanUser),
        isTrue,
      );
    });

    test('owner hasPermission(manageRoles) is true', () {
      expect(
        AdminPermissions.hasPermission('owner', AdminPermission.manageRoles),
        isTrue,
      );
    });

    test('owner has every permission via hasPermission', () {
      for (final perm in AdminPermission.values) {
        expect(
          AdminPermissions.hasPermission('owner', perm),
          isTrue,
          reason: 'Owner should have $perm',
        );
      }
    });
  });

  group('AdminPermissions.hasPermission - moderator', () {
    test('moderator hasPermission(viewUserData) is true', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.viewUserData,
        ),
        isTrue,
      );
    });

    test('moderator hasPermission(tempBanUser) is true', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.tempBanUser,
        ),
        isTrue,
      );
    });

    test('moderator hasPermission(changeUsername) is true', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.changeUsername,
        ),
        isTrue,
      );
    });

    test('moderator hasPermission(viewReports) is true', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.viewReports,
        ),
        isTrue,
      );
    });

    test('moderator hasPermission(editEarnings) is false', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.editEarnings,
        ),
        isFalse,
      );
    });

    test('moderator hasPermission(giftGold) is false', () {
      expect(
        AdminPermissions.hasPermission('moderator', AdminPermission.giftGold),
        isFalse,
      );
    });

    test('moderator hasPermission(permaBanUser) is false', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.permaBanUser,
        ),
        isFalse,
      );
    });

    test('moderator hasPermission(manageRoles) is false', () {
      expect(
        AdminPermissions.hasPermission(
          'moderator',
          AdminPermission.manageRoles,
        ),
        isFalse,
      );
    });

    test('moderator hasPermission(unbanUser) is false', () {
      expect(
        AdminPermissions.hasPermission('moderator', AdminPermission.unbanUser),
        isFalse,
      );
    });
  });

  group('AdminPermissions.hasPermission - null role', () {
    test('null role hasPermission returns false for every permission', () {
      for (final perm in AdminPermission.values) {
        expect(
          AdminPermissions.hasPermission(null, perm),
          isFalse,
          reason: 'Null role should not have $perm',
        );
      }
    });

    test('unknown role hasPermission returns false for every permission', () {
      for (final perm in AdminPermission.values) {
        expect(
          AdminPermissions.hasPermission('editor', perm),
          isFalse,
          reason: 'Unknown role should not have $perm',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // AdminPermission enum completeness
  // -------------------------------------------------------------------------

  group('AdminPermission enum', () {
    test('enum contains viewUserData', () {
      expect(AdminPermission.values, contains(AdminPermission.viewUserData));
    });

    test('enum contains permaBanUser', () {
      expect(AdminPermission.values, contains(AdminPermission.permaBanUser));
    });

    test('enum contains tempBanUser', () {
      expect(AdminPermission.values, contains(AdminPermission.tempBanUser));
    });

    test('enum contains manageRoles', () {
      expect(AdminPermission.values, contains(AdminPermission.manageRoles));
    });

    test('enum contains editEarnings', () {
      expect(AdminPermission.values, contains(AdminPermission.editEarnings));
    });

    test('enum contains giftGold', () {
      expect(AdminPermission.values, contains(AdminPermission.giftGold));
    });

    test('moderator set is a proper subset of owner set', () {
      final mod = AdminPermissions.forRole('moderator');
      final own = AdminPermissions.forRole('owner');
      expect(own.containsAll(mod), isTrue);
      expect(mod.containsAll(own), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AdminConfig.ownerEmails
  // -------------------------------------------------------------------------

  group('AdminConfig.ownerEmails', () {
    test('ownerEmails is non-empty', () {
      expect(AdminConfig.ownerEmails, isNotEmpty);
    });

    test('ownerEmails contains the known owner email', () {
      expect(AdminConfig.ownerEmails, contains('jamiebright1@gmail.com'));
    });

    test('ownerEmails does not contain empty string', () {
      expect(AdminConfig.ownerEmails, isNot(contains('')));
    });
  });
}
