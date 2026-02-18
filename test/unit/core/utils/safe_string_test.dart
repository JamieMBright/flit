import 'package:flutter_test/flutter_test.dart';
import 'package:flit/core/utils/safe_string.dart';

void main() {
  group('SafeString.sanitize', () {
    test('strips control characters', () {
      expect(SafeString.sanitize('hello\x00world'), 'hello world');
      expect(SafeString.sanitize('tab\there'), 'tab here');
    });

    test('preserves newlines', () {
      expect(SafeString.sanitize('line1\nline2'), 'line1\nline2');
    });

    test('collapses whitespace', () {
      expect(SafeString.sanitize('too   many   spaces'), 'too many spaces');
    });

    test('trims leading and trailing whitespace', () {
      expect(SafeString.sanitize('  padded  '), 'padded');
    });

    test('truncates to maxLength', () {
      expect(SafeString.sanitize('long string', maxLength: 4), 'long');
    });
  });

  group('SafeString.sanitizeUsername', () {
    test('strips non-alphanumeric characters', () {
      expect(SafeString.sanitizeUsername('user@name!'), 'username');
    });

    test('preserves underscores and hyphens', () {
      expect(SafeString.sanitizeUsername('cool_user-1'), 'cool_user-1');
    });

    test('returns null if too short after sanitization', () {
      expect(SafeString.sanitizeUsername('@@'), isNull);
    });

    test('truncates to maxLength', () {
      expect(SafeString.sanitizeUsername('a' * 30, maxLength: 20), 'a' * 20);
    });
  });

  group('SafeString.sanitizeDisplayName', () {
    test('allows apostrophes', () {
      expect(SafeString.sanitizeDisplayName("O'Brien"), "O'Brien");
    });

    test('strips dangerous characters', () {
      expect(SafeString.sanitizeDisplayName('name<script>'), 'namescript');
    });

    test('collapses whitespace', () {
      expect(SafeString.sanitizeDisplayName('John   Doe'), 'John Doe');
    });
  });

  group('SafeString.escapeSingleQuoted', () {
    test('escapes apostrophes', () {
      expect(SafeString.escapeSingleQuoted("St. John's"), r"St. John\'s");
    });

    test('escapes backslashes', () {
      expect(SafeString.escapeSingleQuoted(r'back\slash'), r'back\\slash');
    });

    test('escapes dollar signs', () {
      expect(SafeString.escapeSingleQuoted(r'$var'), r'\$var');
    });
  });

  group('SafeString.escapeDoubleQuoted', () {
    test('escapes double quotes', () {
      expect(SafeString.escapeDoubleQuoted('say "hello"'), r'say \"hello\"');
    });

    test('escapes backslashes', () {
      expect(SafeString.escapeDoubleQuoted(r'path\to'), r'path\\to');
    });
  });

  group('SafeString.isSafeSingleQuoted', () {
    test('returns true for simple strings', () {
      expect(SafeString.isSafeSingleQuoted('hello'), isTrue);
    });

    test('returns false for strings with apostrophes', () {
      expect(SafeString.isSafeSingleQuoted("it's"), isFalse);
    });

    test('returns false for strings with backslashes', () {
      expect(SafeString.isSafeSingleQuoted(r'back\slash'), isFalse);
    });
  });

  group('SafeString.toDartLiteral', () {
    test('uses single quotes for simple strings', () {
      expect(SafeString.toDartLiteral('hello'), "'hello'");
    });

    test('uses double quotes for strings with apostrophes', () {
      expect(SafeString.toDartLiteral("St. John's"), '"St. John\'s"');
    });

    test('falls back to escaped single quotes for complex strings', () {
      final result = SafeString.toDartLiteral('He said "it\'s"');
      expect(result, contains('He said'));
      // Should be valid Dart regardless of quote style chosen.
      expect(result[0], anyOf("'", '"'));
    });
  });
}
