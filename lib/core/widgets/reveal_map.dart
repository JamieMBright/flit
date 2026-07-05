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
/// One star marker on the reveal map — an answer/target location.
class RevealStar {
  const RevealStar(this.lngLat, {this.color = FlitColors.gold});

  final Vector2 lngLat;
  final Color color;
}

/// One dot marker, optionally tied by a connector line to a location
/// (e.g. a wrong guess pointing at its own question's answer).
class RevealDot {
  const RevealDot(this.lngLat, {this.color = FlitColors.error, this.lineTo});

  final Vector2 lngLat;
  final Color color;
  final Vector2? lineTo;
}

/// A polyline layer (e.g. the flown path in the flight modes).
class RevealPath {
  const RevealPath(this.points, {this.color = FlitColors.accent});

  final List<Vector2> points;
  final Color color;
}

/// One legend entry below the map.
class RevealLegendItem {
  const RevealLegendItem(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;
  final String label;
}

class RevealMap extends StatefulWidget {
  const RevealMap({
    super.key,
    this.targetLngLat,
    this.clueLngLats = const [],
    this.guessLngLats = const [],
    this.stars = const [],
    this.dots = const [],
    this.paths = const [],
    this.legendItems,
    this.showLegend = true,
  });

  /// The single answer location as (lng, lat) degrees — Triangulation's
  /// classic shape. [guessLngLats] connect to it. Modes with several
  /// targets use [stars]/[dots] instead.
  final Vector2? targetLngLat;

  /// Original clue anchor locations, if the mode has them.
  final List<Vector2> clueLngLats;

  /// Wrong-guess locations (connected to [targetLngLat]).
  final List<Vector2> guessLngLats;

  /// Additional star markers (multi-target modes).
  final List<RevealStar> stars;

  /// Additional dot markers with optional per-dot connector lines.
  final List<RevealDot> dots;

  /// Polyline layers, drawn beneath the markers.
  final List<RevealPath> paths;

  /// Custom legend; when null the classic answer/clues/guesses legend is
  /// derived from whichever of the simple layers are present.
  final List<RevealLegendItem>? legendItems;

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

  List<RevealLegendItem> _defaultLegend() => [
        if (widget.targetLngLat != null || widget.stars.isNotEmpty)
          const RevealLegendItem(Icons.star, FlitColors.gold, 'answer'),
        if (widget.clueLngLats.isNotEmpty)
          const RevealLegendItem(
            Icons.circle_outlined,
            FlitColors.accent,
            'clues',
          ),
        if (widget.guessLngLats.isNotEmpty || widget.dots.isNotEmpty)
          const RevealLegendItem(
            Icons.circle,
            FlitColors.error,
            'your guesses',
          ),
      ];

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
                    stars: widget.stars,
                    dots: widget.dots,
                    paths: widget.paths,
                    zoom: _zoom,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 2,
            children: [
              for (final item in widget.legendItems ?? _defaultLegend())
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: item.color, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
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
    required this.stars,
    required this.dots,
    required this.paths,
    this.zoom = 1,
  });

  final Vector2? targetLngLat;
  final List<Vector2> clueLngLats;
  final List<Vector2> guessLngLats;
  final List<RevealStar> stars;
  final List<RevealDot> dots;
  final List<RevealPath> paths;
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

    // Longitudes from a live flight can drift outside [-180, 180).
    double normLng(double lng) {
      var v = (lng + 180) % 360;
      if (v < 0) v += 360;
      return v - 180;
    }

    // Polyline layers (flight trails) beneath all markers. Segments that
    // cross the antimeridian break into a new subpath instead of drawing
    // a streak across the whole map.
    for (final path in paths) {
      if (path.points.length < 2) continue;
      final p = Path();
      double? prevLng;
      for (var i = 0; i < path.points.length; i++) {
        final lng = normLng(path.points[i].x);
        final pt = project(lng, path.points[i].y);
        if (i == 0 || (lng - prevLng!).abs() > 180) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
        prevLng = lng;
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = path.color.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / z
          ..strokeCap = StrokeCap.round,
      );
      // Take-off dot so the trail's direction reads at a glance.
      final start = project(normLng(path.points.first.x), path.points.first.y);
      canvas.drawCircle(start, 2.5 / z, Paint()..color = path.color);
    }

    final target =
        targetLngLat == null ? null : project(targetLngLat!.x, targetLngLat!.y);

    // Clue anchors: accent-ringed dots with a faint line to the answer.
    for (final clue in clueLngLats) {
      final pos = project(clue.x, clue.y);
      if (target != null) {
        canvas.drawLine(
          pos,
          target,
          Paint()
            ..color = FlitColors.textSecondary.withOpacity(0.3)
            ..strokeWidth = 0.8 / z,
        );
      }
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

    // Guess dots + connector lines toward the single answer.
    for (final g in guessLngLats) {
      final pos = project(g.x, g.y);
      if (target != null) {
        canvas.drawLine(
          pos,
          target,
          Paint()
            ..color = FlitColors.error.withOpacity(0.5)
            ..strokeWidth = 1 / z,
        );
      }
      canvas.drawCircle(pos, 3.5 / z, Paint()..color = FlitColors.error);
    }

    // Free-form dots (multi-target modes), each with its own connector.
    for (final dot in dots) {
      final pos = project(dot.lngLat.x, dot.lngLat.y);
      if (dot.lineTo != null) {
        canvas.drawLine(
          pos,
          project(dot.lineTo!.x, dot.lineTo!.y),
          Paint()
            ..color = dot.color.withOpacity(0.5)
            ..strokeWidth = 1 / z,
        );
      }
      canvas.drawCircle(pos, 3.5 / z, Paint()..color = dot.color);
    }

    for (final star in stars) {
      _drawStar(
        canvas,
        project(star.lngLat.x, star.lngLat.y),
        6 / z,
        Paint()..color = star.color,
      );
    }
    if (target != null) {
      _drawStar(canvas, target, 7 / z, Paint()..color = FlitColors.gold);
    }
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
      stars.length != old.stars.length ||
      dots.length != old.dots.length ||
      paths.length != old.paths.length ||
      zoom != old.zoom;
}
