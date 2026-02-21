import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for account management operations: data export and account deletion.
///
/// Handles fetching all user data for export and cascading deletion of user
/// data across all Supabase tables.
class AccountManagementService {
  AccountManagementService._();

  static final AccountManagementService instance =
      AccountManagementService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Export user data
  // ---------------------------------------------------------------------------

  /// Fetch all user data from Supabase and return as a structured JSON string.
  ///
  /// Includes: profile, settings, scores history, friends list, challenge
  /// history. Excludes internal UUIDs and RLS metadata that are meaningless
  /// to the user.
  Future<String> exportUserData({
    required String userId,
    required String? email,
  }) async {
    try {
      // Fetch all data in parallel for speed.
      final results = await Future.wait<dynamic>([
        (() async => await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle())(),
        (() async => await _client
            .from('user_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle())(),
        (() async => await _client
            .from('account_state')
            .select()
            .eq('user_id', userId)
            .maybeSingle())(),
        (() async => await _client
            .from('scores')
            .select('score, time_ms, region, rounds_completed, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(500))(),
        _fetchFriendsList(userId),
        _fetchChallengeHistory(userId),
      ]);

      final profileData = results[0] as Map<String, dynamic>?;
      final settingsData = results[1] as Map<String, dynamic>?;
      final accountStateData = results[2] as Map<String, dynamic>?;
      final scoresData = results[3] as List<dynamic>;
      final friendsList = results[4] as List<Map<String, dynamic>>;
      final challengeHistory = results[5] as List<Map<String, dynamic>>;

      // Build a user-friendly export object (no internal UUIDs).
      final exportData = <String, dynamic>{
        'export_info': {
          'exported_at': DateTime.now().toUtc().toIso8601String(),
          'app': 'Flit - Geography Flight Game',
        },
        'account': {
          'email': email,
          'username': profileData?['username'],
          'display_name': profileData?['display_name'],
          'created_at': profileData?['created_at'],
        },
        'stats': {
          'level': profileData?['level'],
          'xp': profileData?['xp'],
          'coins': profileData?['coins'],
          'games_played': profileData?['games_played'],
          'best_score': profileData?['best_score'],
          'best_time_ms': profileData?['best_time_ms'],
          'total_flight_time_ms': profileData?['total_flight_time_ms'],
          'countries_found': profileData?['countries_found'],
        },
        'settings': settingsData != null
            ? {
                'turn_sensitivity': settingsData['turn_sensitivity'],
                'invert_controls': settingsData['invert_controls'],
                'enable_night': settingsData['enable_night'],
                'map_style': settingsData['map_style'],
                'english_labels': settingsData['english_labels'],
                'difficulty': settingsData['difficulty'],
              }
            : null,
        'customization': accountStateData != null
            ? {
                'avatar_config': accountStateData['avatar_config'],
                'license_data': accountStateData['license_data'],
                'unlocked_regions': accountStateData['unlocked_regions'],
                'equipped_plane': accountStateData['equipped_plane_id'],
                'equipped_contrail': accountStateData['equipped_contrail_id'],
              }
            : null,
        'scores_history': scoresData
            .map((s) => {
                  'score': s['score'],
                  'time_ms': s['time_ms'],
                  'region': s['region'],
                  'rounds_completed': s['rounds_completed'],
                  'played_at': s['created_at'],
                })
            .toList(),
        'friends': friendsList,
        'challenge_history': challengeHistory,
      };

      // Pretty-print for readability.
      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      debugPrint('[AccountManagementService] exportUserData failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFriendsList(String userId) async {
    try {
      final data = await _client
          .from('friendships')
          .select(
            'status, created_at, '
            'requester:profiles!friendships_requester_id_fkey(username, display_name), '
            'addressee:profiles!friendships_addressee_id_fkey(username, display_name)',
          )
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      return data.map<Map<String, dynamic>>((row) {
        // Include both sides of the friendship — the user can identify
        // themselves and see who the friend is.
        final requester = row['requester'] as Map<String, dynamic>?;
        final addressee = row['addressee'] as Map<String, dynamic>?;
        return {
          'requester_username': requester?['username'],
          'requester_display_name': requester?['display_name'],
          'addressee_username': addressee?['username'],
          'addressee_display_name': addressee?['display_name'],
          'status': row['status'],
          'friends_since': row['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[AccountManagementService] _fetchFriendsList failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchChallengeHistory(
    String userId,
  ) async {
    try {
      final data = await _client
          .from('challenges')
          .select(
            'challenger_name, challenged_name, status, winner_id, '
            'challenger_coins, challenged_coins, created_at, completed_at',
          )
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(100);

      return data
          .map<Map<String, dynamic>>((row) => {
                'challenger': row['challenger_name'],
                'challenged': row['challenged_name'],
                'status': row['status'],
                'coins_earned': row['challenger_coins'] ?? row['challenged_coins'],
                'played_at': row['created_at'],
                'completed_at': row['completed_at'],
              })
          .toList();
    } catch (e) {
      debugPrint(
        '[AccountManagementService] _fetchChallengeHistory failed: $e',
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Delete account
  // ---------------------------------------------------------------------------

  /// Delete all user data from Supabase tables.
  ///
  /// Cascade order: friendships, challenges, scores, account_state,
  /// user_settings, then profiles.
  ///
  /// After deletion, the caller must sign out the Supabase auth session
  /// and navigate to the login screen.
  ///
  // TODO(account-deletion): Add a Supabase Edge Function to delete the auth
  // user itself via `auth.admin.deleteUser()`. The client SDK cannot call
  // admin endpoints. Until then, the auth row remains orphaned but all
  // user-visible data is removed. The Edge Function should be called after
  // table data is deleted.
  Future<void> deleteAccountData(String userId) async {
    try {
      // Delete in dependency order — child tables first, then profile last.
      // Each delete targets rows where the user is referenced.

      // 1. Friendships (user can be requester or addressee).
      await _client
          .from('friendships')
          .delete()
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      // 2. Challenges (user can be challenger or challenged).
      await _client
          .from('challenges')
          .delete()
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId');

      // 3. Scores.
      await _client.from('scores').delete().eq('user_id', userId);

      // 4. Account state.
      await _client.from('account_state').delete().eq('user_id', userId);

      // 5. User settings.
      await _client.from('user_settings').delete().eq('user_id', userId);

      // 6. Profile (last, since other tables may reference it).
      await _client.from('profiles').delete().eq('id', userId);
    } catch (e) {
      debugPrint('[AccountManagementService] deleteAccountData failed: $e');
      rethrow;
    }
  }
}
