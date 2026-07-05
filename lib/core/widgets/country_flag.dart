import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a country flag for any playable code.
///
/// Resolution order:
/// 1. Bundled SVG override — territories the `flag` package doesn't ship
///    (XC Northern Cyprus, XS Somaliland).
/// 2. The `flag` package (all ISO 3166-1 alpha-2 codes plus XK).
/// 3. Regional-indicator emoji as a last resort, so an unknown future
///    code still shows something rather than crashing.
///
/// Use this everywhere a flag is shown so coverage stays uniform across
/// game modes.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.code,
    this.height = 22,
    this.width = 33,
    this.borderRadius = 3,
  });

  final String code;
  final double height;
  final double width;
  final double borderRadius;

  /// Codes served from bundled assets instead of the `flag` package.
  static const Set<String> bundledCodes = {'XC', 'XS'};

  @override
  Widget build(BuildContext context) {
    final upper = code.toUpperCase();
    if (bundledCodes.contains(upper)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SvgPicture.asset(
          'assets/images/flags/${upper.toLowerCase()}.svg',
          height: height,
          width: width,
          fit: BoxFit.cover,
        ),
      );
    }
    if (upper.length == 2 && Flag.flagsCode.contains(upper.toLowerCase())) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Flag.fromString(
          upper,
          height: height,
          width: width,
          fit: BoxFit.contain,
          borderRadius: borderRadius,
        ),
      );
    }
    final emoji = upper.length == 2
        ? String.fromCharCodes(upper.codeUnits.map((c) => c + 127397))
        : upper;
    return Text(emoji, style: TextStyle(fontSize: height * 0.73));
  }
}
