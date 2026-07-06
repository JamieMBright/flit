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
}
