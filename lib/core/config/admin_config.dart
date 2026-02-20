import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin access configuration.
///
/// Only the admin email has access to the admin panel.
/// The same email is enforced in Supabase RLS policies so that
/// even crafted API calls cannot bypass admin restrictions.
abstract final class AdminConfig {
  /// The sole admin email. Hardcoded here and mirrored in the
  /// Supabase RLS policy for belt-and-suspenders security.
  static const String adminEmail = 'jamiebright1@gmail.com';

  /// Whether the currently authenticated Supabase user is an admin.
  static bool get isCurrentUserAdmin {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return email != null && email == adminEmail;
  }
}
