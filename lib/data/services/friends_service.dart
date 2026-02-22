import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';
import 'ttl_cache.dart';

/// Service for managing friendships via Supabase.
///
/// All methods require an authenticated user.
/// Read-heavy paths ([fetchFriends], [fetchPendingRequests]) are cached with a
/// 60-second TTL. Mutations automatically invalidate the cache so the next
/// read fetches fresh data.
class FriendsService {
  FriendsService._();

  static final FriendsService instance = FriendsService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // 60 s TTL — friends list changes infrequently.
  final _friendsCache = TtlCache<List<Friend>>(const Duration(seconds: 60));
  final _pendingCache =
      TtlCache<
        List<
          ({
            int friendshipId,
            String requesterId,
            String username,
            String? displayName,
            String? avatarUrl,
          })
        >
      >(const Duration(seconds: 60));

  /// Drop cached friends/pending data. Called automatically after mutations.
  void invalidateCache() {
    _friendsCache.invalidate();
    _pendingCache.invalidate();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search for a user by username. Returns the profile if found.
  Future<Map<String, dynamic>?> searchUser(String username) async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('username', username)
          .neq('id', _userId!)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[FriendsService] searchUser failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Friend requests
  // ---------------------------------------------------------------------------

  /// Send a friend request. Returns true on success.
  Future<bool> sendFriendRequest(String addresseeId) async {
    if (_userId == null) return false;
    try {
      // If they already sent us a pending request, auto-accept it so both
      // players become friends immediately when they add each other.
      final reversePending = await _client
          .from('friendships')
          .select('id')
          .eq('requester_id', addresseeId)
          .eq('addressee_id', _userId!)
          .eq('status', 'pending')
          .maybeSingle();

      if (reversePending != null) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'})
            .eq('id', reversePending['id'] as int);
        await _deleteOwnPendingRequest(addresseeId);
        invalidateCache();
        return true;
      }

      await _client.from('friendships').insert({
        'requester_id': _userId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });

      // Handle near-simultaneous mutual requests: if the reverse pending row
      // appeared between our first check and insert, accept it now.
      final reverseAfterInsert = await _client
          .from('friendships')
          .select('id')
          .eq('requester_id', addresseeId)
          .eq('addressee_id', _userId!)
          .eq('status', 'pending')
          .maybeSingle();

      if (reverseAfterInsert != null) {
        await _client
            .from('friendships')
            .update({'status': 'accepted'})
            .eq('id', reverseAfterInsert['id'] as int);
        await _deleteOwnPendingRequest(addresseeId);
      }
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] sendFriendRequest failed: $e');
      return false;
    }
  }

  Future<void> _deleteOwnPendingRequest(String addresseeId) async {
    if (_userId == null) return;
    await _client
        .from('friendships')
        .delete()
        .eq('requester_id', _userId!)
        .eq('addressee_id', addresseeId)
        .eq('status', 'pending');
  }

  /// Accept a friend request. Returns true on success.
  Future<bool> acceptFriendRequest(int friendshipId) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] acceptFriendRequest failed: $e');
      return false;
    }
  }

  /// Decline a friend request. Returns true on success.
  Future<bool> declineFriendRequest(int friendshipId) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('friendships')
          .update({'status': 'declined'})
          .eq('id', friendshipId);
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] declineFriendRequest failed: $e');
      return false;
    }
  }

  /// Remove a friendship (unfriend).
  Future<bool> removeFriend(int friendshipId) async {
    if (_userId == null) return false;
    try {
      await _client.from('friendships').delete().eq('id', friendshipId);
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] removeFriend failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch friends
  // ---------------------------------------------------------------------------

  /// Fetch all accepted friends with profile data.
  Future<List<Friend>> fetchFriends() async {
    if (_userId == null) return [];

    const cacheKey = 'friends';
    final cached = _friendsCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      // Fetch friendships where current user is either party and status is accepted.
      final data = await _client
          .from('friendships')
          .select(
            'id, requester_id, addressee_id, status, created_at, '
            'requester:profiles!friendships_requester_id_fkey(id, username, display_name, avatar_url), '
            'addressee:profiles!friendships_addressee_id_fkey(id, username, display_name, avatar_url)',
          )
          .eq('status', 'accepted')
          .or('requester_id.eq.$_userId,addressee_id.eq.$_userId');

      final result = data.map<Friend>((row) {
        // The "friend" is whichever party isn't the current user.
        final isRequester = row['requester_id'] == _userId;
        final profile =
            (isRequester ? row['addressee'] : row['requester'])
                as Map<String, dynamic>;
        return Friend(
          id: row['id'].toString(),
          playerId: profile['id'] as String,
          username: profile['username'] as String? ?? 'Unknown',
          displayName: profile['display_name'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
          status: FriendshipStatus.accepted,
        );
      }).toList();

      _friendsCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[FriendsService] fetchFriends failed: $e');
      return [];
    }
  }

  /// Fetch pending friend requests where the current user is the addressee.
  Future<
    List<
      ({
        int friendshipId,
        String requesterId,
        String username,
        String? displayName,
        String? avatarUrl,
      })
    >
  >
  fetchPendingRequests() async {
    if (_userId == null) return [];

    const cacheKey = 'pending';
    final cached = _pendingCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('friendships')
          .select(
            'id, requester_id, '
            'requester:profiles!friendships_requester_id_fkey(id, username, display_name, avatar_url)',
          )
          .eq('addressee_id', _userId!)
          .eq('status', 'pending');

      final result = data.map((row) {
        final profile = row['requester'] as Map<String, dynamic>;
        return (
          friendshipId: row['id'] as int,
          requesterId: profile['id'] as String,
          username: profile['username'] as String? ?? 'Unknown',
          displayName: profile['display_name'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
        );
      }).toList();

      _pendingCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[FriendsService] fetchPendingRequests failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Head-to-head record
  // ---------------------------------------------------------------------------

  /// Compute H2H record between current user and a friend from challenges.
  ///
  /// Returns lifetime totals, last-10-game breakdown, and last-game result.
  Future<HeadToHead> fetchH2HRecord(String friendId, String friendName) async {
    if (_userId == null) {
      return HeadToHead(
        friendId: friendId,
        friendName: friendName,
        wins: 0,
        losses: 0,
        totalChallenges: 0,
      );
    }
    try {
      // Fetch all completed challenges between the two players (newest first).
      final data = await _client
          .from('challenges')
          .select('winner_id, created_at')
          .eq('status', 'completed')
          .or(
            'and(challenger_id.eq.$_userId,challenged_id.eq.$friendId),'
            'and(challenger_id.eq.$friendId,challenged_id.eq.$_userId)',
          )
          .order('created_at', ascending: false);

      var wins = 0;
      var losses = 0;
      var last10Wins = 0;
      var last10Losses = 0;
      bool? lastGameWon;
      DateTime? lastPlayed;

      for (var i = 0; i < data.length; i++) {
        final row = data[i];
        if (lastPlayed == null && row['created_at'] != null) {
          lastPlayed = DateTime.tryParse(row['created_at'] as String);
        }
        final winnerId = row['winner_id'] as String?;
        final isWin = winnerId == _userId;
        final isLoss = winnerId == friendId;

        if (isWin) wins++;
        if (isLoss) losses++;

        // Last 10 games.
        if (i < 10) {
          if (isWin) last10Wins++;
          if (isLoss) last10Losses++;
        }

        // Most recent game result.
        if (i == 0) {
          if (isWin) {
            lastGameWon = true;
          } else if (isLoss) {
            lastGameWon = false;
          }
        }
      }

      return HeadToHead(
        friendId: friendId,
        friendName: friendName,
        wins: wins,
        losses: losses,
        totalChallenges: data.length,
        last10Wins: last10Wins,
        last10Losses: last10Losses,
        last10Total: data.length < 10 ? data.length : 10,
        lastGameWon: lastGameWon,
        lastPlayed: lastPlayed,
      );
    } catch (e) {
      debugPrint('[FriendsService] fetchH2HRecord failed: $e');
      return HeadToHead(
        friendId: friendId,
        friendName: friendName,
        wins: 0,
        losses: 0,
        totalChallenges: 0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Send coins
  // ---------------------------------------------------------------------------

  /// Transfer coins from current user to another user.
  ///
  /// Uses the atomic `send_coins` DB function to prevent race conditions
  /// (double-spend, negative balances). Both deduction and credit happen
  /// in a single transaction with row-level locks.
  Future<bool> sendCoins({
    required String recipientId,
    required int amount,
  }) async {
    if (_userId == null || amount <= 0) return false;
    try {
      final result = await _client.rpc(
        'send_coins',
        params: {
          'p_sender_id': _userId!,
          'p_recipient_id': recipientId,
          'p_amount': amount,
        },
      );

      if (result is Map<String, dynamic>) {
        return result['success'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('[FriendsService] sendCoins failed: $e');
      return false;
    }
  }

  /// Gift a shop cosmetic to another player (gifter pays the cost).
  ///
  /// Uses the atomic `gift_cosmetic` DB function.
  Future<Map<String, dynamic>> giftCosmetic({
    required String recipientId,
    required String cosmeticId,
    required int cost,
  }) async {
    if (_userId == null) {
      return {'success': false, 'error': 'Not logged in'};
    }
    try {
      final result = await _client.rpc(
        'gift_cosmetic',
        params: {
          'p_gifter_id': _userId!,
          'p_recipient_id': recipientId,
          'p_cosmetic_id': cosmeticId,
          'p_cost': cost,
        },
      );
      if (result is Map<String, dynamic>) return result;
      return {'success': false, 'error': 'Unexpected response'};
    } catch (e) {
      debugPrint('[FriendsService] giftCosmetic failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Gift an avatar part to another player (gifter pays the cost).
  ///
  /// Uses the atomic `gift_avatar_part` DB function.
  Future<Map<String, dynamic>> giftAvatarPart({
    required String recipientId,
    required String partId,
    required int cost,
  }) async {
    if (_userId == null) {
      return {'success': false, 'error': 'Not logged in'};
    }
    try {
      final result = await _client.rpc(
        'gift_avatar_part',
        params: {
          'p_gifter_id': _userId!,
          'p_recipient_id': recipientId,
          'p_part_id': partId,
          'p_cost': cost,
        },
      );
      if (result is Map<String, dynamic>) return result;
      return {'success': false, 'error': 'Unexpected response'};
    } catch (e) {
      debugPrint('[FriendsService] giftAvatarPart failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
