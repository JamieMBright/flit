import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Watercolor rendering utilities for painting planes and companions.
///
/// Replaces the old sketch/pencil/crosshatch hand-drawn style with a softer,
/// more organic watercolor vector aesthetic. Each method produces layered
/// semi-transparent washes, soft edges, and subtle pigment effects that
/// complement the realistic satellite-globe backdrop.
class WatercolorStyle {
  WatercolorStyle._();

  // ---------------------------------------------------------------------------
  // Core wash effects
  // ---------------------------------------------------------------------------

  /// Paint a path with layered semi-transparent washes to simulate watercolor.
  ///
  /// Draws [layers] copies of the path with slight scale/offset jitter and
  /// reduced opacity, producing the uneven, translucent look of wet pigment
  /// on paper. The final solid layer sits on top for legibility.
  static void washFill(
    Canvas canvas,
    Path path,
    Color color, {
    int layers = 3,
    double opacity = 0.30,
    double spread = 1.2,
    String seed = '',
  }) {
    final rng = Random(seed.hashCode);

    // Under-layers: slightly offset, slightly scaled, translucent.
    for (var i = 0; i < layers; i++) {
      final dx = (rng.nextDouble() - 0.5) * spread;
      final dy = (rng.nextDouble() - 0.5) * spread;
      final layerOpacity = opacity * (1.0 - i * 0.08);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(layerOpacity.clamp(0.05, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
      canvas.restore();
    }

    // Top solid-ish layer — the "dry" pigment that settles.
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.85));
  }

  /// Draw a wet-edge effect along a path — simulates paint pooling at
  /// boundaries where watercolor darkens along the edge of a stroke.
  static void wetEdge(
    Canvas canvas,
    Path path,
    Color color, {
    double width = 1.8,
    double blur = 2.5,
    double opacity = 0.30,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = _darken(color, 0.35).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Subtle pigment granulation: scattered semi-transparent dots inside
  /// [clipPath] that simulate the grainy texture of watercolor pigment.
  static void granulate(
    Canvas canvas,
    Path clipPath,
    Color color, {
    int count = 20,
    double maxRadius = 1.5,
    double opacity = 0.06,
    String seed = '',
  }) {
    final rng = Random(seed.hashCode ^ 0xCAFE);
    final bounds = clipPath.getBounds();
    if (bounds.isEmpty) return;

    canvas.save();
    canvas.clipPath(clipPath);
    for (var i = 0; i < count; i++) {
      final x = bounds.left + rng.nextDouble() * bounds.width;
      final y = bounds.top + rng.nextDouble() * bounds.height;
      final r = rng.nextDouble() * maxRadius + 0.3;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = _darken(color, 0.2).withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
      );
    }
    canvas.restore();
  }

  /// Soft shadow beneath a shape — blurred, offset, low-opacity.
  static void softShadow(
    Canvas canvas,
    Path path, {
    Offset offset = const Offset(0.5, 1.5),
    double blur = 4.0,
    double opacity = 0.12,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.restore();
  }

  /// Wash texture: a subtle gradient overlay inside a clipped area,
  /// simulating colour variation across a watercolor wash.
  static void washTexture(
    Canvas canvas,
    Path clipPath,
    Color color, {
    double opacity = 0.08,
  }) {
    final bounds = clipPath.getBounds();
    if (bounds.isEmpty) return;

    canvas.save();
    canvas.clipPath(clipPath);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _lighten(color, 0.15).withOpacity(opacity),
        _darken(color, 0.15).withOpacity(opacity * 0.5),
      ],
    );
    canvas.drawRect(
      bounds,
      Paint()..shader = gradient.createShader(bounds),
    );
    canvas.restore();
  }

  /// Colour bleed: draw a soft blurred halo around a path in a tinted colour.
  /// Simulates paint bleeding beyond its intended boundary.
  static void colorBleed(
    Canvas canvas,
    Path path,
    Color color, {
    double blur = 3.0,
    double opacity = 0.10,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Draw a watercolor-style stroke — a slightly irregular, soft-edged stroke
  /// that varies in width along its length.
  static void watercolorStroke(
    Canvas canvas,
    Path path,
    Color color, {
    double width = 1.5,
    double opacity = 0.55,
    String seed = '',
  }) {
    // Soft wide under-stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.8),
    );
    // Crisp centre line.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Aura glow — soft radial glow around a point, useful for magical
  /// effects (phoenix fire, dragon breath, etc.).
  static void auraGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double opacity = 0.15,
    double blur = 8.0,
  }) {
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        color.withOpacity(opacity),
        color.withOpacity(0),
      ],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient,
    );
  }

  // ---------------------------------------------------------------------------
  // Colour helpers (shared)
  // ---------------------------------------------------------------------------

  static Color darken(Color c, double amount) => _darken(c, amount);
  static Color lighten(Color c, double amount) => _lighten(c, amount);

  static Color _darken(Color c, double amount) {
    final f = (1.0 - amount).clamp(0.0, 1.0);
    return Color.fromARGB(
      c.alpha,
      (c.red * f).round(),
      (c.green * f).round(),
      (c.blue * f).round(),
    );
  }

  static Color _lighten(Color c, double amount) {
    final f = amount.clamp(0.0, 1.0);
    return Color.fromARGB(
      c.alpha,
      (c.red + (255 - c.red) * f * 0.4).round().clamp(0, 255),
      (c.green + (255 - c.green) * f * 0.4).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * f * 0.4).round().clamp(0, 255),
    );
  }
}
