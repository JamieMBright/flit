import 'package:flit/data/services/block_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for BlockService (WAVE 2, item A2): block-list caching, the
/// block/unblock cache mutation, and the filtering used to hide blocked users
/// from friends, leaderboards and matchmaking.
void main() {
  final svc = BlockService.instance;

  setUp(svc.clear);
  tearDown(svc.clear);

  group('isBlocked / cache', () {
    test('reports blocked ids and ignores unknown ids', () {
      svc.debugSetBlocked(['a', 'b']);
      expect(svc.isBlocked('a'), isTrue);
      expect(svc.isBlocked('b'), isTrue);
      expect(svc.isBlocked('c'), isFalse);
      expect(svc.blockedIds, {'a', 'b'});
    });

    test('clear empties the cache', () {
      svc.debugSetBlocked(['a']);
      svc.clear();
      expect(svc.isBlocked('a'), isFalse);
      expect(svc.blockedIds, isEmpty);
    });
  });

  group('block/unblock cache mutation', () {
    test('optimistic block then unblock updates the cache', () {
      svc.debugOptimisticBlock('x');
      expect(svc.isBlocked('x'), isTrue);
      svc.debugOptimisticUnblock('x');
      expect(svc.isBlocked('x'), isFalse);
    });
  });

  group('filterBlocked', () {
    test('removes blocked entries and keeps the rest', () {
      svc.debugSetBlocked(['blocked1', 'blocked2']);
      final ids = ['keep1', 'blocked1', 'keep2', 'blocked2', 'keep3'];

      final visible = svc.filterBlocked<String>(ids, (e) => e).toList();

      expect(visible, ['keep1', 'keep2', 'keep3']);
    });

    test('works over records via an id selector (friends/leaderboard shape)',
        () {
      svc.debugSetBlocked(['u2']);
      final entries = [
        (playerId: 'u1', name: 'Ana'),
        (playerId: 'u2', name: 'Bob'),
        (playerId: 'u3', name: 'Cid'),
      ];

      final visible = svc.filterBlocked(entries, (e) => e.playerId).toList();

      expect(visible.map((e) => e.playerId), ['u1', 'u3']);
    });

    test('is a no-op passthrough when nothing is blocked', () {
      final ids = ['a', 'b', 'c'];
      expect(svc.filterBlocked<String>(ids, (e) => e).toList(), ids);
    });
  });
}
