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
      // Mixed separators (dashes + spaces) around a lowercase code.
      expect(FriendCode.normalize('d4-56 3d'), 'D4563D');
    });

    test('keeps letters — a flit-style prefix is NOT stripped', () {
      // normalize only removes non-alphanumerics, so letters in a `flit`
      // prefix survive, push the code past its 6-char length, and are
      // rejected. It does NOT collapse to the trailing 6 chars.
      expect(FriendCode.normalize('flitD4563D'), isNull);
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

    test('punctuation-only input is stripped and rejected by length', () {
      // All six chars are non-alphanumeric, so they're stripped, leaving an
      // empty string that fails the length check. (Folding maps every
      // surviving char — I/L/O/U included — into the alphabet, so the later
      // per-char alphabet check can never be what rejects real input; the
      // length gate is.)
      expect(FriendCode.normalize('!!!!!!'), isNull);
      // Sanity: strip embedded punctuation and a valid code still normalizes,
      // confirming the null above is the length gate, not the char stripping.
      expect(FriendCode.normalize('D45!63D'), 'D4563D');
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
