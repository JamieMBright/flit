import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player.dart';

/// How an account deletion resolved.
enum AccountDeletionOutcome {
  /// The edge function ran the full cascade AND removed the `auth.users` row.
  serverCascade,

  /// The edge function was unavailable (not deployed); app-side data was wiped
  /// client-side but the `auth.users` row (email) remains until it is deployed.
  clientFallback,
}

/// Service for account management operations: data export and account deletion.
///
/// Handles fetching all user data for export and cascading deletion of user
/// data across all Supabase tables.
class AccountManagementService {
  AccountManagementService._();

  static final AccountManagementService instance = AccountManagementService._();

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
    Player? currentPlayer,
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
        // Use local AccountState stats (currentPlayer) when available,
        // falling back to Supabase profile data. This avoids showing stale
        // lvl 1 / xp 0 when the latest state hasn't been synced to the DB yet.
        'stats': {
          'level': currentPlayer?.level ?? profileData?['level'],
          'xp': currentPlayer?.xp ?? profileData?['xp'],
          'coins': currentPlayer?.coins ?? profileData?['coins'],
          'games_played':
              currentPlayer?.gamesPlayed ?? profileData?['games_played'],
          'best_score': currentPlayer?.bestScore ?? profileData?['best_score'],
          'best_time_ms': currentPlayer?.bestTime?.inMilliseconds ??
              profileData?['best_time_ms'],
          'total_flight_time_ms':
              currentPlayer?.totalFlightTime.inMilliseconds ??
                  profileData?['total_flight_time_ms'],
          'countries_found':
              currentPlayer?.countriesFound ?? profileData?['countries_found'],
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
            .map(
              (s) => {
                'score': s['score'],
                'time_ms': s['time_ms'],
                'region': s['region'],
                'rounds_completed': s['rounds_completed'],
                'played_at': s['created_at'],
              },
            )
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
            'requester:profiles!fk_friendships_requester_profiles(username, display_name), '
            'addressee:profiles!fk_friendships_addressee_profiles(username, display_name)',
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
            'challenger_id, challenger_name, challenged_name, status, winner_id, '
            'challenger_coins, challenged_coins, created_at, completed_at',
          )
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(100);

      return data
          .map<Map<String, dynamic>>(
            (row) => {
              'challenger': row['challenger_name'],
              'challenged': row['challenged_name'],
              'status': row['status'],
              // Show coins for the role the current user played:
              // challenger_id rows → challenger_coins; challenged_id rows → challenged_coins.
              'coins_earned': row['challenger_id'] == userId
                  ? row['challenger_coins']
                  : row['challenged_coins'],
              'played_at': row['created_at'],
              'completed_at': row['completed_at'],
            },
          )
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

  /// Delete a user's account.
  ///
  /// Primary path: invoke the `delete-auth-user` Edge Function, which runs the
  /// FULL cascade server-side (with the service role, so RLS cannot block it)
  /// AND removes the `auth.users` row (the email). This is what lets a normal,
  /// non-owner account be fully and correctly deleted in one call.
  ///
  /// Graceful degradation: edge functions deploy separately from the app, so if
  /// the (new) function is not yet deployed the server call returns 404. In that
  /// case we fall back to wiping all app-side data from the client. The
  /// `auth.users` row then remains until the function is deployed; that is
  /// surfaced via the returned [AccountDeletionOutcome] and logged.
  ///
  /// IMPORTANT ordering: the server call happens BEFORE any client-side table
  /// deletes. The old code deleted the caller's `profiles` row first, which
  /// broke the function's role lookup — that is fixed both here (order) and in
  /// the function (self-delete is authorized from the JWT, not the profile).
  ///
  /// After deletion the caller must sign out the Supabase session and navigate
  /// to the login screen.
  Future<AccountDeletionOutcome> deleteAccountData(String userId) {
    return orchestrateDeletion(
      serverDelete: () => _invokeServerDeletion(userId),
      clientFallbackCascade: () => _clientSideCascade(userId),
    );
  }

