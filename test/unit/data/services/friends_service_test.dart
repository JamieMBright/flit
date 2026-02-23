import 'package:flit/data/services/friends_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FriendsService invite expiry helper', () {
    test('returns false for null/empty/malformed created_at', () {
      final service = FriendsService.instance;
      expect(service.isInviteExpiredForTest(null), isFalse);
      expect(service.isInviteExpiredForTest(''), isFalse);
      expect(service.isInviteExpiredForTest('not-a-date'), isFalse);
    });

    test('returns false for recent invites', () {
      final service = FriendsService.instance;
      final recent = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 2, hours: 23))
          .toIso8601String();
      expect(service.isInviteExpiredForTest(recent), isFalse);
    });

    test('returns true for invites older than 3 days', () {
      final service = FriendsService.instance;
      final oldInvite = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 3, minutes: 1))
          .toIso8601String();
      expect(service.isInviteExpiredForTest(oldInvite), isTrue);
    });
  });
}
