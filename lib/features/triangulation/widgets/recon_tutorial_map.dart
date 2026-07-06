import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../../core/theme/flit_colors.dart';
import '../../../game/map/country_data.dart';

/// One neighbour marker plotted on the recon teaching map: a known country
/// whose direction from the hidden target is the clue.
class ReconMapMarker {
  const ReconMapMarker({
    required this.code,
    required this.lngLat,
    required this.label,
    this.isWrong = false,
  });

  /// ISO country code (highlighted on the map).
  final String code;

  /// Capital coordinate as (lng, lat) degrees — the marker/label anchor.
  final Vector2 lngLat;

  /// Short label drawn beside the marker, e.g. 'Spain · SW'.
  final String label;

  /// A wrong-guess marker (Andorra) — drawn in red instead of accent.
  final bool isWrong;
}

/// A France-centred teaching map for Training Recon: real country polygons
/// pulled from [CountryData], with France highlighted as the hidden target
/// and each revealed neighbour tied back to it by a bearing line. Reuses the
/// same equirectangular polygon data as [RevealMap] but frames France and its
/// neighbours instead of the whole world, so the clue relationships read at a
/// glance. Purely presentational — no gestures, sized by its parent.
class ReconTutorialMap extends StatelessWidget {
  const ReconTutorialMap({
    super.key,
    required this.targetCode,
    required this.targetLngLat,
    required this.markers,
    this.showTargetName = false,
    this.aspectRatio = 1.15,
    this.labelFontFamily,
  });

  /// The hidden target country (France) — highlighted gold.
  final String targetCode;

  /// Target capital (Paris) as (lng, lat) — the star + line origin.
  final Vector2 targetLngLat;

  /// Neighbour clue markers revealed so far (plus an optional wrong guess).
  final List<ReconMapMarker> markers;

  /// When true the star is labelled 'FRANCE' (the reveal); otherwise '?'.
  final bool showTargetName;

  final double aspectRatio;

  /// Font family for the canvas labels. The app leaves this null (labels use
  /// the ambient default font); golden tests pass a loaded family so the
  /// captured PNG shows real glyphs instead of tofu.
  final String? labelFontFamily;

  /// Geographic window framing France + its neighbours (minLng, minLat,
  /// maxLng, maxLat). Wide enough to show the UK, Spain, Germany and the
  /// Algerian coast around France.
  static const _bounds = [-11.0, 33.0, 17.0, 56.0];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: FlitColors.backgroundMid,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: CustomPaint(
            painter: _ReconMapPainter(
              targetCode: targetCode,
              targetLngLat: targetLngLat,
              markers: markers,
              showTargetName: showTargetName,
              labelFontFamily: labelFontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconMapPainter extends CustomPainter {
  _ReconMapPainter({
    required this.targetCode,
    required this.targetLngLat,
    required this.markers,
    required this.showTargetName,
    this.labelFontFamily,
  });

  final String targetCode;
  final Vector2 targetLngLat;
  final List<ReconMapMarker> markers;
  final bool showTargetName;
  final String? labelFontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    const bounds = ReconTutorialMap._bounds;
    final minLng = bounds[0], minLat = bounds[1];
    final maxLng = bounds[2], maxLat = bounds[3];
    final midLatRad = ((minLat + maxLat) / 2) * math.pi / 180;
    final cosLat = math.cos(midLatRad);

    final gw = (maxLng - minLng) * cosLat;
    final gh = maxLat - minLat;
    final scale = math.min(size.width / gw, size.height / gh);
    final offX = (size.width - gw * scale) / 2;
    final offY = (size.height - gh * scale) / 2;

    Offset project(double lng, double lat) => Offset(
          offX + (lng - minLng) * cosLat * scale,
          offY + (maxLat - lat) * scale,
        );

    // Clip to the framed window so full polygons (e.g. Algeria's vast south)
    // don't spill past the map edges.
    canvas.clipRect(Offset.zero & size);

    final landPaint = Paint()
      ..color = FlitColors.landMass.withValues(alpha: 0.28);
    final borderPaint = Paint()
      ..color = FlitColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Highlight fills: target (gold) and each revealed neighbour (accent),
    // wrong-guess country (red).
    final highlight = <String, Color>{
      targetCode: FlitColors.gold.withValues(alpha: 0.5),
      for (final m in markers)
        m.code: (m.isWrong ? FlitColors.error : FlitColors.accent)
            .withValues(alpha: 0.42),
    };

    // Draw every country: faint context fill, or its highlight colour when
    // it is the target or a revealed neighbour.
    for (final country in CountryData.countries) {
      final fill = highlight[country.code];
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
        canvas.drawPath(path, borderPaint);
      }
    }

    final target = project(targetLngLat.x, targetLngLat.y);

    // Bearing lines from the target to each clue marker.
    for (final m in markers) {
      final pos = project(m.lngLat.x, m.lngLat.y);
      final color = m.isWrong ? FlitColors.error : FlitColors.accent;
      canvas.drawLine(
        target,
        pos,
        Paint()
          ..color = color.withValues(alpha: m.isWrong ? 0.8 : 0.7)
          ..strokeWidth = m.isWrong ? 2.0 : 1.6
          ..strokeCap = StrokeCap.round,
      );
      // Marker dot.
      canvas.drawCircle(pos, 4.5, Paint()..color = FlitColors.backgroundDark);
      canvas.drawCircle(
        pos,
        4.5,
        Paint()
          ..color = color
          ..style = m.isWrong ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      // Radiate the label outward from the target so labels fan apart
      // instead of piling up around Paris.
      var out = pos - target;
      if (out.distance < 1) out = const Offset(0, -1);
      out = out / out.distance;
      _drawLabel(canvas, size, pos, m.label, color, outward: out);
    }

    // Target star (gold) + its label sitting just below, over France's body.
    _drawStar(canvas, target, 8, Paint()..color = FlitColors.gold);
    _drawLabel(
      canvas,
      size,
      target,
      showTargetName ? 'FRANCE' : 'TARGET ?',
      FlitColors.gold,
      outward: const Offset(0, 1),
      bold: true,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset anchor,
    String text,
    Color color, {
    required Offset outward,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: labelFontFamily,
          fontSize: 11.5,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          letterSpacing: bold ? 1.0 : 0.2,
          shadows: const [
            Shadow(color: Color(0xE60B0F14), blurRadius: 3),
            Shadow(color: Color(0xE60B0F14), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Anchor the label box on the outward side of the marker: push its
    // centre out along [outward], then place the box so the marker sits at
    // its inward edge.
    const gap = 8.0;
    final cx = anchor.dx + outward.dx * (tp.width / 2 + gap);
    final cy = anchor.dy + outward.dy * (tp.height / 2 + gap);
    var dx = cx - tp.width / 2;
    var dy = cy - tp.height / 2;
    dx = dx.clamp(2.0, size.width - tp.width - 2);
    dy = dy.clamp(2.0, size.height - tp.height - 2);
    tp.paint(canvas, Offset(dx, dy));
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pt =
          center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    // Dark outline so the star reads over any fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = FlitColors.backgroundDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ReconMapPainter old) =>
      old.markers.length != markers.length ||
      old.showTargetName != showTargetName;
}
