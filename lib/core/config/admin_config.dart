import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin access configuration.
///
/// Admin roles are stored in the `profiles.admin_role` column:
///   - `null`        → regular user
///   - `'moderator'` → limited admin (view data, moderate usernames)
///   - `'owner'`     → god mode (unlimited access)
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
  // ── View / Read-only ──
  /// View analytics dashboard (player counts, game stats, top players).
  viewAnalytics,

  /// Look up a player by username and view their profile data.
  viewUserData,

  /// View a player's game history / recent scores.
  viewGameHistory,

  /// View coin ledger entries for a player.
  viewCoinLedger,

  /// View game log (debug entries).
  viewGameLog,

  /// View design previews (planes, avatars, country flags & outlines).
  viewDesignPreviews,

  /// View country difficulty ratings.
  viewDifficulty,

  /// View ad configuration settings (read-only for moderators).
  viewAdConfig,

  /// View error telemetry / runtime errors.
  viewErrors,

  // ── Moderation ──
  /// Change a player's username (e.g. profanity enforcement).
  changeUsername,

  // ── Owner-only (economy / gifting / player modification) ──
  /// Quick self-service actions (give self gold, XP, flights).
  selfServiceActions,

  /// Gift gold to another player.
  giftGold,

  /// Gift levels to another player.
  giftLevels,

  /// Gift flights to another player.
  giftFlights,

  /// Set a player's coins to an exact value.
  setCoins,

  /// Set a player's level to an exact value.
  setLevel,

  /// Set a player's flights to an exact value.
  setFlights,

  /// Gift a cosmetic item to a player.
  giftCosmetic,

  /// Set a player's pilot license stats.
  setLicense,

  /// Set a player's avatar configuration.
  setAvatar,

  /// Unlock all shop items for a player.
  unlockAll,

  /// Promote / demote players to moderator or revoke access.
  manageRoles,

  /// Edit earnings config (daily scramble rewards, flight caps, etc.).
  editEarnings,

  /// Manage promotions (create, toggle, delete).
  editPromotions,

  /// Edit gold package pricing.
  editGoldPackages,

  /// Edit shop price overrides.
  editShopPrices,

  /// Edit country difficulty ratings.
  editDifficulty,
}

/// Resolves the set of [AdminPermission]s for a given `admin_role` value.
abstract final class AdminPermissions {
  /// Permissions granted to moderators.
  ///
  /// Moderators can **view** data and **moderate usernames**, but cannot
  /// gift items, change economy config, or promote/demote users.
  static const Set<AdminPermission> moderator = {
    AdminPermission.viewAnalytics,
    AdminPermission.viewUserData,
    AdminPermission.viewGameHistory,
    AdminPermission.viewCoinLedger,
    AdminPermission.viewGameLog,
    AdminPermission.viewDesignPreviews,
    AdminPermission.viewDifficulty,
    AdminPermission.viewAdConfig,
    AdminPermission.viewErrors,
    AdminPermission.changeUsername,
  };

  /// Permissions granted to owners — everything.
  static const Set<AdminPermission> owner = AdminPermission.values;

  /// Returns the permission set for the given [adminRole] string.
  ///
  /// Returns an empty set for null / unknown roles.
  static Set<AdminPermission> forRole(String? adminRole) {
    switch (adminRole) {
      case 'owner':
        return owner;
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
