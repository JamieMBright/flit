import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../map/region.dart';

/// Renders a flat satellite map for regional game modes (US States, Ireland
/// Counties, British Counties, Canadian Provinces).
///
/// Unlike the globe renderer, this draws a static map with an equirectangular
/// projection where the plane sprite moves across the screen instead of the
/// world scrolling under a fixed plane.
///
/// The renderer draws:
/// 1. A dark background (the satellite texture comes from OSM tiles behind)
/// 2. Regional boundary outlines
/// 3. Optional labels for regions at higher zoom
class FlatMapRenderer extends Component with HasGameRef<FlitGame> {
  FlatMapRenderer({required this.region});

  final GameRegion region;

  /// Cached boundary data for the region.
  List<RegionalArea>? _areas;

  /// Map bounds [minLng, minLat, maxLng, maxLat].
  late final List<double> _bounds;

  /// Padding fraction around the region bounds.
  static const double _padding = 0.08;

  @override
  void onMount() {
    super.onMount();
    _bounds = region.bounds;
    _areas = RegionalData.getAreas(region);
  }

  /// Convert lng/lat to screen position for the flat map projection.
  ///
  /// Returns screen coordinates where (0,0) is top-left.
  /// Returns (-9999, -9999) for off-screen points.
  Vector2 worldToScreen(Vector2 lngLat, double screenW, double screenH) {
    final minLng = _bounds[0];
    final minLat = _bounds[1];
    final maxLng = _bounds[2];
    final maxLat = _bounds[3];

    // Add padding
    final padLng = (maxLng - minLng) * _padding;
    final padLat = (maxLat - minLat) * _padding;
    final bMinLng = minLng - padLng;
    final bMaxLng = maxLng + padLng;
    final bMinLat = minLat - padLat;
    final bMaxLat = maxLat + padLat;

    // Equirectangular: linear mapping of lng → x, lat → y
    final x = (lngLat.x - bMinLng) / (bMaxLng - bMinLng) * screenW;
    final y = (1.0 - (lngLat.y - bMinLat) / (bMaxLat - bMinLat)) * screenH;

    if (x < -100 || x > screenW + 100 || y < -100 || y > screenH + 100) {
      return Vector2(-9999, -9999);
    }
    return Vector2(x, y);
  }

  /// Convert screen position back to lng/lat.
  Vector2 screenToWorld(Vector2 screenPos, double screenW, double screenH) {
    final minLng = _bounds[0];
    final minLat = _bounds[1];
    final maxLng = _bounds[2];
    final maxLat = _bounds[3];

    final padLng = (maxLng - minLng) * _padding;
    final padLat = (maxLat - minLat) * _padding;
    final bMinLng = minLng - padLng;
    final bMaxLng = maxLng + padLng;
    final bMinLat = minLat - padLat;
    final bMaxLat = maxLat + padLat;

    final lng = bMinLng + (screenPos.x / screenW) * (bMaxLng - bMinLng);
    final lat = bMinLat + (1.0 - screenPos.y / screenH) * (bMaxLat - bMinLat);
    return Vector2(lng, lat);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final screenW = gameRef.size.x;
    final screenH = gameRef.size.y;
    final areas = _areas;
    if (areas == null || areas.isEmpty) return;

    // The OSM tile satellite map sits behind this layer. We only draw
    // the boundary lines and labels on top.

    _renderBoundaries(canvas, areas, screenW, screenH);
    _renderLabels(canvas, areas, screenW, screenH);
    _renderActiveHighlight(canvas, areas, screenW, screenH);
  }

  // ---------------------------------------------------------------------------
  // Region boundary outlines
  // ---------------------------------------------------------------------------

  void _renderBoundaries(
    Canvas canvas,
    List<RegionalArea> areas,
    double screenW,
    double screenH,
  ) {
    final borderPaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final area in areas) {
      if (area.points.length < 3) continue;

      final path = ui.Path();
      var started = false;

      for (var i = 0; i < area.points.length; i++) {
        final screenPos = worldToScreen(area.points[i], screenW, screenH);
        if (screenPos.x < -500) continue;

        if (!started) {
          path.moveTo(screenPos.x, screenPos.y);
          started = true;
        } else {
          path.lineTo(screenPos.x, screenPos.y);
        }
      }

      if (started) {
        path.close();
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Region name labels
  // ---------------------------------------------------------------------------

  static final Map<String, TextPainter> _labelCache = {};

  void _renderLabels(
    Canvas canvas,
    List<RegionalArea> areas,
    double screenW,
    double screenH,
  ) {
    for (final area in areas) {
      if (area.points.isEmpty) continue;

      // Compute centroid
      var sumX = 0.0;
      var sumY = 0.0;
      for (final pt in area.points) {
        sumX += pt.x;
        sumY += pt.y;
      }
      final centroid = Vector2(
        sumX / area.points.length,
        sumY / area.points.length,
      );

      final screenPos = worldToScreen(centroid, screenW, screenH);
      if (screenPos.x < -500) continue;

      final painter = _labelCache.putIfAbsent(area.code, () {
        return TextPainter(
          text: TextSpan(
            text: area.name,
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 8,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

      painter.paint(
        canvas,
        Offset(screenPos.x - painter.width / 2, screenPos.y - painter.height / 2),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Active region highlight (the one the plane is currently over)
  // ---------------------------------------------------------------------------

  void _renderActiveHighlight(
    Canvas canvas,
    List<RegionalArea> areas,
    double screenW,
    double screenH,
  ) {
    final activeAreaName = gameRef.currentCountryName;
    if (activeAreaName == null) return;

    RegionalArea? activeArea;
    for (final area in areas) {
      if (area.name == activeAreaName) {
        activeArea = area;
        break;
      }
    }
    if (activeArea == null) return;

    final highlightPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    var started = false;

    for (var i = 0; i < activeArea.points.length; i++) {
      final screenPos = worldToScreen(activeArea.points[i], screenW, screenH);
      if (screenPos.x < -500) continue;

      if (!started) {
        path.moveTo(screenPos.x, screenPos.y);
        started = true;
      } else {
        path.lineTo(screenPos.x, screenPos.y);
      }
    }

    if (started) {
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, highlightPaint);
    }
  }
}
