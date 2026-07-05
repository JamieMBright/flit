import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';
import '../../game/map/country_data.dart';

/// Post-round reveal map shared by all game modes: an equirectangular
/// world map with the answer (gold star), optional clue anchors
/// (accent-ringed dots), and the player's wrong guesses (red dots with
/// connector lines back to the answer).
///
/// Pinch-zoomable and pannable; marker and line sizes counter-scale with
/// zoom so they keep a constant on-screen size. Includes the legend and
/// gesture hint so every mode presents results identically.
class RevealMap extends StatefulWidget {
  const RevealMap({
    super.key,
    required this.targetLngLat,
    this.clueLngLats = const [],
    this.guessLngLats = const [],
    this.showLegend = true,
  });

  /// The answer location as (lng, lat) degrees.
  final Vector2 targetLngLat;

  /// Original clue anchor locations, if the mode has them.
  final List<Vector2> clueLngLats;

  /// Wrong-guess locations.
  final List<Vector2> guessLngLats;

  final bool showLegend;

  @override
  State<RevealMap> createState() => _RevealMapState();
}

class _RevealMapState extends State<RevealMap> {
  /// Drives pinch-zoom/pan; the current zoom feeds back into the painter
  /// so markers keep a constant on-screen size.
  final TransformationController _controller = TransformationController();
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    final zoom = _controller.value.getMaxScaleOnAxis();
    if ((zoom - _zoom).abs() > 0.01) setState(() => _zoom = zoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: FlitColors.backgroundMid,
            child: AspectRatio(
              aspectRatio: 2,
              child: InteractiveViewer(
                transformationController: _controller,
                maxScale: 12,
                child: CustomPaint(
                  painter: _RevealMapPainter(
                    targetLngLat: widget.targetLngLat,
                    clueLngLats: widget.clueLngLats,
                    guessLngLats: widget.guessLngLats,
                    zoom: _zoom,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: FlitColors.gold, size: 13),
              const SizedBox(width: 3),
              const Text(
                'answer',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
              ),
              if (widget.clueLngLats.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.circle_outlined,
                  color: FlitColors.accent,
                  size: 11,
                ),
                const SizedBox(width: 3),
                const Text(
                  'clues',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
                ),
              ],
              if (widget.guessLngLats.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.circle, color: FlitColors.error, size: 11),
                const SizedBox(width: 3),
                const Text(
                  'your guesses',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'pinch to zoom · drag to pan',
            style: TextStyle(
              color: FlitColors.textMuted.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

/// Equirectangular world map painter behind [RevealMap]. [zoom] is the
/// InteractiveViewer's current scale; markers and line widths are divided
/// by it so they keep a constant on-screen size while the map zooms.
class _RevealMapPainter extends CustomPainter {
  _RevealMapPainter({
    required this.targetLngLat,
    required this.clueLngLats,
    required this.guessLngLats,
    this.zoom = 1,
  });

  final Vector2 targetLngLat;
  final List<Vector2> clueLngLats;
  final List<Vector2> guessLngLats;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final z = zoom.clamp(1.0, 100.0);
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.45);
    final borderPaint = Paint()
      ..color = FlitColors.border.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 / z;

    Offset project(double lng, double lat) => Offset(
          (lng + 180) / 360 * size.width,
          (90 - lat) / 180 * size.height,
        );

    for (final country in CountryData.countries) {
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
        canvas.drawPath(path, landPaint);
        canvas.drawPath(path, borderPaint);
      }
    }

    final target = project(targetLngLat.x, targetLngLat.y);

    // Clue anchors: accent-ringed dots with a faint line to the answer.
    for (final clue in clueLngLats) {
      final pos = project(clue.x, clue.y);
      canvas.drawLine(
        pos,
        target,
        Paint()
          ..color = FlitColors.textSecondary.withOpacity(0.3)
          ..strokeWidth = 0.8 / z,
      );
      canvas.drawCircle(pos, 3 / z, Paint()..color = FlitColors.backgroundDark);
      canvas.drawCircle(
        pos,
        3 / z,
        Paint()
          ..color = FlitColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / z,
      );
    }

    // Guess dots + connector lines toward the answer.
    for (final g in guessLngLats) {
      final pos = project(g.x, g.y);
      canvas.drawLine(
        pos,
        target,
        Paint()
          ..color = FlitColors.error.withOpacity(0.5)
          ..strokeWidth = 1 / z,
      );
      canvas.drawCircle(pos, 3.5 / z, Paint()..color = FlitColors.error);
    }

    _drawStar(canvas, target, 7 / z, Paint()..color = FlitColors.gold);
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RevealMapPainter old) =>
      targetLngLat != old.targetLngLat ||
      guessLngLats.length != old.guessLngLats.length ||
      clueLngLats.length != old.clueLngLats.length ||
      zoom != old.zoom;
}
