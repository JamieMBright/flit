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

  group('FriendsService.buildSearchPattern', () {
    test('escapes a literal % so it cannot broaden the match', () {
      expect(FriendsService.buildSearchPattern('%'), r'\%%');
      expect(FriendsService.buildSearchPattern('50%'), r'50\%%');
    });

    test('escapes a literal _ so it cannot broaden the match', () {
      expect(FriendsService.buildSearchPattern('_'), r'\_%');
      expect(FriendsService.buildSearchPattern('a_b'), r'a\_b%');
    });

    test('appends % to a plain prefix', () {
      expect(FriendsService.buildSearchPattern('plain'), 'plain%');
    });

    test('trims surrounding whitespace before building the pattern', () {
      expect(FriendsService.buildSearchPattern('  jamie  '), 'jamie%');
    });

    test('whitespace-only query returns the empty (no-query) sentinel', () {
      expect(FriendsService.buildSearchPattern(''), '');
      expect(FriendsService.buildSearchPattern('   '), '');
      expect(FriendsService.buildSearchPattern('\t\n'), '');
    });
  });

  group('FriendsService.findByFriendCode', () {
    test('returns null for an invalid code with no DB/session work', () async {
      // An obviously invalid code is rejected by FriendCode.normalize before
      // any auth/session or Supabase access, so this resolves to null even
      // though Supabase is not initialised in unit tests.
      expect(
        await FriendsService.instance.findByFriendCode('!!!!!!'),
        isNull,
      );
      expect(
        await FriendsService.instance.findByFriendCode('nope'),
        isNull,
      );
    });
  });
}
