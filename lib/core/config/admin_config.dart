import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin access configuration.
///
/// Admin roles are stored in the `profiles.admin_role` column:
///   - `null`           → regular user
///   - `'moderator'`    → limited admin (view data, moderate usernames)
///   - `'collaborator'` → trusted collaborator (edit difficulty, flags,
///                         announcements, app config — no economy or
///                         destructive actions)
///   - `'owner'`        → god mode (unlimited access)
///
/// The primary check is [isCurrentUserAdmin] which uses the auth email
/// as a client-side bootstrap (before DB data loads). Once the Player
/// model is hydrated from Supabase, use `AccountState.isAdmin` /
/// `AccountState.isOwner` instead for the DB-authoritative answer.
abstract final class AdminConfig {
  /// Known owner emails — used as a client-side bootstrap before DB loads.
  /// The server-side `admin_role` column is the real source of truth.
  static const Set<String> ownerEmails = {'jamiebright1@gmail.com'};

  /// Whether the currently authenticated Supabase user is a known owner
  /// by email. Use this only as a pre-hydration fallback; prefer
  /// `AccountState.isAdmin` once Riverpod state is available.
  static bool get isCurrentUserAdmin {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return email != null && ownerEmails.contains(email);
  }
}

/// Granular admin permissions.
///
/// Each permission maps to a specific capability in the admin panel.
/// Use [AdminPermissions.forRole] to get the set of permissions for
/// a given `admin_role` value.
enum AdminPermission {
  // ── View / Read-only (moderator + owner) ──
  viewAnalytics,
  viewUserData,
  viewGameHistory,
  viewCoinLedger,
  viewGameLog,
  viewDesignPreviews,
  viewDifficulty,
  viewAdConfig,
  viewErrors,
  viewReports,
  viewAnnouncements,
  viewFeatureFlags,
  viewEconomyHealth,
  viewSuspiciousActivity,
  viewOwnAuditLog,

  // ── Moderation (moderator + owner) ──
  changeUsername,
  resolveReports,
  tempBanUser,
  triggerPasswordReset,
  createInfoAnnouncements,

  // ── Owner-only ──
  selfServiceActions,
  giftGold,
  giftLevels,
  giftFlights,
  setCoins,
  setLevel,
  setFlights,
  giftCosmetic,
  setLicense,
  setAvatar,
  unlockAll,
  manageRoles,
  editEarnings,
  editPromotions,
  editGoldPackages,
  editShopPrices,
  editDifficulty,
  permaBanUser,
  unbanUser,
  editAppConfig,
  editAnnouncements,
  editFeatureFlags,
  viewAuditLog,
}

/// Resolves the set of [AdminPermission]s for a given `admin_role` value.
abstract final class AdminPermissions {
  /// Permissions granted to moderators.
  ///
  /// Moderators can **view** data, **moderate usernames**, resolve reports,
  /// temp-ban users, and create info announcements. They cannot gift items,
  /// change economy config, or promote/demote users.
  static const Set<AdminPermission> moderator = {
    // View
    AdminPermission.viewAnalytics,
    AdminPermission.viewUserData,
    AdminPermission.viewGameHistory,
    AdminPermission.viewCoinLedger,
    AdminPermission.viewGameLog,
    AdminPermission.viewDesignPreviews,
    AdminPermission.viewDifficulty,
    AdminPermission.viewAdConfig,
    AdminPermission.viewErrors,
    AdminPermission.viewReports,
    AdminPermission.viewAnnouncements,
    AdminPermission.viewFeatureFlags,
    AdminPermission.viewEconomyHealth,
    AdminPermission.viewSuspiciousActivity,
    AdminPermission.viewOwnAuditLog,
    // Moderation
    AdminPermission.changeUsername,
    AdminPermission.resolveReports,
    AdminPermission.tempBanUser,
    AdminPermission.triggerPasswordReset,
    AdminPermission.createInfoAnnouncements,
  };

  /// Permissions granted to collaborators — everything except economy and
  /// destructive actions.
  ///
  /// Collaborators are trusted game-design partners. They can edit difficulty
  /// ratings, feature flags, announcements, and app config, but cannot touch
  /// the economy (gifting, pricing, earnings) or perform destructive actions
  /// (perma-ban, unban, role management).
  static final Set<AdminPermission> collaborator =
      Set<AdminPermission>.unmodifiable({
        ...moderator,
        // ── Collaborator extras (game design + content) ──
        AdminPermission.editDifficulty,
        AdminPermission.editAnnouncements,
        AdminPermission.editAppConfig,
        AdminPermission.editFeatureFlags,
        AdminPermission.viewAuditLog,
      });

  /// Permissions granted to owners — everything.
  static final Set<AdminPermission> owner = Set<AdminPermission>.unmodifiable(
    AdminPermission.values,
  );

  /// Returns the permission set for the given [adminRole] string.
  ///
  /// Returns an empty set for null / unknown roles.
  static Set<AdminPermission> forRole(String? adminRole) {
    switch (adminRole) {
      case 'owner':
        return owner;
      case 'collaborator':
        return collaborator;
      case 'moderator':
        return moderator;
      default:
        return const {};
    }
  }

  /// Convenience: check if a role has a specific permission.
  static bool hasPermission(String? adminRole, AdminPermission permission) {
    return forRole(adminRole).contains(permission);
  }
}
