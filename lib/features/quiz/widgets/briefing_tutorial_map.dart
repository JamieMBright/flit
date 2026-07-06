import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../../core/theme/flit_colors.dart';
import '../../../game/map/country_data.dart';

/// One country taught on the briefing map — a real region country the pilot
/// learns to recognise and tap.
class BriefingCountry {
  const BriefingCountry({
    required this.code,
    required this.name,
    required this.blurb,
  });

  /// ISO country code (highlighted + hit-tested on the map).
  final String code;

  /// Display name, e.g. 'Egypt'.
  final String name;

  /// Short direction/landmark hint the coach uses, e.g. 'west of Egypt'.
  final String blurb;
}

/// A North-Africa / Middle-East teaching map for Training Briefing: real
/// country polygons from [CountryData], framed on Egypt and its neighbours,
/// with tap hit-testing so the pilot can answer a briefing by tapping the
/// named country on the map.
///
/// Purely a teaching surface — it renders the region's countries, marks the
/// one being asked about, the ones already found (green), and the most recent
/// wrong tap (red), and reports taps back through [onTapCountry]. It reuses
/// the same equirectangular projection idea as the recon teaching map so the
/// two guided lessons look and feel like one system.
class BriefingTutorialMap extends StatelessWidget {
  const BriefingTutorialMap({
    super.key,
    required this.region,
    this.promptCode,
    this.foundCodes = const {},
    this.wrongCode,
    this.showLabels = true,
    this.onTapCountry,
    this.aspectRatio = 1.55,
    this.labelFontFamily,
  });

  /// The countries in the lesson (the only tappable / highlighted set).
  final List<BriefingCountry> region;

  /// The country currently being asked about — pulsed gold as a hint. Null
  /// when the pilot answers unaided.
  final String? promptCode;

  /// Countries the pilot has already correctly tapped (drawn green).
  final Set<String> foundCodes;

  /// The most recent wrong tap, briefly drawn red for gentle correction.
  final String? wrongCode;

  /// When true, each region country is labelled with its name.
  final bool showLabels;

  /// Called with the tapped region country's code, or null for empty sea /
  /// out-of-region taps (which the lesson simply ignores).
  final void Function(String? code)? onTapCountry;

  final double aspectRatio;

  /// Font family for the canvas labels (golden tests pass a loaded family so
  /// the captured PNG shows real glyphs instead of tofu; the app leaves it
  /// null to use the ambient default).
  final String? labelFontFamily;

  /// Geographic window framing Egypt + Libya, Sudan, Saudi Arabia and Jordan
  /// (minLng, minLat, maxLng, maxLat).
  static const List<double> bounds = [8.0, 8.0, 56.0, 34.0];

  static double get _cosLat =>
      math.cos(((bounds[1] + bounds[3]) / 2) * math.pi / 180);

  /// Forward projection helper shared by the painter and hit-tester.
  static ({double scale, double offX, double offY}) _fit(Size size) {
    final gw = (bounds[2] - bounds[0]) * _cosLat;
    final gh = bounds[3] - bounds[1];
    final scale = math.min(size.width / gw, size.height / gh);
    return (
      scale: scale,
      offX: (size.width - gw * scale) / 2,
      offY: (size.height - gh * scale) / 2,
    );
  }

  /// Local pixel offset of a geographic point within a map of [size] — the
  /// forward projection, exposed for widget tests that tap a country by its
  /// capital coordinate.
  @visibleForTesting
  static Offset projectLocal(Size size, double lng, double lat) {
    final fit = _fit(size);
    return Offset(
      fit.offX + (lng - bounds[0]) * _cosLat * fit.scale,
      fit.offY + (bounds[3] - lat) * fit.scale,
    );
  }

  /// Which region country (if any) contains the tapped local point.
  String? _hitTest(Offset local, Size size) {
    final fit = _fit(size);
    // Inverse projection: local pixel -> (lng, lat).
    final lng = (local.dx - fit.offX) / (_cosLat * fit.scale) + bounds[0];
    final lat = bounds[3] - (local.dy - fit.offY) / fit.scale;
    for (final rc in region) {
      final country = CountryData.getCountry(rc.code);
      if (country == null) continue;
      for (final poly in country.polygons) {
        if (_pointInPolygon(lng, lat, poly)) return rc.code;
      }
    }
    return null;
  }

