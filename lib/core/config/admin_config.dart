import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin access configuration.
///
/// Admin roles are stored in the `profiles.admin_role` column:
///   - `null`        → regular user
///   - `'moderator'` → limited admin (view histories, gift capped amounts)
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
