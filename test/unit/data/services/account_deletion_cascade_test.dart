import 'package:flit/data/services/account_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the reordered account-deletion orchestration (WAVE 2, item A1).
///
/// The real fix moves the edge-function call BEFORE any client-side table
/// deletes, and degrades gracefully when the function is not yet deployed.
/// These tests pin that ordering/fallback logic without touching Supabase.
void main() {
  group('AccountManagementService.orchestrateDeletion', () {
    test('server success => serverCascade, no client fallback', () async {
      var clientCalled = false;

      final outcome = await AccountManagementService.orchestrateDeletion(
        serverDelete: () async => true,
        clientFallbackCascade: () async => clientCalled = true,
      );

      expect(outcome, AccountDeletionOutcome.serverCascade);
      expect(
        clientCalled,
        isFalse,
        reason: 'client cascade must NOT run when the server handled deletion',
      );
    });

    test('server not deployed (false) => runs client fallback', () async {
      var clientCalled = false;

      final outcome = await AccountManagementService.orchestrateDeletion(
        serverDelete: () async => false,
        clientFallbackCascade: () async => clientCalled = true,
      );

      expect(outcome, AccountDeletionOutcome.clientFallback);
      expect(clientCalled, isTrue);
    });

    test('server error propagates and does NOT run client fallback', () async {
      var clientCalled = false;

      await expectLater(
        AccountManagementService.orchestrateDeletion(
          serverDelete: () async => throw Exception('boom'),
          clientFallbackCascade: () async => clientCalled = true,
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        clientCalled,
        isFalse,
        reason: 'a genuine server error must surface, not silently wipe data',
      );
    });

    test('server is awaited before client fallback (ordering)', () async {
      final order = <String>[];

      await AccountManagementService.orchestrateDeletion(
        serverDelete: () async {
          order.add('server');
          return false;
        },
        clientFallbackCascade: () async => order.add('client'),
      );

      expect(order, ['server', 'client']);
    });
  });

  group('AccountManagementService.cascadeTables', () {
    // Pins the client-side cascade's actual table coverage — the real bug the
    // old stub-closure assertion missed (it checked 0 of these tables).
    test('covers exactly the expected 8 tables', () {
      expect(AccountManagementService.cascadeTables, hasLength(8));
      expect(
        AccountManagementService.cascadeTables,
        containsAll(<String>[
          'friendships',
          'challenges',
          'blocked_users',
          'scores',
          'account_state',
          'user_settings',
          'iap_receipts',
          'profiles',
        ]),
      );
    });

    test('deletes profiles LAST so FK-dependent rows are gone first', () {
      expect(AccountManagementService.cascadeTables.last, 'profiles');
      // profiles must appear exactly once and nowhere but the end.
      expect(
        AccountManagementService.cascadeTables
            .where((t) => t == 'profiles')
            .length,
        1,
      );
    });

    test('relationship/child tables come before profiles', () {
      final tables = AccountManagementService.cascadeTables;
      for (final child in ['friendships', 'challenges', 'blocked_users']) {
        expect(
          tables.indexOf(child),
          lessThan(tables.indexOf('profiles')),
          reason: '$child must be deleted before profiles',
        );
      }
    });

    test('has no duplicate tables', () {
      final tables = AccountManagementService.cascadeTables;
      expect(tables.toSet(), hasLength(tables.length));
    });
  });
}
