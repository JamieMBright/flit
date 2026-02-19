import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// Shared plane rendering utility used by both in-game [PlaneComponent] and
/// shop [PlanePainter]. All methods draw with (0, 0) as the plane's center,
/// nose pointing up (negative Y). Callers must translate/rotate the canvas
/// before invoking.
///
/// For in-game: pass live [bankCos]/[bankSin] from the current bank angle.
/// For shop previews: pass bankCos=1.0, bankSin=0.0 (level flight).
class PlaneRenderer {
  PlaneRenderer._(); // Non-instantiable utility class

  // ─── Helpers ────────────────────────────────────────────────────────

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
      (c.red + (255 - c.red) * f * 0.3).round(),
      (c.green + (255 - c.green) * f * 0.3).round(),
      (c.blue + (255 - c.blue) * f * 0.3).round(),
    );
  }

  static Color _primary(Map<String, int>? cs, int fallback) =>
      Color(cs?['primary'] ?? fallback);
  static Color _secondary(Map<String, int>? cs, int fallback) =>
      Color(cs?['secondary'] ?? fallback);
  static Color _detail(Map<String, int>? cs, int fallback) =>
      Color(cs?['detail'] ?? fallback);

  // ─── Dispatch ───────────────────────────────────────────────────────

  /// Render the correct plane variant. [propAngle] is only used by planes
  /// with a spinning propeller (bi-plane, triplane); pass 0.0 for static
  /// shop previews.
  static void renderPlane({
    required Canvas canvas,
    required double bankCos,
    required double bankSin,
    required double wingSpan,
    required String planeId,
    Map<String, int>? colorScheme,
    double propAngle = 0.0,
  }) {
    switch (planeId) {
      case 'plane_paper':
        _renderPaperPlane(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      case 'plane_jet':
      case 'plane_rocket':
      case 'plane_golden_jet':
        _renderJetPlane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_stealth':
        _renderStealthPlane(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      case 'plane_red_baron':
        _renderTriplane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
        );
        break;
      case 'plane_concorde_classic':
      case 'plane_diamond_concorde':
        _renderConcorde(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      case 'plane_seaplane':
        _renderSeaplane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
        );
        break;
      case 'plane_bryanair':
        _renderAirliner(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      case 'plane_air_force_one':
        _renderAirForceOne(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      case 'plane_platinum_eagle':
        _renderEagle(canvas, bankCos, bankSin, wingSpan, colorScheme);
        break;
      default:
        _renderBiPlane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
        );
        break;
    }
  }

  // ─── Bi-Plane (default, prop, spitfire, lancaster) ──────────────────

  static void _renderBiPlane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    double propAngle,
  ) {
    final primary = _primary(colorScheme, 0xFFF5F0E0);
    final secondary = _secondary(colorScheme, 0xFFC0392B);
    final detail = _detail(colorScheme, 0xFF8B4513);

    final shade = -bankSin;
    final leftWingColor = shade < 0
        ? _lighten(detail, -shade)
        : _darken(detail, shade * 0.4);
    final rightWingColor = shade > 0
        ? _lighten(detail, shade)
        : _darken(detail, -shade * 0.4);
    final bodyPaint = Paint()..color = primary;
    final accentPaint = Paint()..color = secondary;
    final highlightPaint = Paint()
      ..color = FlitColors.planeHighlight.withOpacity(0.35);
    final undersidePaint = Paint()..color = _darken(primary, 0.35);

    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;
    final bodyShift = bankSin * 1.5;

    // --- Propeller (behind everything) ---
    final propDiscPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bodyShift, -17), 8, propDiscPaint);

    final bladePaint = Paint()
      ..color = const Color(0xFF666666).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const bladeLen = 7.0;
    for (var i = 0; i < 2; i++) {
      final a = propAngle + i * pi;
      canvas.drawLine(
        Offset(bodyShift + cos(a) * bladeLen, -17 + sin(a) * bladeLen),
        Offset(bodyShift - cos(a) * bladeLen, -17 - sin(a) * bladeLen),
        bladePaint,
      );
    }

    // --- Left wing ---
    final leftSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final leftDip = wingDip;
    final leftWing = Path()
      ..moveTo(-4, -1 + leftDip * 0.2)
      ..quadraticBezierTo(
        -leftSpan * 0.5,
        0 + leftDip * 0.5,
        -leftSpan,
        2 + leftDip,
      )
      ..quadraticBezierTo(
        -leftSpan - 1,
        4 + leftDip,
        -leftSpan + 2,
        5 + leftDip,
      )
      ..lineTo(-4, 3 + leftDip * 0.2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // Left wing highlight
    if (shade <= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(-4, -0.5 + leftDip * 0.2)
          ..quadraticBezierTo(
            -leftSpan * 0.4,
            0.5 + leftDip * 0.3,
            -leftSpan * 0.8,
            2.5 + leftDip * 0.8,
          )
          ..lineTo(-leftSpan * 0.8, 3.5 + leftDip * 0.8)
          ..quadraticBezierTo(
            -leftSpan * 0.4,
            1.5 + leftDip * 0.3,
            -4,
            1 + leftDip * 0.2,
          )
          ..close(),
        highlightPaint,
      );
    }

    // --- Right wing ---
    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
    final rightDip = -wingDip;
    final rightWing = Path()
      ..moveTo(4, -1 + rightDip * 0.2)
      ..quadraticBezierTo(
        rightSpan * 0.5,
        0 + rightDip * 0.5,
        rightSpan,
        2 + rightDip,
      )
      ..quadraticBezierTo(
        rightSpan + 1,
        4 + rightDip,
        rightSpan - 2,
        5 + rightDip,
      )
      ..lineTo(4, 3 + rightDip * 0.2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // Right wing highlight
    if (shade >= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(4, -0.5 + rightDip * 0.2)
          ..quadraticBezierTo(
            rightSpan * 0.4,
            0.5 + rightDip * 0.3,
            rightSpan * 0.8,
            2.5 + rightDip * 0.8,
          )
          ..lineTo(rightSpan * 0.8, 3.5 + rightDip * 0.8)
          ..quadraticBezierTo(
            rightSpan * 0.4,
            1.5 + rightDip * 0.3,
            4,
            1 + rightDip * 0.2,
          )
          ..close(),
        highlightPaint,
      );
    }

    // --- Body group (underside + tail + fuselage roll on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Underside strip (visible when significantly banked)
    final bankAbs = bankSin.abs();
    if (bankAbs > 0.15) {
      final undersideWidth = 6.0 * bankAbs;
      final undersideX = bankSin > 0 ? -undersideWidth / 2 : undersideWidth / 2;
      final undersidePath = Path()
        ..moveTo(undersideX - undersideWidth / 2, -12)
        ..quadraticBezierTo(
          undersideX - undersideWidth / 2 - 1,
          0,
          undersideX - undersideWidth / 2,
          14,
        )
        ..lineTo(undersideX + undersideWidth / 2, 14)
        ..quadraticBezierTo(
          undersideX + undersideWidth / 2 + 1,
          0,
          undersideX + undersideWidth / 2,
          -12,
        )
        ..close();
      canvas.drawPath(undersidePath, undersidePaint);
    }

    // Tail assembly
    final tailSpan = (wingSpan * 0.38) * bankCos.abs();
    final tailPath = Path()
      ..moveTo(-tailSpan, 14 + wingDip * 0.3)
      ..quadraticBezierTo(-tailSpan - 2, 16, -tailSpan, 18)
      ..lineTo(tailSpan, 18 - wingDip * 0.3)
      ..quadraticBezierTo(tailSpan + 2, 16, tailSpan, 14 - wingDip * 0.3)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = _darken(detail, 0.1));

    // Vertical fin
    final finPath = Path()
      ..moveTo(bankSin * 2, 11)
      ..quadraticBezierTo(-4 + bankSin * 3, 15, -2 + bankSin * 2, 18)
      ..lineTo(2 + bankSin * 2, 18)
      ..quadraticBezierTo(4 + bankSin * 3, 15, bankSin * 2, 11)
      ..close();
    canvas.drawPath(finPath, accentPaint);

    // Fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(5 + bodyShift, -12, 5 + bodyShift, -2)
      ..quadraticBezierTo(4 + bodyShift, 10, 3 + bodyShift, 16)
      ..quadraticBezierTo(bodyShift, 18, -3 + bodyShift, 16)
      ..quadraticBezierTo(-4 + bodyShift, 10, -5 + bodyShift, -2)
      ..quadraticBezierTo(-5 + bodyShift, -12, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, bodyPaint);

    // Fuselage highlight
    final highlightStreak = Path()
      ..moveTo(bodyShift - 0.5, -14)
      ..quadraticBezierTo(2.5 + bodyShift, -8, 2 + bodyShift, 0)
      ..lineTo(1 + bodyShift, 10)
      ..lineTo(-1 + bodyShift, 10)
      ..lineTo(-2 + bodyShift, 0)
      ..quadraticBezierTo(-2.5 + bodyShift, -8, bodyShift - 0.5, -14)
      ..close();
    canvas.drawPath(highlightStreak, highlightPaint);

    // Accent stripe
    final stripe = Path()
      ..moveTo(-3 + bodyShift, -4)
      ..lineTo(3 + bodyShift, -4)
      ..lineTo(3 + bodyShift, 2)
      ..lineTo(-3 + bodyShift, 2)
      ..close();
    canvas.drawPath(stripe, accentPaint);

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -9), width: 5, height: 6),
      Paint()..color = const Color(0xFF4A90B8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-0.5 + bodyShift, -10),
        width: 2,
        height: 3,
      ),
      Paint()..color = const Color(0xFF8CC8E8),
    );

    // Engine / nose cone
    canvas.drawCircle(
      Offset(bodyShift, -16),
      3.0,
      Paint()..color = const Color(0xFF888888),
    );
    canvas.drawCircle(
      Offset(bodyShift, -16),
      1.5,
      Paint()..color = const Color(0xFF555555),
    );
    canvas.restore(); // End body roll transform

    // Wing tip navigation lights
    canvas.drawCircle(Offset(-leftSpan + 1, 3.5 + leftDip), 1.8, accentPaint);
    canvas.drawCircle(
      Offset(rightSpan - 1, 3.5 + rightDip),
      1.8,
      Paint()..color = FlitColors.success,
    );
  }

  // ─── Paper Plane ────────────────────────────────────────────────────

  static void _renderPaperPlane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFFE0E0E0);
    final detail = _detail(colorScheme, 0xFFCCCCCC);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;

    // Paper planes are a single folded shape — wings ARE the body.
    // Draw as unified triangular form with fold line, not separate parts.
    final leftWingColor = shade < 0 ? primary : secondary;
    final rightWingColor = shade > 0 ? primary : secondary;

    final leftSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;

    // --- Left wing (triangular, extends from nose to trailing edge) ---
    final leftWing = Path()
      ..moveTo(bodyShift, -18) // nose tip
      ..lineTo(-leftSpan, 6 + wingDip) // wing tip
      ..lineTo(-leftSpan + 4, 8 + wingDip) // trailing edge notch
      ..lineTo(bodyShift, 4) // center trailing edge
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // --- Right wing ---
    final rightWing = Path()
      ..moveTo(bodyShift, -18) // nose tip
      ..lineTo(rightSpan, 6 - wingDip) // wing tip
      ..lineTo(rightSpan - 4, 8 - wingDip) // trailing edge notch
      ..lineTo(bodyShift, 4) // center trailing edge
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Center body / keel (the folded ridge) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Folded keel — the raised center crease of a paper plane
    final keelPath = Path()
      ..moveTo(bodyShift, -18) // nose tip
      ..lineTo(bodyShift + 2.5, -8) // slight body width
      ..lineTo(bodyShift + 2, 8)
      ..lineTo(bodyShift, 12) // tail point
      ..lineTo(bodyShift - 2, 8)
      ..lineTo(bodyShift - 2.5, -8)
      ..close();
    canvas.drawPath(keelPath, Paint()..color = primary);

    // Center fold line
    canvas.drawLine(
      Offset(bodyShift, -18),
      Offset(bodyShift, 12),
      Paint()
        ..color = detail
        ..strokeWidth = 1.0,
    );

    // Nose point highlight
    canvas.drawCircle(Offset(bodyShift, -18), 2.0, Paint()..color = secondary);

    // Tail notch (the V-cut at the back of a paper plane)
    final tailNotch = Path()
      ..moveTo(bodyShift - 3, 10)
      ..lineTo(bodyShift, 6) // notch apex
      ..lineTo(bodyShift + 3, 10)
      ..close();
    canvas.drawPath(
      tailNotch,
      Paint()
        ..color = detail
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.restore(); // End body roll transform
  }

  // ─── Jet / Rocket / Golden Jet ──────────────────────────────────────

  static void _renderJetPlane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFFC0C0C0);
    final secondary = _secondary(colorScheme, 0xFF4A90B8);
    final detail = _detail(colorScheme, 0xFF808080);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Swept delta wings
    final leftWingColor = shade < 0
        ? detail
        : Color.lerp(detail, Colors.black, 0.3)!;
    final rightWingColor = shade > 0
        ? detail
        : Color.lerp(detail, Colors.black, 0.3)!;

    final leftSpan =
        dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-3 + bodyShift, 2)
      ..lineTo(-leftSpan, 8 + wingDip)
      ..lineTo(-leftSpan + 4, 10 + wingDip)
      ..lineTo(-2 + bodyShift, 6)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(3 + bodyShift, 2)
      ..lineTo(rightSpan, 8 - wingDip)
      ..lineTo(rightSpan - 4, 10 - wingDip)
      ..lineTo(2 + bodyShift, 6)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Sleek fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -18)
      ..quadraticBezierTo(3 + bodyShift, -14, 3 + bodyShift, -4)
      ..quadraticBezierTo(2.5 + bodyShift, 8, 2 + bodyShift, 15)
      ..lineTo(-2 + bodyShift, 15)
      ..quadraticBezierTo(-2.5 + bodyShift, 8, -3 + bodyShift, -4)
      ..quadraticBezierTo(-3 + bodyShift, -14, bodyShift, -18)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Canopy
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -10), width: 4, height: 7),
      Paint()..color = const Color(0xFF4A90B8),
    );

    // Jet exhaust
    if (planeId == 'plane_rocket') {
      canvas.drawCircle(
        Offset(bodyShift, 15),
        3.0,
        Paint()..color = const Color(0xFFFF6600).withOpacity(0.8),
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, 15), width: 4, height: 3),
        Paint()..color = const Color(0xFF555555),
      );
    }

    // Accent stripe
    canvas.drawLine(
      Offset(bodyShift - 1, -12),
      Offset(bodyShift - 1, 8),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.0,
    );
    canvas.restore(); // End body roll transform
  }

  // ─── Stealth Bomber ─────────────────────────────────────────────────

  static void _renderStealthPlane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFF2A2A2A);
    final secondary = _secondary(colorScheme, 0xFF1A1A1A);
    final detail = _detail(colorScheme, 0xFF444444);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    final leftWingColor = shade < 0 ? primary : secondary;
    final rightWingColor = shade > 0 ? primary : secondary;

    final leftSpan =
        dynamicWingSpan * 1.2 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final leftWing = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(
        -leftSpan * 0.4,
        -8 + wingDip * 0.3,
        -leftSpan,
        4 + wingDip,
      )
      ..lineTo(-leftSpan + 6, 8 + wingDip)
      ..quadraticBezierTo(-leftSpan * 0.3, 6 + wingDip * 0.5, bodyShift, 10)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * 1.2 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
    final rightWing = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(
        rightSpan * 0.4,
        -8 - wingDip * 0.3,
        rightSpan,
        4 - wingDip,
      )
      ..lineTo(rightSpan - 6, 8 - wingDip)
      ..quadraticBezierTo(rightSpan * 0.3, 6 - wingDip * 0.5, bodyShift, 10)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Center body section
    final centerBody = Path()
      ..moveTo(bodyShift - 4, -12)
      ..lineTo(bodyShift - 3, 8)
      ..lineTo(bodyShift + 3, 8)
      ..lineTo(bodyShift + 4, -12)
      ..close();
    canvas.drawPath(centerBody, Paint()..color = detail);

    // Sawtooth trailing edge
    final sawtoothPaint = Paint()
      ..color = secondary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final sawtoothPath = Path()
      ..moveTo(-leftSpan + 6, 8 + wingDip)
      ..lineTo(-leftSpan * 0.6, 9 + wingDip * 0.6)
      ..lineTo(-leftSpan * 0.3, 8 + wingDip * 0.4)
      ..lineTo(bodyShift - 3, 9)
      ..lineTo(bodyShift + 3, 9)
      ..lineTo(rightSpan * 0.3, 8 - wingDip * 0.4)
      ..lineTo(rightSpan * 0.6, 9 - wingDip * 0.6)
      ..lineTo(rightSpan - 6, 8 - wingDip);
    canvas.drawPath(sawtoothPath, sawtoothPaint);

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -8), width: 3, height: 4),
      Paint()..color = const Color(0xFF333333),
    );
    canvas.restore(); // End body roll transform
  }

  // ─── Triplane (Red Baron) ──────────────────────────────────────────

  static void _renderTriplane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    double propAngle,
  ) {
    final primary = _primary(colorScheme, 0xFFCC3333);
    final secondary = _secondary(colorScheme, 0xFF8B0000);
    final detail = _detail(colorScheme, 0xFF1A1A1A);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    final wingColor = shade < 0
        ? detail
        : Color.lerp(detail, Colors.black, 0.2)!;

    // --- Propeller ---
    final propDiscPaint = Paint()
      ..color = primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bodyShift, -17), 7, propDiscPaint);
    final bladePaint = Paint()
      ..color = const Color(0xFF444444).withOpacity(0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const bladeLen = 6.0;
    for (var i = 0; i < 2; i++) {
      final a = propAngle + i * pi;
      canvas.drawLine(
        Offset(bodyShift + cos(a) * bladeLen, -17 + sin(a) * bladeLen),
        Offset(bodyShift - cos(a) * bladeLen, -17 - sin(a) * bladeLen),
        bladePaint,
      );
    }

    // --- Three stacked wings ---
    // Top wing (smallest)
    final topSpan = dynamicWingSpan * 0.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -6 + wingDip * 0.3),
          width: topSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // Middle wing
    final midSpan = dynamicWingSpan * 0.85;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 0 + wingDip * 0.6),
          width: midSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // Bottom wing (largest)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 6 + wingDip),
          width: dynamicWingSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Tail
    final tailPath = Path()
      ..moveTo(-4, 12)
      ..lineTo(-4, 16)
      ..lineTo(4, 16)
      ..lineTo(4, 12)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = wingColor);

    // Fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(4 + bodyShift, -12, 4 + bodyShift, -2)
      ..quadraticBezierTo(3 + bodyShift, 10, 2 + bodyShift, 16)
      ..quadraticBezierTo(bodyShift, 17, -2 + bodyShift, 16)
      ..quadraticBezierTo(-3 + bodyShift, 10, -4 + bodyShift, -2)
      ..quadraticBezierTo(-4 + bodyShift, -12, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Struts
    final strutPaint = Paint()
      ..color = detail
      ..strokeWidth = 1.5;
    for (var x in [-dynamicWingSpan * 0.5, dynamicWingSpan * 0.5]) {
      canvas.drawLine(Offset(x, -4), Offset(x, 8 + wingDip * 0.5), strutPaint);
    }

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -8), width: 5, height: 6),
      Paint()..color = const Color(0xFF654321),
    );

    // Red Baron cross emblem
    canvas.drawLine(
      Offset(bodyShift - 3, 0),
      Offset(bodyShift + 3, 0),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(bodyShift, -3),
      Offset(bodyShift, 3),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.restore(); // End body roll transform
  }

  // ─── Concorde ──────────────────────────────────────────────────────

  static void _renderConcorde(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFF1A3A5C);
    final detail = _detail(colorScheme, 0xFFCC3333);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.5;

    // Delta wing
    final leftWingColor = shade < 0
        ? primary
        : Color.lerp(primary, Colors.grey, 0.2)!;
    final rightWingColor = shade > 0
        ? primary
        : Color.lerp(primary, Colors.grey, 0.2)!;

    final leftSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(bodyShift - 2, -16)
      ..lineTo(-leftSpan, 10 + wingDip)
      ..lineTo(bodyShift - 2, 14)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(bodyShift + 2, -16)
      ..lineTo(rightSpan, 10 - wingDip)
      ..lineTo(bodyShift + 2, 14)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -18)
      ..quadraticBezierTo(3 + bodyShift, -10, 3 + bodyShift, 0)
      ..lineTo(2 + bodyShift, 14)
      ..lineTo(-2 + bodyShift, 14)
      ..lineTo(-3 + bodyShift, 0)
      ..quadraticBezierTo(-3 + bodyShift, -10, bodyShift, -18)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Drooping nose
    canvas.drawLine(
      Offset(bodyShift, -18),
      Offset(bodyShift, -20),
      Paint()
        ..color = secondary
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Accent stripe
    canvas.drawLine(
      Offset(bodyShift, -16),
      Offset(bodyShift, 10),
      Paint()
        ..color = detail
        ..strokeWidth = 2.0,
    );

    // Cockpit windows
    for (var y in [-12.0, -10.0, -8.0]) {
      canvas.drawCircle(
        Offset(bodyShift, y),
        1.2,
        Paint()..color = const Color(0xFF4A90B8),
      );
    }
    canvas.restore(); // End body roll transform

    // Four jet engines
    for (var x in [-leftSpan * 0.4, -leftSpan * 0.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, 8 + wingDip * 0.5),
          width: 3,
          height: 4,
        ),
        Paint()..color = const Color(0xFF555555),
      );
    }
    for (var x in [rightSpan * 0.4, rightSpan * 0.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, 8 - wingDip * 0.5),
          width: 3,
          height: 4,
        ),
        Paint()..color = const Color(0xFF555555),
      );
    }
  }

  // ─── Seaplane ──────────────────────────────────────────────────────

  static void _renderSeaplane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    double propAngle,
  ) {
    final secondary = _secondary(colorScheme, 0xFF2E8B57);
    final detail = _detail(colorScheme, 0xFFF5F5F5);

    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;

    // Pontoons (below the plane)
    final pontoonPaint = Paint()..color = detail;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-dynamicWingSpan * 0.5, 12 + wingDip),
          width: 6,
          height: 16,
        ),
        const Radius.circular(3),
      ),
      pontoonPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(dynamicWingSpan * 0.5, 12 - wingDip),
          width: 6,
          height: 16,
        ),
        const Radius.circular(3),
      ),
      pontoonPaint,
    );

    // Struts connecting pontoons to wings
    final strutPaint = Paint()
      ..color = secondary
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(-dynamicWingSpan * 0.5, 4 + wingDip * 0.7),
      Offset(-dynamicWingSpan * 0.5, 8 + wingDip),
      strutPaint,
    );
    canvas.drawLine(
      Offset(dynamicWingSpan * 0.5, 4 - wingDip * 0.7),
      Offset(dynamicWingSpan * 0.5, 8 - wingDip),
      strutPaint,
    );

    // Delegate to bi-plane for the main body
    _renderBiPlane(canvas, bankCos, bankSin, wingSpan, colorScheme, propAngle);
  }

  // ─── Airliner (Bryanair, Air Force One) ─────────────────────────────

  static void _renderAirliner(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFF003580);
    final detail = _detail(colorScheme, 0xFFFFCC00);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Wide swept wings
    final leftWingColor = shade < 0
        ? detail
        : Color.lerp(detail, Colors.grey, 0.3)!;
    final rightWingColor = shade > 0
        ? detail
        : Color.lerp(detail, Colors.grey, 0.3)!;

    final leftSpan =
        dynamicWingSpan * 1.1 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-6 + bodyShift, 0)
      ..quadraticBezierTo(
        -leftSpan * 0.5,
        2 + wingDip * 0.5,
        -leftSpan,
        6 + wingDip,
      )
      ..lineTo(-leftSpan + 5, 8 + wingDip)
      ..quadraticBezierTo(-leftSpan * 0.4, 5 + wingDip * 0.5, -5 + bodyShift, 2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * 1.1 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(6 + bodyShift, 0)
      ..quadraticBezierTo(
        rightSpan * 0.5,
        2 - wingDip * 0.5,
        rightSpan,
        6 - wingDip,
      )
      ..lineTo(rightSpan - 5, 8 - wingDip)
      ..quadraticBezierTo(rightSpan * 0.4, 5 - wingDip * 0.5, 5 + bodyShift, 2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Tail section
    final tailPath = Path()
      ..moveTo(-3, 14)
      ..lineTo(-2, 16)
      ..lineTo(2, 16)
      ..lineTo(3, 14)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = detail);

    // Vertical stabilizer
    final finPath = Path()
      ..moveTo(bodyShift, 12)
      ..quadraticBezierTo(-2 + bodyShift, 14, bodyShift, 17)
      ..quadraticBezierTo(2 + bodyShift, 14, bodyShift, 12)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);

    // Wide fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -17)
      ..quadraticBezierTo(6 + bodyShift, -12, 6 + bodyShift, 0)
      ..quadraticBezierTo(5 + bodyShift, 10, 3 + bodyShift, 16)
      ..lineTo(-3 + bodyShift, 16)
      ..quadraticBezierTo(-5 + bodyShift, 10, -6 + bodyShift, 0)
      ..quadraticBezierTo(-6 + bodyShift, -12, bodyShift, -17)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Cockpit windows
    for (var y in [-13.0, -11.0, -9.0, -7.0]) {
      canvas.drawCircle(
        Offset(bodyShift + 2, y),
        0.8,
        Paint()..color = const Color(0xFF4A90B8),
      );
      canvas.drawCircle(
        Offset(bodyShift - 2, y),
        0.8,
        Paint()..color = const Color(0xFF4A90B8),
      );
    }

    // Airline stripe
    canvas.drawLine(
      Offset(bodyShift - 4, -8),
      Offset(bodyShift - 4, 12),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.restore(); // End body roll transform

    // Engines under wings
    for (var x in [-leftSpan * 0.4, -leftSpan * 0.7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 8 + wingDip * 0.6),
            width: 4,
            height: 7,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF888888),
      );
    }
    for (var x in [rightSpan * 0.4, rightSpan * 0.7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 8 - wingDip * 0.6),
            width: 4,
            height: 7,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF888888),
      );
    }
  }

  // ─── Air Force One (Presidential 747) ──────────────────────────────

  static void _renderAirForceOne(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFF1A3A5C);
    final detail = _detail(colorScheme, 0xFFD4A944);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Swept-back wings — wider and more authoritative than Bryanair
    final leftWingColor = shade < 0
        ? primary
        : Color.lerp(primary, Colors.grey, 0.15)!;
    final rightWingColor = shade > 0
        ? primary
        : Color.lerp(primary, Colors.grey, 0.15)!;

    final leftSpan =
        dynamicWingSpan * 1.15 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-5 + bodyShift, -2)
      ..quadraticBezierTo(
        -leftSpan * 0.5,
        0 + wingDip * 0.5,
        -leftSpan,
        5 + wingDip,
      )
      ..lineTo(-leftSpan + 4, 7 + wingDip)
      ..quadraticBezierTo(
        -leftSpan * 0.35,
        4 + wingDip * 0.5,
        -4 + bodyShift,
        1,
      )
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * 1.15 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(5 + bodyShift, -2)
      ..quadraticBezierTo(
        rightSpan * 0.5,
        0 - wingDip * 0.5,
        rightSpan,
        5 - wingDip,
      )
      ..lineTo(rightSpan - 4, 7 - wingDip)
      ..quadraticBezierTo(rightSpan * 0.35, 4 - wingDip * 0.5, 4 + bodyShift, 1)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Horizontal stabilizer
    final stabSpan = dynamicWingSpan * 0.35;
    final stabLeft = Path()
      ..moveTo(-2 + bodyShift, 15)
      ..lineTo(-stabSpan + bodyShift, 17 + wingDip * 0.2)
      ..lineTo(-stabSpan + 3 + bodyShift, 18 + wingDip * 0.2)
      ..lineTo(-1 + bodyShift, 16)
      ..close();
    canvas.drawPath(stabLeft, Paint()..color = primary);
    final stabRight = Path()
      ..moveTo(2 + bodyShift, 15)
      ..lineTo(stabSpan + bodyShift, 17 - wingDip * 0.2)
      ..lineTo(stabSpan - 3 + bodyShift, 18 - wingDip * 0.2)
      ..lineTo(1 + bodyShift, 16)
      ..close();
    canvas.drawPath(stabRight, Paint()..color = primary);

    // Tall vertical fin — distinctive T-tail
    final finPath = Path()
      ..moveTo(bodyShift - 1, 11)
      ..quadraticBezierTo(bodyShift - 3, 14, bodyShift - 1.5, 19)
      ..lineTo(bodyShift + 1.5, 19)
      ..quadraticBezierTo(bodyShift + 3, 14, bodyShift + 1, 11)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);
    // Gold accent on fin
    canvas.drawLine(
      Offset(bodyShift, 12),
      Offset(bodyShift, 18),
      Paint()
        ..color = detail
        ..strokeWidth = 1.2,
    );

    // Wide presidential fuselage (larger than Bryanair)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -19)
      ..quadraticBezierTo(7 + bodyShift, -14, 7 + bodyShift, 0)
      ..quadraticBezierTo(6 + bodyShift, 10, 3 + bodyShift, 18)
      ..lineTo(-3 + bodyShift, 18)
      ..quadraticBezierTo(-6 + bodyShift, 10, -7 + bodyShift, 0)
      ..quadraticBezierTo(-7 + bodyShift, -14, bodyShift, -19)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Presidential blue belly stripe (the iconic two-tone)
    final bellyStripe = Path()
      ..moveTo(bodyShift - 6, -2)
      ..quadraticBezierTo(bodyShift - 5, 8, bodyShift - 3, 16)
      ..lineTo(bodyShift + 3, 16)
      ..quadraticBezierTo(bodyShift + 5, 8, bodyShift + 6, -2)
      ..close();
    canvas.drawPath(bellyStripe, Paint()..color = secondary.withOpacity(0.4));

    // Upper blue band (the distinctive Air Force One livery)
    canvas.drawLine(
      Offset(bodyShift - 6.5, -4),
      Offset(bodyShift + 6.5, -4),
      Paint()
        ..color = secondary
        ..strokeWidth = 3.0,
    );
    // Gold pinstripe below blue band
    canvas.drawLine(
      Offset(bodyShift - 6, -2),
      Offset(bodyShift + 6, -2),
      Paint()
        ..color = detail
        ..strokeWidth = 0.8,
    );

    // Cockpit windows — larger, more prominent
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -13), width: 6, height: 5),
      Paint()..color = const Color(0xFF6AB0D6),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift - 0.5, -14),
        width: 2.5,
        height: 2,
      ),
      Paint()..color = const Color(0xFF9FD4F0),
    );

    // Passenger windows (both sides)
    for (var y in [-10.0, -7.0, -4.0, -1.0, 2.0, 5.0, 8.0]) {
      canvas.drawCircle(
        Offset(bodyShift + 3.5, y),
        0.6,
        Paint()..color = const Color(0xFF4A90B8),
      );
      canvas.drawCircle(
        Offset(bodyShift - 3.5, y),
        0.6,
        Paint()..color = const Color(0xFF4A90B8),
      );
    }

    // American flag accent at tail (small red-white-blue stripes)
    for (var i = 0; i < 3; i++) {
      final flagY = 13.0 + i * 1.5;
      final flagColor = i == 1 ? primary : (i == 0 ? secondary : detail);
      canvas.drawLine(
        Offset(bodyShift - 2, flagY),
        Offset(bodyShift + 2, flagY),
        Paint()
          ..color = flagColor
          ..strokeWidth = 1.2,
      );
    }

    // Nose cone — rounded, polished
    canvas.drawCircle(
      Offset(bodyShift, -19),
      3.5,
      Paint()..color = const Color(0xFFBBBBBB),
    );
    canvas.drawCircle(Offset(bodyShift, -19), 2.0, Paint()..color = primary);

    canvas.restore(); // End body roll transform

    // Four engines under wings (747 has 4)
    final enginePaint = Paint()..color = const Color(0xFF999999);
    final engineNose = Paint()..color = const Color(0xFF777777);
    for (var x in [-leftSpan * 0.35, -leftSpan * 0.6]) {
      final ey = 6 + wingDip * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ey), width: 4, height: 8),
          const Radius.circular(2),
        ),
        enginePaint,
      );
      canvas.drawCircle(Offset(x, ey - 4), 2.0, engineNose);
    }
    for (var x in [rightSpan * 0.35, rightSpan * 0.6]) {
      final ey = 6 - wingDip * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ey), width: 4, height: 8),
          const Radius.circular(2),
        ),
        enginePaint,
      );
      canvas.drawCircle(Offset(x, ey - 4), 2.0, engineNose);
    }

    // Navigation lights
    final navRed = Paint()..color = const Color(0xFFCC3333);
    final navGreen = Paint()..color = FlitColors.success;
    canvas.drawCircle(Offset(-leftSpan + 2, 6 + wingDip), 1.5, navRed);
    canvas.drawCircle(Offset(rightSpan - 2, 6 - wingDip), 1.5, navGreen);
  }

  // ─── Platinum Eagle ────────────────────────────────────────────────

  static void _renderEagle(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
  ) {
    final primary = _primary(colorScheme, 0xFFD4D4D4);
    final secondary = _secondary(colorScheme, 0xFF6A0DAD);
    final detail = _detail(colorScheme, 0xFFC0C0C0);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Swept eagle wings
    final leftWingColor = shade < 0
        ? secondary
        : Color.lerp(secondary, Colors.black, 0.3)!;
    final rightWingColor = shade > 0
        ? secondary
        : Color.lerp(secondary, Colors.black, 0.3)!;

    final leftSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-4 + bodyShift, -4)
      ..quadraticBezierTo(
        -leftSpan * 0.5,
        -10 + wingDip * 0.3,
        -leftSpan,
        2 + wingDip,
      )
      ..lineTo(-leftSpan + 6, 6 + wingDip)
      ..lineTo(-4 + bodyShift, 2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(4 + bodyShift, -4)
      ..quadraticBezierTo(
        rightSpan * 0.5,
        -10 - wingDip * 0.3,
        rightSpan,
        2 - wingDip,
      )
      ..lineTo(rightSpan - 6, 6 - wingDip)
      ..lineTo(4 + bodyShift, 2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Tail feathers
    final tailPath = Path()
      ..moveTo(bodyShift - 4, 10)
      ..lineTo(bodyShift - 6, 16)
      ..lineTo(bodyShift, 13)
      ..lineTo(bodyShift + 6, 16)
      ..lineTo(bodyShift + 4, 10)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = secondary);

    // Raptor body (tapered)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16) // beak tip
      ..quadraticBezierTo(4 + bodyShift, -10, 4 + bodyShift, -2)
      ..quadraticBezierTo(3 + bodyShift, 6, 2 + bodyShift, 12)
      ..lineTo(-2 + bodyShift, 12)
      ..quadraticBezierTo(-3 + bodyShift, 6, -4 + bodyShift, -2)
      ..quadraticBezierTo(-4 + bodyShift, -10, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Eagle eye
    canvas.drawCircle(
      Offset(bodyShift + 1.5, -10),
      2.0,
      Paint()..color = secondary,
    );
    canvas.drawCircle(
      Offset(bodyShift + 1.5, -10),
      1.0,
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Shimmer highlights
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(bodyShift - 2 + i * 3.0, -4 + i * 4.0),
        1.2,
        Paint()..color = detail.withOpacity(0.6),
      );
    }

    canvas.restore(); // End body roll transform
  }
}