  static bool _pointInPolygon(double lng, double lat, List<Vector2> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].x, yi = poly[i].y;
      final xj = poly[j].x, yj = poly[j].y;
      final intersects = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: FlitColors.backgroundMid,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onTapCountry == null
                    ? null
                    : (details) =>
                        onTapCountry!(_hitTest(details.localPosition, size)),
                child: CustomPaint(
                  size: size,
                  painter: _BriefingMapPainter(
                    region: region,
                    promptCode: promptCode,
                    foundCodes: foundCodes,
                    wrongCode: wrongCode,
                    showLabels: showLabels,
                    labelFontFamily: labelFontFamily,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BriefingMapPainter extends CustomPainter {
  _BriefingMapPainter({
    required this.region,
    required this.promptCode,
    required this.foundCodes,
    required this.wrongCode,
    required this.showLabels,
    this.labelFontFamily,
  });

  final List<BriefingCountry> region;
  final String? promptCode;
  final Set<String> foundCodes;
  final String? wrongCode;
  final bool showLabels;
  final String? labelFontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    const bounds = BriefingTutorialMap.bounds;
    final minLng = bounds[0];
    final maxLat = bounds[3];
    final cosLat = BriefingTutorialMap._cosLat;
    final fit = BriefingTutorialMap._fit(size);

    Offset project(double lng, double lat) => Offset(
          fit.offX + (lng - minLng) * cosLat * fit.scale,
          fit.offY + (maxLat - lat) * fit.scale,
        );

    // Keep polygons that spill past the framed window inside the card.
    canvas.clipRect(Offset.zero & size);

    final landPaint = Paint()
      ..color = FlitColors.landMass.withValues(alpha: 0.28);
    final borderPaint = Paint()
      ..color = FlitColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Highlight colour per region country: found (green), wrong (red),
    // prompt (gold), otherwise a neutral accent so it reads as "in play".
    Color? highlightFor(String code) {
      if (foundCodes.contains(code)) {
        return FlitColors.success.withValues(alpha: 0.5);
      }
      if (code == wrongCode) return FlitColors.error.withValues(alpha: 0.5);
      if (code == promptCode) return FlitColors.gold.withValues(alpha: 0.5);
      return FlitColors.accent.withValues(alpha: 0.22);
    }

    final regionCodes = {for (final rc in region) rc.code};

    // Draw every country as faint context, region countries with their state
    // highlight.
    for (final country in CountryData.countries) {
      final fill = regionCodes.contains(country.code)
          ? highlightFor(country.code)
          : null;
      final strong = fill != null;
      for (final poly in country.polygons) {
        if (poly.length < 3) continue;
        final path = Path();
        for (var i = 0; i < poly.length; i++) {
          final pt = project(poly[i].x, poly[i].y);
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(
            path, fill == null ? landPaint : (Paint()..color = fill));
        canvas.drawPath(
          path,
          strong
              ? (Paint()
                ..color = FlitColors.textPrimary.withValues(alpha: 0.55)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.1)
              : borderPaint,
        );
      }
    }

    // Labels (+ prompt pulse) drawn at each region country's capital.
    for (final rc in region) {
      final cap = CountryData.getCapital(rc.code);
      if (cap == null) continue;
      final pos = project(cap.location.x, cap.location.y);
      final isPrompt = rc.code == promptCode;
      final isFound = foundCodes.contains(rc.code);
      final isWrong = rc.code == wrongCode;

      // A ring on the country being asked about draws the eye to it.
      if (isPrompt) {
        canvas.drawCircle(
          pos,
          13,
          Paint()
            ..color = FlitColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
      final dotColor = isFound
          ? FlitColors.success
          : isWrong
              ? FlitColors.error
              : isPrompt
                  ? FlitColors.gold
                  : FlitColors.textPrimary;
      canvas.drawCircle(pos, 4, Paint()..color = FlitColors.backgroundDark);
      canvas.drawCircle(
        pos,
        4,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill,
      );

      if (showLabels || isPrompt || isFound || isWrong) {
        _drawLabel(canvas, size, pos, rc.name.toUpperCase(), dotColor,
            bold: isPrompt || isFound);
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset anchor,
    String text,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: labelFontFamily,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          letterSpacing: 0.4,
          shadows: const [
            Shadow(color: Color(0xE60B0F14), blurRadius: 3),
            Shadow(color: Color(0xE60B0F14), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Place the label just above the marker, clamped inside the card.
    var dx = anchor.dx - tp.width / 2;
    var dy = anchor.dy - tp.height - 8;
    dx = dx.clamp(2.0, size.width - tp.width - 2);
    dy = dy.clamp(2.0, size.height - tp.height - 2);
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_BriefingMapPainter old) =>
      old.promptCode != promptCode ||
      old.wrongCode != wrongCode ||
      old.showLabels != showLabels ||
      old.foundCodes.length != foundCodes.length;
}
