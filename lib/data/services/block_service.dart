import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/network_timeout.dart';

/// Blocked-user management (Apple Guideline 1.2: UGC/social apps must offer
/// both Report and Block).
///
/// The blocker is always the authenticated user — the client never supplies a
/// blocker id (the `block_user`/`unblock_user` RPCs use `auth.uid()`).
///
/// Feature-detection + graceful degradation: the `blocked_users` table / RPCs
/// deploy separately from the app (migration `20260706_blocked_users.sql`). If
/// they are not present yet, every method degrades to a no-op / empty result
/// instead of throwing, so the app keeps working before the migration lands.
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// In-memory cache of ids the current user has blocked. Used for synchronous
  /// client-side filtering of lists (friends, leaderboard, matchmaking).
  final Set<String> _blockedIds = <String>{};

  /// True once [refreshBlockedIds] has completed at least once this session.
  bool _loaded = false;

  /// Whether the backend appears to support blocking (table/RPC present). Set
  /// false the first time a "missing relation/function" error is seen so we
  /// stop hammering a backend that can't serve it.
  bool _backendSupported = true;

  bool get isSupported => _backendSupported;
  bool get isLoaded => _loaded;

  /// Snapshot of currently-blocked ids (empty if unsupported / not loaded).
  Set<String> get blockedIds => Set.unmodifiable(_blockedIds);

  bool isBlocked(String userId) => _blockedIds.contains(userId);

  /// Removes any entries whose id the current user has blocked. Safe to call
  /// even if blocking is unsupported (returns [items] unchanged).
  Iterable<T> filterBlocked<T>(
    Iterable<T> items,
    String Function(T) idOf,
  ) {
    if (_blockedIds.isEmpty) return items;
    return items.where((e) => !_blockedIds.contains(idOf(e)));
  }

  /// (Re)loads the current user's block list into [_blockedIds]. Never throws;
  /// on any failure it leaves the last-known set intact and returns false.
  Future<bool> refreshBlockedIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    if (!_backendSupported) return false;
    try {
      final rows = await withNetworkTimeout(
        _client
            .from('blocked_users')
            .select('blocked_id')
            .eq('blocker_id', uid),
        label: 'load blocks',
      );
      _blockedIds
        ..clear()
        ..addAll(
          (rows as List)
              .map((r) => (r as Map)['blocked_id'] as String?)
              .whereType<String>(),
        );
      _loaded = true;
      return true;
    } catch (e) {
      _handleBackendError(e, 'refreshBlockedIds');
      return false;
    }
  }

  /// Blocks [blockedId]. Optimistically updates the cache. Returns true on
  /// success. Never throws; returns false if unsupported or on error.
  Future<bool> blockUser(String blockedId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || blockedId == uid) return false;
    // Optimistic local update so UI filtering is instant.
    _blockedIds.add(blockedId);
    if (!_backendSupported) return false;
    try {
      await withNetworkTimeout(
        _client.rpc('block_user', params: {'p_blocked_id': blockedId}),
        label: 'block user',
      );
      return true;
    } catch (e) {
      // If the RPC is missing but the table exists, fall back to a direct,
      // policy-guarded insert (auth.uid() enforced by RLS WITH CHECK).
      if (_isMissingFunction(e)) {
        try {
          await withNetworkTimeout(
            _client.from('blocked_users').insert({
              'blocker_id': uid,
              'blocked_id': blockedId,
            }),
            label: 'block user (insert)',
          );
          return true;
        } catch (e2) {
          _handleBackendError(e2, 'blockUser.insert');
          _blockedIds.remove(blockedId); // revert optimistic add
          return false;
        }
      }
      _handleBackendError(e, 'blockUser');
      _blockedIds.remove(blockedId); // revert optimistic add
      return false;
    }
  }

  /// Unblocks [blockedId]. Optimistically updates the cache. Never throws.
  Future<bool> unblockUser(String blockedId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final wasBlocked = _blockedIds.remove(blockedId);
    if (!_backendSupported) return false;
    try {
      await withNetworkTimeout(
        _client.rpc('unblock_user', params: {'p_blocked_id': blockedId}),
        label: 'unblock user',
      );
      return true;
    } catch (e) {
      if (_isMissingFunction(e)) {
        try {
          await withNetworkTimeout(
            _client
                .from('blocked_users')
                .delete()
                .eq('blocker_id', uid)
                .eq('blocked_id', blockedId),
            label: 'unblock user (delete)',
          );
          return true;
        } catch (e2) {
          _handleBackendError(e2, 'unblockUser.delete');
          if (wasBlocked) _blockedIds.add(blockedId); // revert
          return false;
        }
      }
      _handleBackendError(e, 'unblockUser');
      if (wasBlocked) _blockedIds.add(blockedId); // revert
      return false;
    }
  }

  /// Clears cached state (e.g. on sign-out).
  void clear() {
    _blockedIds.clear();
    _loaded = false;
    _backendSupported = true;
  }

  /// Test-only: seed the in-memory block cache to exercise filtering logic
  /// without a live Supabase backend.
  @visibleForTesting
  void debugSetBlocked(Iterable<String> ids) {
    _blockedIds
      ..clear()
      ..addAll(ids);
    _loaded = true;
  }

  /// Test-only: optimistic add/remove mirror the block/unblock cache mutation.
  @visibleForTesting
  void debugOptimisticBlock(String id) => _blockedIds.add(id);

  @visibleForTesting
  void debugOptimisticUnblock(String id) => _blockedIds.remove(id);

  void _handleBackendError(Object e, String where) {
    if (_isMissingRelation(e)) {
      _backendSupported = false;
      debugPrint(
        '[BlockService] $where: blocked_users table/RPC not deployed yet — '
        'blocking disabled until migration 20260706_blocked_users.sql lands.',
      );
      return;
    }
    debugPrint('[BlockService] $where failed: $e');
  }

  /// Postgres "undefined table" (42P01) — table not migrated yet.
  bool _isMissingRelation(Object e) {
    if (e is PostgrestException) {
      return e.code == '42P01' || e.code == '42883';
    }
    final s = e.toString();
    return s.contains('does not exist') || s.contains('PGRST205');
  }

  /// Postgres "undefined function" (42883) — RPC not migrated yet.
  bool _isMissingFunction(Object e) {
    if (e is PostgrestException) {
      return e.code == '42883' || e.code == 'PGRST202';
    }
    final s = e.toString();
    return s.contains('function') && s.contains('does not exist');
  }
}