  /// Testable orchestration of the deletion cascade, decoupled from Supabase.
  ///
  /// - [serverDelete] returns `true` if the server fully handled deletion, or
  ///   `false` if the edge function is unavailable (not deployed). It throws on
  ///   any real server error (403/500/…), which propagates so the UI can report
  ///   a genuine failure.
  /// - [clientFallbackCascade] wipes app-side data when the server is
  ///   unavailable.
  @visibleForTesting
  static Future<AccountDeletionOutcome> orchestrateDeletion({
    required Future<bool> Function() serverDelete,
    required Future<void> Function() clientFallbackCascade,
  }) async {
    final serverHandled = await serverDelete();
    if (serverHandled) {
      return AccountDeletionOutcome.serverCascade;
    }
    // Function not deployed yet — degrade gracefully by wiping app-side data.
    await clientFallbackCascade();
    return AccountDeletionOutcome.clientFallback;
  }

  /// Invokes the edge function. Returns `true` on success, `false` if the
  /// function is not deployed (404), and throws on any other failure.
  Future<bool> _invokeServerDeletion(String userId) async {
    try {
      // `invoke` returns a FunctionResponse only for 2xx; any non-2xx (incl.
      // 404 "not deployed") is thrown as a FunctionException, handled below.
      final res = await _client.functions.invoke(
        'delete-auth-user',
        body: {'user_id': userId},
      );
      final data = res.data;
      if (data is Map && data['success'] == false) {
        throw Exception('delete-auth-user error: ${data['error']}');
      }
      return true;
    } on FunctionException catch (e) {
      // 404 => function not deployed yet; degrade gracefully.
      if (e.status == 404) {
        debugPrint(
          '[AccountManagementService] delete-auth-user missing (404) — '
          'falling back to client-side cascade.',
        );
        return false;
      }
      rethrow;
    }
  }

  /// Ordered list of app-side tables the client-side cascade deletes from,
  /// child/relationship tables first and `profiles` LAST (so FK-dependent rows
  /// are gone before the profile row they reference). This is the single
  /// source of truth for the cascade's coverage; [_clientSideCascade] deletes
  /// from exactly these tables, in this order. Exposed so tests can pin the
  /// coverage without a live Supabase connection.
  @visibleForTesting
  static const List<String> cascadeTables = [
    'friendships',
    'challenges',
    'blocked_users',
    'scores',
    'account_state',
    'user_settings',
    'iap_receipts',
    'profiles',
  ];

  /// Fallback cascade run entirely from the client (used only when the edge
  /// function is not deployed). Deletes every app-side table the user touches
  /// (see [cascadeTables] for the ordered coverage).
  /// Cannot remove the `auth.users` row — that waits for the function deploy.
  Future<void> _clientSideCascade(String userId) async {
    final completed = <String>[];

    void logStep(String step) {
      completed.add(step);
      debugPrint(
        '[AccountManagementService] clientSideCascade: completed $step',
      );
    }

    try {
      // Child/relationship tables first.
      await _client
          .from('friendships')
          .delete()
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');
      logStep('friendships');

      await _client
          .from('challenges')
          .delete()
          .or('challenger_id.eq.$userId,challenged_id.eq.$userId');
      logStep('challenges');

      // Blocks (table may not exist on older databases) — best-effort.
      try {
        await _client
            .from('blocked_users')
            .delete()
            .or('blocker_id.eq.$userId,blocked_id.eq.$userId');
        logStep('blocked_users');
      } catch (e) {
        debugPrint(
          '[AccountManagementService] blocked_users delete skipped: $e',
        );
      }

      await _client.from('scores').delete().eq('user_id', userId);
      logStep('scores');

      await _client.from('account_state').delete().eq('user_id', userId);
      logStep('account_state');

      await _client.from('user_settings').delete().eq('user_id', userId);
      logStep('user_settings');

      // IAP receipts — best-effort (older rows may be RLS-protected).
      try {
        await _client.from('iap_receipts').delete().eq('user_id', userId);
        logStep('iap_receipts');
      } catch (e) {
        debugPrint(
          '[AccountManagementService] iap_receipts delete skipped: $e',
        );
      }

      // Profile last.
      await _client.from('profiles').delete().eq('id', userId);
      logStep('profiles');
    } catch (e) {
      debugPrint(
        '[AccountManagementService] clientSideCascade failed after '
        '[${completed.join(', ')}]: $e',
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GDPR request tracking
  // ---------------------------------------------------------------------------

  /// Submit a GDPR request (export or delete) for tracking.
  Future<void> submitGdprRequest({
    required String requestType,
    String? username,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('gdpr_requests').insert({
      'user_id': userId,
      'username': username,
      'request_type': requestType,
    });
  }
}
