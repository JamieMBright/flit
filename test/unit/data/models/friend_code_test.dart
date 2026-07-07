import 'package:flutter_test/flutter_test.dart';
import 'package:flit/data/models/friend_code.dart';

void main() {
  group('FriendCode.normalize', () {
    test('passes a clean canonical code through unchanged', () {
      expect(FriendCode.normalize('D4563D'), 'D4563D');
    });

    test('uppercases and strips spaces and dashes', () {
      expect(FriendCode.normalize('d45-63d'), 'D4563D');
      expect(FriendCode.normalize(' D4 56 3D '), 'D4563D');
      expect(FriendCode.normalize('flitD4563D'.substring(4)), 'D4563D');
    });

    test('folds ambiguous letters onto the canonical alphabet', () {
      // I/L -> 1, O -> 0, U -> V
      expect(FriendCode.normalize('ILO00U'), '11000V');
    });

    test('rejects wrong length', () {
      expect(FriendCode.normalize('D456'), isNull); // too short
      expect(FriendCode.normalize('D4563DD'), isNull); // too long
      expect(FriendCode.normalize(''), isNull);
    });

    test('rejects characters not in the alphabet after folding', () {
      // Punctuation is stripped, leaving too few chars → null.
      expect(FriendCode.normalize('!!!!!!'), isNull);
    });
  });

  group('FriendCode.isValid', () {
    test('true for valid, false for invalid', () {
      expect(FriendCode.isValid('d45-63d'), isTrue);
      expect(FriendCode.isValid('nope'), isFalse);
    });
  });

  group('FriendCode.format', () {
    test('groups a canonical code with a dash', () {
      expect(FriendCode.format('D4563D'), 'D45-63D');
    });

    test('normalises before formatting', () {
      expect(FriendCode.format('d4563d'), 'D45-63D');
    });

    test('returns empty for null', () {
      expect(FriendCode.format(null), '');
    });

    test('passes non-canonical input through unchanged', () {
      expect(FriendCode.format('weird'), 'weird');
    });
  });

  test('every alphabet character is unambiguous (no I/L/O/U)', () {
    for (final banned in ['I', 'L', 'O', 'U']) {
      expect(FriendCode.alphabet.contains(banned), isFalse,
          reason: '$banned should not be in the code alphabet');
    }
    expect(FriendCode.alphabet.length, 32);
  });
}
