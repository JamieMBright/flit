import 'package:flag/flag.dart';
import 'package:flit/core/widgets/country_flag.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage guard: the special territories that used to render as bare
/// regional-indicator letters (Northern Cyprus XC, Somaliland XS, Kosovo XK)
/// must resolve to a real vector flag inside [CountryFlag] and never fall
/// through to the last-resort emoji `Text` branch.
void main() {
  group('CountryFlag resolves special territories to real flags', () {
    test('XC (Northern Cyprus) resolves via the bundled-SVG path', () {
      expect(CountryFlag.bundledCodes.contains('XC'), isTrue);
    });

    test('XS (Somaliland) resolves via the bundled-SVG path', () {
      expect(CountryFlag.bundledCodes.contains('XS'), isTrue);
    });

    test('XK (Kosovo) resolves via the flag package, not emoji', () {
      // Kosovo is not a bundled override, so it must be served by the
      // `flag` package to avoid the bare-letters fallback.
      expect(CountryFlag.bundledCodes.contains('XK'), isFalse);
      expect(Flag.flagsCode.contains('xk'), isTrue);
    });

    test('EH (Western Sahara) resolves via the flag package', () {
      expect(Flag.flagsCode.contains('eh'), isTrue);
    });

    test('none of XC/XS/XK hit the bare-emoji fallback branch', () {
      // The emoji branch is only reached when a code is neither a bundled
      // override nor known to the `flag` package. Verify every special code
      // is covered by one of the two real-flag paths.
      for (final code in ['XC', 'XS', 'XK']) {
        final bundled = CountryFlag.bundledCodes.contains(code);
        final packaged = Flag.flagsCode.contains(code.toLowerCase());
        expect(
          bundled || packaged,
          isTrue,
          reason: '$code must resolve to a real flag, not emoji letters',
        );
      }
    });
  });
}
