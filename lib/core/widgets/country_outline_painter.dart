import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Draws a country's border polygons as a flat, north-up silhouette that
/// fills the available box.
///
/// Shared by the Explore clue browser and the Triangulation compass so all
/// modes render outlines identically (see CLAUDE.md: shared rendering lives
/// at the shared layer).
class CountryOutlinePainter extends CustomPainter {
  CountryOutlinePainter(
    this.polygons, {
    required this.fillColor,
    required this.strokeColor,
    this.strokeWidth = 1.0,
    this.padding = 2.0,
  });

  /// Multi-polygon border data, each point as (lng, lat) degrees.
  final List<List<Vector2>> polygons;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty || size.isEmpty) return;

    final firstPt = polygons.first.first;
    var minX = firstPt.x;
    var maxX = firstPt.x;
    var minY = firstPt.y;
    var maxY = firstPt.y;
    for (final poly in polygons) {
      for (final p in poly) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX == 0 || rangeY == 0) return;

    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;
    final scale = math.min(drawW / rangeX, drawH / rangeY);
    final offsetX = padding + (drawW - rangeX * scale) / 2;
    final offsetY = padding + (drawH - rangeY * scale) / 2;

    final path = Path();
    for (final poly in polygons) {
      for (var i = 0; i < poly.length; i++) {
        final x = offsetX + (poly[i].x - minX) * scale;
        // Flip Y so north is up.
        final y = offsetY + (maxY - poly[i].y) * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(CountryOutlinePainter old) =>
      polygons != old.polygons ||
      fillColor != old.fillColor ||
      strokeColor != old.strokeColor ||
      strokeWidth != old.strokeWidth;
}
