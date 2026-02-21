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

  // ─── Sketch / Hand-drawn Helpers ────────────────────────────────────

  /// Returns a seeded [Random] based on [planeId] so wobble offsets are
  /// deterministic across frames (no per-frame jitter).
  static Random _sketchRng(String planeId) =>
      Random(planeId.codeUnits.fold<int>(0, (h, c) => h * 31 + c));

  /// Draws [path] with a subtle random offset on each segment endpoint to
  /// simulate the slight imprecision of hand-drawn line work.
  ///
  /// [wobble] controls the maximum displacement in logical pixels (0.3–0.5 is
  /// subtle; stay under 0.6 to avoid changing the apparent shape).
  ///
  /// Uses [rng] so the same path always produces identical wobble (stable).
  static void _sketchPath(
    Path path,
    Canvas canvas,
    Paint paint,
    Random rng, {
    double wobble = 0.4,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final len = metric.length;
      if (len < 1) continue;

      // Sample points along the path and add tiny perpendicular jitter.
      const step = 4.0; // sample every 4px of path length
      final sketched = Path();
      bool first = true;
      for (double t = 0; t <= len; t += step) {
        final tangent = metric.getTangentForOffset(t.clamp(0, len));
        if (tangent == null) continue;
        final pos = tangent.position;
        final dx = (rng.nextDouble() - 0.5) * 2 * wobble;
        final dy = (rng.nextDouble() - 0.5) * 2 * wobble;
        if (first) {
          sketched.moveTo(pos.dx + dx, pos.dy + dy);
          first = false;
        } else {
          sketched.lineTo(pos.dx + dx, pos.dy + dy);
        }
      }
      canvas.drawPath(sketched, paint);
    }
  }

  /// Draws a pencil-sketch outline pass around [path]: a slightly offset,
  /// slightly darker stroke with [StrokeCap.round] to simulate ink-on-pencil
  /// hand-drawn lines.
  ///
  /// Call this AFTER the fill pass so the outline sits on top.
  static void _pencilOutline(
    Path path,
    Canvas canvas,
    Color baseColor, {
    double strokeWidth = 1.1,
    double offsetX = 0.3,
    double offsetY = 0.3,
    double opacity = 0.55,
  }) {
    final outlinePaint = Paint()
      ..color = _darken(baseColor, 0.45).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Primary outline (sits exactly on the path)
    canvas.drawPath(path, outlinePaint);

    // Offset shadow stroke — creates the "ink bleed" hand-drawn feel
    final shadowPaint = Paint()
      ..color = _darken(baseColor, 0.55).withOpacity(opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
  }

  /// Draws light diagonal cross-hatch lines inside [bounds] to simulate
  /// fabric-covered wing surfaces (biplanes, triplanes, paper planes).
  ///
  /// [opacity] should stay in the 0.08–0.12 range — extremely subtle.
  static void _crossHatch(
    Canvas canvas,
    Rect bounds,
    Color lineColor, {
    double spacing = 5.0,
    double opacity = 0.10,
  }) {
    // Normalise so left < right, top < bottom (avoid degenerate rects)
    final normalised = Rect.fromLTRB(
      bounds.left < bounds.right ? bounds.left : bounds.right,
      bounds.top < bounds.bottom ? bounds.top : bounds.bottom,
      bounds.left < bounds.right ? bounds.right : bounds.left,
      bounds.top < bounds.bottom ? bounds.bottom : bounds.top,
    );

    if (normalised.width < 1 || normalised.height < 1) return;

    final paint = Paint()
      ..color = lineColor.withOpacity(opacity)
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.butt;

    final w = normalised.width;
    final h = normalised.height;
    final diag = w + h;

    // Clip to the bounds so lines don't bleed outside
    canvas.save();
    canvas.clipRect(normalised);

    // 45° lines going bottom-left to top-right
    for (double t = -diag; t <= diag; t += spacing) {
      canvas.drawLine(
        Offset(normalised.left + t, normalised.bottom),
        Offset(normalised.left + t + h, normalised.top),
        paint,
      );
    }
    canvas.restore();
  }

  /// Draws a soft ambient-occlusion shadow where a wing meets the fuselage.
  ///
  /// [center] is the joint point, [radius] controls the AO spread.
  static void _wingJointAO(
    Canvas canvas,
    Offset center, {
    double radius = 5.0,
    double opacity = 0.18,
  }) {
    final gradient = RadialGradient(
      colors: [Colors.black.withOpacity(opacity), Colors.transparent],
    );
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, paint);
  }

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
        _renderPaperPlane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
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
        _renderStealthPlane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_red_baron':
        _renderTriplane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
          planeId,
        );
        break;
      case 'plane_concorde_classic':
      case 'plane_diamond_concorde':
        _renderConcorde(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_seaplane':
        _renderSeaplane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
          planeId,
        );
        break;
      case 'plane_padraigaer':
        _renderAirliner(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_presidential':
        _renderPresidential(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_platinum_eagle':
        _renderEagle(canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
        break;
      default:
        _renderBiPlane(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          propAngle,
          planeId,
        );
        break;
    }
  }

  // ─── Bi-Plane (default, prop, warbird, night raider) ────────────────

  static void _renderBiPlane(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    double propAngle,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
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
    // Oval disc + blades simulate a slightly top-down camera angle.
    final propDiscPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -17), width: 16, height: 9),
      propDiscPaint,
    );

    final bladePaint = Paint()
      ..color = const Color(0xFF666666).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const bladeLen = 7.0;
    const bladeYScale = 0.55; // foreshorten vertical for top-down perspective
    for (var i = 0; i < 2; i++) {
      final a = propAngle + i * pi;
      canvas.drawLine(
        Offset(
          bodyShift + cos(a) * bladeLen,
          -17 + sin(a) * bladeLen * bladeYScale,
        ),
        Offset(
          bodyShift - cos(a) * bladeLen,
          -17 - sin(a) * bladeLen * bladeYScale,
        ),
        bladePaint,
      );
    }

    // --- Lower wing (visible peeking out behind/below upper wing) ---
    final leftSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final leftDip = wingDip;
    final lowerLeftSpan = leftSpan * 0.9; // lower wing slightly shorter
    final lowerLeftWing = Path()
      ..moveTo(-4, 3 + leftDip * 0.2)
      ..quadraticBezierTo(
        -lowerLeftSpan * 0.5,
        4 + leftDip * 0.5,
        -lowerLeftSpan,
        6 + leftDip,
      )
      ..quadraticBezierTo(
        -lowerLeftSpan - 1,
        8 + leftDip,
        -lowerLeftSpan + 2,
        9 + leftDip,
      )
      ..lineTo(-4, 7 + leftDip * 0.2)
      ..close();
    canvas.drawPath(
      lowerLeftWing,
      Paint()..color = _darken(leftWingColor, 0.15),
    );
    _crossHatch(
      canvas,
      Rect.fromLTRB(-lowerLeftSpan, 3 + leftDip, -4, 9 + leftDip),
      _darken(leftWingColor, 0.15),
      spacing: 4.5,
      opacity: 0.08,
    );
    _pencilOutline(
      lowerLeftWing,
      canvas,
      _darken(leftWingColor, 0.15),
      strokeWidth: 0.8,
    );

    // Interplane struts (connecting upper and lower wings)
    final biStrut = Paint()
      ..color = _darken(detail, 0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(-leftSpan * 0.4, 1 + leftDip * 0.4),
      Offset(-lowerLeftSpan * 0.4, 5 + leftDip * 0.4),
      biStrut,
    );
    canvas.drawLine(
      Offset(-leftSpan * 0.7, 2 + leftDip * 0.7),
      Offset(-lowerLeftSpan * 0.7, 6 + leftDip * 0.7),
      biStrut,
    );

    // --- Upper left wing ---
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

    // Left wing cross-hatch (fabric texture)
    _crossHatch(
      canvas,
      Rect.fromLTRB(-leftSpan, -1 + leftDip, -4, 5 + leftDip),
      leftWingColor,
      spacing: 4.5,
      opacity: 0.10,
    );

    // Left wing pencil outline
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 1.0);

    // Ambient occlusion at left wing root
    _wingJointAO(canvas, Offset(-4, 1 + leftDip * 0.2), radius: 5.0);

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

    // --- Lower right wing (visible behind/below upper) ---
    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
    final rightDip = -wingDip;
    final lowerRightSpan = rightSpan * 0.9;
    final lowerRightWing = Path()
      ..moveTo(4, 3 + rightDip * 0.2)
      ..quadraticBezierTo(
        lowerRightSpan * 0.5,
        4 + rightDip * 0.5,
        lowerRightSpan,
        6 + rightDip,
      )
      ..quadraticBezierTo(
        lowerRightSpan + 1,
        8 + rightDip,
        lowerRightSpan - 2,
        9 + rightDip,
      )
      ..lineTo(4, 7 + rightDip * 0.2)
      ..close();
    canvas.drawPath(
      lowerRightWing,
      Paint()..color = _darken(rightWingColor, 0.15),
    );
    _crossHatch(
      canvas,
      Rect.fromLTRB(4, 3 + rightDip, lowerRightSpan, 9 + rightDip),
      _darken(rightWingColor, 0.15),
      spacing: 4.5,
      opacity: 0.08,
    );
    _pencilOutline(
      lowerRightWing,
      canvas,
      _darken(rightWingColor, 0.15),
      strokeWidth: 0.8,
    );

    // Right interplane struts
    canvas.drawLine(
      Offset(rightSpan * 0.4, 1 + rightDip * 0.4),
      Offset(lowerRightSpan * 0.4, 5 + rightDip * 0.4),
      biStrut,
    );
    canvas.drawLine(
      Offset(rightSpan * 0.7, 2 + rightDip * 0.7),
      Offset(lowerRightSpan * 0.7, 6 + rightDip * 0.7),
      biStrut,
    );

    // --- Upper right wing ---
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

    // Right wing cross-hatch (fabric texture)
    _crossHatch(
      canvas,
      Rect.fromLTRB(4, -1 + rightDip, rightSpan, 5 + rightDip),
      rightWingColor,
      spacing: 4.5,
      opacity: 0.10,
    );

    // Right wing pencil outline
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 1.0);

    // Ambient occlusion at right wing root
    _wingJointAO(canvas, Offset(4, 1 + rightDip * 0.2), radius: 5.0);

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
    _pencilOutline(tailPath, canvas, _darken(detail, 0.1), strokeWidth: 0.9);

    // Vertical fin
    final finPath = Path()
      ..moveTo(bankSin * 2, 11)
      ..quadraticBezierTo(-4 + bankSin * 3, 15, -2 + bankSin * 2, 18)
      ..lineTo(2 + bankSin * 2, 18)
      ..quadraticBezierTo(4 + bankSin * 3, 15, bankSin * 2, 11)
      ..close();
    canvas.drawPath(finPath, accentPaint);
    _pencilOutline(finPath, canvas, secondary, strokeWidth: 0.9);

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

    // Sketch outline on fuselage — slightly wobbly hand-drawn feel
    final sketchOutlinePaint = Paint()
      ..color = _darken(primary, 0.40).withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, sketchOutlinePaint, rng, wobble: 0.35);

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
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
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

    // --- Left wing (sharp angular paper fold — crisp geometric lines) ---
    final leftWing = Path()
      ..moveTo(bodyShift, -22) // extended sharp nose tip
      ..lineTo(
        -leftSpan,
        4 + wingDip,
      ) // wing tip (moved forward for dart shape)
      ..lineTo(-leftSpan + 2, 5 + wingDip) // sharp trailing edge
      ..lineTo(bodyShift, 4) // center trailing edge
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // Paper wing cross-hatch (fold crease texture)
    _crossHatch(
      canvas,
      Rect.fromLTRB(-leftSpan, -22 + wingDip, bodyShift, 5 + wingDip),
      detail,
      spacing: 6.0,
      opacity: 0.09,
    );

    // Sharp fold crease line running from nose to wing tip
    canvas.drawLine(
      Offset(bodyShift, -22),
      Offset(-leftSpan * 0.6, 2 + wingDip * 0.6),
      Paint()
        ..color = _darken(detail, 0.1).withOpacity(0.25)
        ..strokeWidth = 0.6,
    );

    _pencilOutline(
      leftWing,
      canvas,
      leftWingColor,
      strokeWidth: 1.1,
      opacity: 0.50,
    );

    // --- Right wing ---
    final rightWing = Path()
      ..moveTo(bodyShift, -22) // sharp nose tip
      ..lineTo(rightSpan, 4 - wingDip) // wing tip
      ..lineTo(rightSpan - 2, 5 - wingDip) // sharp trailing edge
      ..lineTo(bodyShift, 4) // center trailing edge
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    _crossHatch(
      canvas,
      Rect.fromLTRB(bodyShift, -22 - wingDip, rightSpan, 5 - wingDip),
      detail,
      spacing: 6.0,
      opacity: 0.09,
    );

    // Right fold crease
    canvas.drawLine(
      Offset(bodyShift, -22),
      Offset(rightSpan * 0.6, 2 - wingDip * 0.6),
      Paint()
        ..color = _darken(detail, 0.1).withOpacity(0.25)
        ..strokeWidth = 0.6,
    );

    _pencilOutline(
      rightWing,
      canvas,
      rightWingColor,
      strokeWidth: 1.1,
      opacity: 0.50,
    );

    // --- Center body / keel (the folded ridge) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Folded keel — the raised center crease of a paper plane
    final keelPath = Path()
      ..moveTo(bodyShift, -22) // extended sharp nose
      ..lineTo(bodyShift + 2, -10) // narrow keel body
      ..lineTo(bodyShift + 1.5, 6)
      ..lineTo(bodyShift, 10) // tail point
      ..lineTo(bodyShift - 1.5, 6)
      ..lineTo(bodyShift - 2, -10)
      ..close();
    canvas.drawPath(keelPath, Paint()..color = primary);

    // Sketch wobble on keel — paper creases are imprecise
    final keelSketchPaint = Paint()
      ..color = _darken(detail, 0.30).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    _sketchPath(keelPath, canvas, keelSketchPaint, rng, wobble: 0.35);

    // Center fold line (sharp crease)
    canvas.drawLine(
      Offset(bodyShift, -22),
      Offset(bodyShift, 10),
      Paint()
        ..color = detail
        ..strokeWidth = 1.0,
    );

    // Tail notch (the V-cut at the back of a paper plane)
    final tailNotch = Path()
      ..moveTo(bodyShift - 2.5, 8)
      ..lineTo(bodyShift, 4) // notch apex
      ..lineTo(bodyShift + 2.5, 8)
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
    final rng = _sketchRng(planeId);
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
    // Wing moved forward (Y -2), tapers from wide root to narrow tip
    final leftWing = Path()
      ..moveTo(-4 + bodyShift, -2) // root leading edge (wider)
      ..lineTo(-leftSpan, 4 + wingDip) // tip leading edge
      ..lineTo(-leftSpan + 2, 5 + wingDip) // narrow tip trailing edge
      ..lineTo(-3 + bodyShift, 3) // root trailing edge (wider)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 0.9);
    _wingJointAO(canvas, Offset(-4 + bodyShift, 0), radius: 4.0);

    final rightSpan =
        dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(4 + bodyShift, -2) // root leading edge
      ..lineTo(rightSpan, 4 - wingDip) // tip leading edge
      ..lineTo(rightSpan - 2, 5 - wingDip) // narrow tip trailing edge
      ..lineTo(3 + bodyShift, 3) // root trailing edge
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 0.9);
    _wingJointAO(canvas, Offset(4 + bodyShift, 0), radius: 4.0);

    // --- Horizontal stabilizers (tail wings) ---
    final stabSpan = dynamicWingSpan * 0.35;
    final stabLeft = Path()
      ..moveTo(-2 + bodyShift, 12)
      ..lineTo(-stabSpan + bodyShift, 14 + wingDip * 0.2)
      ..lineTo(-stabSpan + 3 + bodyShift, 15 + wingDip * 0.2)
      ..lineTo(-1 + bodyShift, 13)
      ..close();
    canvas.drawPath(stabLeft, Paint()..color = leftWingColor);
    _pencilOutline(stabLeft, canvas, leftWingColor, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(2 + bodyShift, 12)
      ..lineTo(stabSpan + bodyShift, 14 - wingDip * 0.2)
      ..lineTo(stabSpan - 3 + bodyShift, 15 - wingDip * 0.2)
      ..lineTo(1 + bodyShift, 13)
      ..close();
    canvas.drawPath(stabRight, Paint()..color = rightWingColor);
    _pencilOutline(stabRight, canvas, rightWingColor, strokeWidth: 0.9);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Vertical stabilizer / fin (all jets have one — prominent dorsal fin)
    final finPath = Path()
      ..moveTo(bodyShift, 9)
      ..quadraticBezierTo(bodyShift - 2.5, 12, bodyShift - 1, 16)
      ..lineTo(bodyShift + 1, 16)
      ..quadraticBezierTo(bodyShift + 2.5, 12, bodyShift, 9)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);
    _pencilOutline(finPath, canvas, secondary, strokeWidth: 0.8);

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

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.40).withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.32);

    // Fighter canopy (bubble canopy for visibility)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -10), width: 4, height: 7),
      Paint()..color = const Color(0xFF4A90B8),
    );
    // Canopy frame
    canvas.drawLine(
      Offset(bodyShift, -13.5),
      Offset(bodyShift, -6.5),
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 0.5,
    );

    // Jet exhaust
    if (planeId == 'plane_rocket') {
      // Multi-layer afterburner flame (white core → yellow → orange → red)
      // Outer red glow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, 19), width: 8, height: 14),
        Paint()..color = const Color(0xFFCC2200).withOpacity(0.35),
      );
      // Orange flame
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, 18), width: 6, height: 11),
        Paint()..color = const Color(0xFFFF6600).withOpacity(0.6),
      );
      // Yellow inner flame
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, 17), width: 4, height: 8),
        Paint()..color = const Color(0xFFFFAA00).withOpacity(0.75),
      );
      // White-hot core
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, 16), width: 2.5, height: 5),
        Paint()..color = const Color(0xFFFFEECC).withOpacity(0.9),
      );
      // Nozzle
      canvas.drawCircle(
        Offset(bodyShift, 15),
        2.5,
        Paint()..color = const Color(0xFF444444),
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
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFF2A2A2A);
    final secondary = _secondary(colorScheme, 0xFF1A1A1A);
    final detail = _detail(colorScheme, 0xFF444444);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    final leftWingColor = shade < 0 ? primary : secondary;
    final rightWingColor = shade > 0 ? primary : secondary;

    // B-2 has extreme wingspan-to-length ratio (172 ft span, 69 ft long)
    // Use wider span multiplier for the flying wing silhouette
    final leftSpan =
        dynamicWingSpan * 1.4 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final leftWing = Path()
      ..moveTo(bodyShift, -12) // shorter nose (flying wing, not conventional)
      // Smooth, continuous leading edge sweep
      ..quadraticBezierTo(
        -leftSpan * 0.35,
        -8 + wingDip * 0.3,
        -leftSpan,
        2 + wingDip,
      )
      // W-shaped trailing edge — B-2's signature shape
      ..lineTo(-leftSpan + 4, 5 + wingDip) // outer trailing edge
      ..lineTo(-leftSpan * 0.5, 3 + wingDip * 0.5) // inner notch of W
      ..lineTo(bodyShift, 7) // center trailing edge
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // Stealth panels — subtle radar-absorbing panel lines
    final leftSketchPaint = Paint()
      ..color = const Color(0xFF555555).withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    _sketchPath(leftWing, canvas, leftSketchPaint, rng, wobble: 0.25);

    final rightSpan =
        dynamicWingSpan * 1.4 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
    final rightWing = Path()
      ..moveTo(bodyShift, -12)
      ..quadraticBezierTo(
        rightSpan * 0.35,
        -8 - wingDip * 0.3,
        rightSpan,
        2 - wingDip,
      )
      ..lineTo(rightSpan - 4, 5 - wingDip)
      ..lineTo(rightSpan * 0.5, 3 - wingDip * 0.5)
      ..lineTo(bodyShift, 7)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    final rightSketchPaint = Paint()
      ..color = const Color(0xFF555555).withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    _sketchPath(rightWing, canvas, rightSketchPaint, rng, wobble: 0.25);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Center body blended into wing — B-2 has no distinct fuselage
    final centerBody = Path()
      ..moveTo(bodyShift - 5, -8)
      ..quadraticBezierTo(bodyShift - 4, 0, bodyShift - 3, 6)
      ..lineTo(bodyShift + 3, 6)
      ..quadraticBezierTo(bodyShift + 4, 0, bodyShift + 5, -8)
      ..close();
    canvas.drawPath(centerBody, Paint()..color = detail);
    _pencilOutline(centerBody, canvas, detail, strokeWidth: 0.8, opacity: 0.40);

    // Exhaust slots on trailing edge (flush with wing, not protruding)
    final exhaustPaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bodyShift - 2.5, 6),
      Offset(bodyShift - 1, 6),
      exhaustPaint,
    );
    canvas.drawLine(
      Offset(bodyShift + 1, 6),
      Offset(bodyShift + 2.5, 6),
      exhaustPaint,
    );

    // Flush cockpit — B-2 has almost no cockpit bump
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -6), width: 4, height: 2.5),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    // Cockpit glass — very subtle
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -6), width: 2.5, height: 1.5),
      Paint()..color = const Color(0xFF3A3A3A),
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
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
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

    // --- Propeller (oval for top-down perspective) ---
    final propDiscPaint = Paint()
      ..color = primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -17), width: 14, height: 8),
      propDiscPaint,
    );
    final bladePaint = Paint()
      ..color = const Color(0xFF444444).withOpacity(0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const bladeLen = 6.0;
    const bladeYScale = 0.55; // foreshorten for perspective
    for (var i = 0; i < 2; i++) {
      final a = propAngle + i * pi;
      canvas.drawLine(
        Offset(
          bodyShift + cos(a) * bladeLen,
          -17 + sin(a) * bladeLen * bladeYScale,
        ),
        Offset(
          bodyShift - cos(a) * bladeLen,
          -17 - sin(a) * bladeLen * bladeYScale,
        ),
        bladePaint,
      );
    }

    // --- Three stacked wings (Fokker Dr.I: all EQUAL span, rounded tips) ---
    // The real Dr.I had equal-span wings — this was its distinctive feature
    final equalSpan = dynamicWingSpan;

    // Top wing
    final topWingRect = Rect.fromCenter(
      center: Offset(0, -6 + wingDip * 0.3),
      width: equalSpan * 2,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topWingRect, const Radius.circular(3)),
      Paint()..color = wingColor,
    );
    _crossHatch(canvas, topWingRect, wingColor, spacing: 4.0, opacity: 0.11);
    final topWingPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(topWingRect, const Radius.circular(3)),
      );
    _pencilOutline(topWingPath, canvas, wingColor, strokeWidth: 0.9);

    // Middle wing (same span)
    final midWingRect = Rect.fromCenter(
      center: Offset(0, 0 + wingDip * 0.6),
      width: equalSpan * 2,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(midWingRect, const Radius.circular(3)),
      Paint()..color = wingColor,
    );
    _crossHatch(canvas, midWingRect, wingColor, spacing: 4.0, opacity: 0.11);
    final midWingPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(midWingRect, const Radius.circular(3)),
      );
    _pencilOutline(midWingPath, canvas, wingColor, strokeWidth: 0.9);

    // Bottom wing (same span)
    final botWingRect = Rect.fromCenter(
      center: Offset(0, 6 + wingDip),
      width: equalSpan * 2,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(botWingRect, const Radius.circular(3)),
      Paint()..color = wingColor,
    );
    _crossHatch(canvas, botWingRect, wingColor, spacing: 4.0, opacity: 0.11);
    final botWingPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(botWingRect, const Radius.circular(3)),
      );
    _pencilOutline(botWingPath, canvas, wingColor, strokeWidth: 0.9);

    // Interplane struts — I-struts connecting each wing pair (Dr.I signature)
    final strutPaintWing = Paint()
      ..color = detail
      ..strokeWidth = 1.2;
    for (final x in [-equalSpan * 0.45, equalSpan * 0.45]) {
      // Top-to-mid struts
      canvas.drawLine(
        Offset(x, -4 + wingDip * 0.3),
        Offset(x, -1 + wingDip * 0.5),
        strutPaintWing,
      );
      // Mid-to-bottom struts
      canvas.drawLine(
        Offset(x, 2 + wingDip * 0.6),
        Offset(x, 4 + wingDip * 0.8),
        strutPaintWing,
      );
    }

    // AO at fuselage-wing junctions
    _wingJointAO(canvas, Offset(bodyShift, -6 + wingDip * 0.3), radius: 5.0);
    _wingJointAO(canvas, Offset(bodyShift, wingDip * 0.6), radius: 5.0);
    _wingJointAO(canvas, Offset(bodyShift, 6 + wingDip), radius: 5.0);

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
    _pencilOutline(tailPath, canvas, wingColor, strokeWidth: 0.9);

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

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.45).withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.38);

    // Inner interplane struts (near fuselage)
    final strutPaint = Paint()
      ..color = detail
      ..strokeWidth = 1.5;
    for (final x in [-dynamicWingSpan * 0.2, dynamicWingSpan * 0.2]) {
      canvas.drawLine(Offset(x, -4), Offset(x, 8 + wingDip * 0.5), strutPaint);
    }

    // Rotary engine cowling — Le Rhône 9J visible as circular housing
    canvas.drawCircle(
      Offset(bodyShift, -16),
      3.5,
      Paint()..color = const Color(0xFF555555),
    );
    canvas.drawCircle(
      Offset(bodyShift, -16),
      2.0,
      Paint()..color = const Color(0xFF444444),
    );
    // Cowling highlight
    canvas.drawCircle(
      Offset(bodyShift - 0.5, -16.5),
      1.0,
      Paint()..color = const Color(0xFF777777),
    );

    // Open cockpit (leather-rimmed)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -8), width: 5, height: 6),
      Paint()..color = const Color(0xFF654321),
    );
    // Cockpit rim
    _pencilOutline(
      Path()..addOval(
        Rect.fromCenter(center: Offset(bodyShift, -8), width: 5, height: 6),
      ),
      canvas,
      const Color(0xFF654321),
      strokeWidth: 0.8,
    );

    // Red Baron Iron Cross emblem
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
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
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

    // Ogival (ogee) delta wings — Concorde's signature double-curve leading edge
    final leftSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(bodyShift - 2, -18)
      // First ogee curve: gentle sweep near root
      ..quadraticBezierTo(
        -leftSpan * 0.3,
        -12 + wingDip * 0.3,
        -leftSpan * 0.65,
        -2 + wingDip * 0.6,
      )
      // Second ogee curve: sharper sweep toward tip
      ..quadraticBezierTo(
        -leftSpan * 0.9,
        4 + wingDip * 0.8,
        -leftSpan,
        10 + wingDip,
      )
      ..lineTo(-leftSpan + 3, 12 + wingDip)
      ..lineTo(bodyShift - 2, 14)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(bodyShift - 2, -4), radius: 5.5);

    final rightSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(bodyShift + 2, -18)
      ..quadraticBezierTo(
        rightSpan * 0.3,
        -12 - wingDip * 0.3,
        rightSpan * 0.65,
        -2 - wingDip * 0.6,
      )
      ..quadraticBezierTo(
        rightSpan * 0.9,
        4 - wingDip * 0.8,
        rightSpan,
        10 - wingDip,
      )
      ..lineTo(rightSpan - 3, 12 - wingDip)
      ..lineTo(bodyShift + 2, 14)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(bodyShift + 2, -4), radius: 5.5);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Long, thin fuselage — Concorde had extreme length-to-width ratio
    final fuselagePath = Path()
      ..moveTo(bodyShift, -20)
      ..quadraticBezierTo(2.5 + bodyShift, -12, 2.5 + bodyShift, 0)
      ..lineTo(2 + bodyShift, 16)
      ..lineTo(-2 + bodyShift, 16)
      ..lineTo(-2.5 + bodyShift, 0)
      ..quadraticBezierTo(-2.5 + bodyShift, -12, bodyShift, -20)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.38).withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.30);

    // Distinctive drooping visor nose — Concorde's iconic feature
    final droopNose = Path()
      ..moveTo(bodyShift - 1.5, -20)
      ..quadraticBezierTo(bodyShift - 0.5, -23, bodyShift, -25)
      ..quadraticBezierTo(bodyShift + 0.5, -23, bodyShift + 1.5, -20)
      ..close();
    canvas.drawPath(droopNose, Paint()..color = secondary);
    _pencilOutline(droopNose, canvas, secondary, strokeWidth: 0.8);

    // Accent stripe running along fuselage
    canvas.drawLine(
      Offset(bodyShift, -18),
      Offset(bodyShift, 12),
      Paint()
        ..color = detail
        ..strokeWidth = 1.8,
    );

    // Cockpit windows (narrow visor windows)
    for (var y in [-16.0, -14.0, -12.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bodyShift, y), width: 2.0, height: 1.2),
        Paint()..color = const Color(0xFF4A90B8),
      );
    }
    canvas.restore(); // End body roll transform

    // Four Olympus engines in two close nacelle pairs (signature Concorde layout)
    final enginePaint = Paint()..color = const Color(0xFF555555);
    final intakePaint = Paint()..color = const Color(0xFF444444);
    for (var x in [-leftSpan * 0.42, -leftSpan * 0.52]) {
      final ey = 8 + wingDip * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ey), width: 3, height: 5),
          const Radius.circular(1.5),
        ),
        enginePaint,
      );
      // Rectangular intake ramp (Concorde had distinctive box intakes)
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, ey - 2.5), width: 3.5, height: 1.5),
        intakePaint,
      );
    }
    for (var x in [rightSpan * 0.42, rightSpan * 0.52]) {
      final ey = 8 - wingDip * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ey), width: 3, height: 5),
          const Radius.circular(1.5),
        ),
        enginePaint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, ey - 2.5), width: 3.5, height: 1.5),
        intakePaint,
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
    String planeId,
  ) {
    final secondary = _secondary(colorScheme, 0xFF2E8B57);
    final detail = _detail(colorScheme, 0xFFF5F5F5);

    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;

    // Hull-shaped floats with step (real seaplanes have boat-hull shaped pontoons)
    final pontoonPaint = Paint()..color = detail;
    final lx = -dynamicWingSpan * 0.5;
    final ly = 12 + wingDip;

    // Left float — hull shape with step break for water release
    final leftFloat = Path()
      ..moveTo(lx, ly - 9) // bow (pointed nose)
      ..quadraticBezierTo(lx + 3.5, ly - 7, lx + 3.5, ly - 2) // hull curve
      ..lineTo(lx + 3, ly) // step break (abrupt change)
      ..lineTo(lx + 2.5, ly + 6) // aft section (narrower after step)
      ..quadraticBezierTo(lx, ly + 8, lx - 2.5, ly + 6) // stern
      ..lineTo(lx - 3, ly) // step on other side
      ..lineTo(lx - 3.5, ly - 2)
      ..quadraticBezierTo(lx - 3.5, ly - 7, lx, ly - 9) // back to bow
      ..close();
    canvas.drawPath(leftFloat, pontoonPaint);
    _pencilOutline(leftFloat, canvas, detail, strokeWidth: 0.9, opacity: 0.45);
    // Step line indicator
    canvas.drawLine(
      Offset(lx - 3, ly),
      Offset(lx + 3, ly),
      Paint()
        ..color = _darken(detail, 0.2).withOpacity(0.4)
        ..strokeWidth = 0.7,
    );

    final rx = dynamicWingSpan * 0.5;
    final ry = 12 - wingDip;

    // Right float — mirror of left
    final rightFloat = Path()
      ..moveTo(rx, ry - 9)
      ..quadraticBezierTo(rx + 3.5, ry - 7, rx + 3.5, ry - 2)
      ..lineTo(rx + 3, ry)
      ..lineTo(rx + 2.5, ry + 6)
      ..quadraticBezierTo(rx, ry + 8, rx - 2.5, ry + 6)
      ..lineTo(rx - 3, ry)
      ..lineTo(rx - 3.5, ry - 2)
      ..quadraticBezierTo(rx - 3.5, ry - 7, rx, ry - 9)
      ..close();
    canvas.drawPath(rightFloat, pontoonPaint);
    _pencilOutline(rightFloat, canvas, detail, strokeWidth: 0.9, opacity: 0.45);
    canvas.drawLine(
      Offset(rx - 3, ry),
      Offset(rx + 3, ry),
      Paint()
        ..color = _darken(detail, 0.2).withOpacity(0.4)
        ..strokeWidth = 0.7,
    );

    // V-struts connecting floats to fuselage (realistic bracing)
    final strutPaint = Paint()
      ..color = secondary
      ..strokeWidth = 1.5;
    // Left struts (V-brace pattern)
    canvas.drawLine(
      Offset(lx + 1, ly - 6),
      Offset(bodyShift - 3, 2 + wingDip * 0.3),
      strutPaint,
    );
    canvas.drawLine(
      Offset(lx - 1, ly - 6),
      Offset(bodyShift - 4, 6 + wingDip * 0.5),
      strutPaint,
    );
    // Right struts
    canvas.drawLine(
      Offset(rx - 1, ry - 6),
      Offset(bodyShift + 3, 2 - wingDip * 0.3),
      strutPaint,
    );
    canvas.drawLine(
      Offset(rx + 1, ry - 6),
      Offset(bodyShift + 4, 6 - wingDip * 0.5),
      strutPaint,
    );

    // Delegate to bi-plane for the main body
    _renderBiPlane(
      canvas,
      bankCos,
      bankSin,
      wingSpan,
      colorScheme,
      propAngle,
      planeId,
    );
  }

  // ─── Airliner (Padraigaer, Presidential) ────────────────────────────

  static void _renderAirliner(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFF169B62);
    final detail = _detail(colorScheme, 0xFFFF883E);

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
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(-6 + bodyShift, 1), radius: 5.0);

    // Left winglet (upturned wing tip — modern airliner signature)
    final leftWinglet = Path()
      ..moveTo(-leftSpan, 6 + wingDip)
      ..lineTo(-leftSpan - 1, 4 + wingDip) // winglet curves upward
      ..lineTo(-leftSpan + 1, 3 + wingDip)
      ..lineTo(-leftSpan + 1, 6 + wingDip)
      ..close();
    canvas.drawPath(leftWinglet, Paint()..color = _lighten(leftWingColor, 0.2));
    _pencilOutline(leftWinglet, canvas, leftWingColor, strokeWidth: 0.7);

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
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(6 + bodyShift, 1), radius: 5.0);

    // Right winglet
    final rightWinglet = Path()
      ..moveTo(rightSpan, 6 - wingDip)
      ..lineTo(rightSpan + 1, 4 - wingDip)
      ..lineTo(rightSpan - 1, 3 - wingDip)
      ..lineTo(rightSpan - 1, 6 - wingDip)
      ..close();
    canvas.drawPath(
      rightWinglet,
      Paint()..color = _lighten(rightWingColor, 0.2),
    );
    _pencilOutline(rightWinglet, canvas, rightWingColor, strokeWidth: 0.7);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Horizontal stabilizers (tail wings)
    final stabSpan = dynamicWingSpan * 0.4;
    final stabLeft = Path()
      ..moveTo(-3 + bodyShift, 13)
      ..lineTo(-stabSpan + bodyShift, 15 + wingDip * 0.2)
      ..lineTo(-stabSpan + 4 + bodyShift, 16 + wingDip * 0.2)
      ..lineTo(-2 + bodyShift, 14)
      ..close();
    canvas.drawPath(stabLeft, Paint()..color = detail);
    _pencilOutline(stabLeft, canvas, detail, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(3 + bodyShift, 13)
      ..lineTo(stabSpan + bodyShift, 15 - wingDip * 0.2)
      ..lineTo(stabSpan - 4 + bodyShift, 16 - wingDip * 0.2)
      ..lineTo(2 + bodyShift, 14)
      ..close();
    canvas.drawPath(stabRight, Paint()..color = detail);
    _pencilOutline(stabRight, canvas, detail, strokeWidth: 0.9);

    // Vertical stabilizer
    final finPath = Path()
      ..moveTo(bodyShift, 12)
      ..quadraticBezierTo(-2 + bodyShift, 14, bodyShift, 17)
      ..quadraticBezierTo(2 + bodyShift, 14, bodyShift, 12)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);
    _pencilOutline(finPath, canvas, secondary, strokeWidth: 0.9);

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

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.38).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.33);

    // Cockpit windows (flight deck)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -13), width: 5, height: 4),
      Paint()..color = const Color(0xFF4A90B8),
    );

    // Passenger windows (long row down each side — realistic airliner density)
    final windowPaint = Paint()..color = const Color(0xFF4A90B8);
    for (var y = -10.0; y <= 10.0; y += 1.8) {
      canvas.drawCircle(Offset(bodyShift + 3.5, y), 0.6, windowPaint);
      canvas.drawCircle(Offset(bodyShift - 3.5, y), 0.6, windowPaint);
    }

    // Airline livery stripe
    canvas.drawLine(
      Offset(bodyShift - 4.5, -8),
      Offset(bodyShift - 3.5, 12),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.0,
    );
    canvas.drawLine(
      Offset(bodyShift + 4.5, -8),
      Offset(bodyShift + 3.5, 12),
      Paint()
        ..color = secondary
        ..strokeWidth = 1.0,
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

  // ─── Presidential (747-style) ──────────────────────────────────────

  static void _renderPresidential(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFFF5F5F5);
    final secondary = _secondary(colorScheme, 0xFF1A3A5C);
    final detail = _detail(colorScheme, 0xFFD4A944);

    final shade = -bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Swept-back wings — wider and more authoritative than Padraigaer
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
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(-5 + bodyShift, 0), radius: 5.5);

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
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(5 + bodyShift, 0), radius: 5.5);

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
    _pencilOutline(stabLeft, canvas, primary, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(2 + bodyShift, 15)
      ..lineTo(stabSpan + bodyShift, 17 - wingDip * 0.2)
      ..lineTo(stabSpan - 3 + bodyShift, 18 - wingDip * 0.2)
      ..lineTo(1 + bodyShift, 16)
      ..close();
    canvas.drawPath(stabRight, Paint()..color = primary);
    _pencilOutline(stabRight, canvas, primary, strokeWidth: 0.9);

    // Tall vertical fin — distinctive T-tail
    final finPath = Path()
      ..moveTo(bodyShift - 1, 11)
      ..quadraticBezierTo(bodyShift - 3, 14, bodyShift - 1.5, 19)
      ..lineTo(bodyShift + 1.5, 19)
      ..quadraticBezierTo(bodyShift + 3, 14, bodyShift + 1, 11)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);
    _pencilOutline(finPath, canvas, secondary, strokeWidth: 0.9);
    // Gold accent on fin
    canvas.drawLine(
      Offset(bodyShift, 12),
      Offset(bodyShift, 18),
      Paint()
        ..color = detail
        ..strokeWidth = 1.2,
    );

    // Wide presidential fuselage (larger than Padraigaer)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -19)
      ..quadraticBezierTo(7 + bodyShift, -14, 7 + bodyShift, 0)
      ..quadraticBezierTo(6 + bodyShift, 10, 3 + bodyShift, 18)
      ..lineTo(-3 + bodyShift, 18)
      ..quadraticBezierTo(-6 + bodyShift, 10, -7 + bodyShift, 0)
      ..quadraticBezierTo(-7 + bodyShift, -14, bodyShift, -19)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.38).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.33);

    // Blue nose / head section (top third of fuselage)
    final blueHead = Path()
      ..moveTo(bodyShift, -19)
      ..quadraticBezierTo(7 + bodyShift, -14, 7 + bodyShift, -6)
      ..lineTo(-7 + bodyShift, -6)
      ..quadraticBezierTo(-7 + bodyShift, -14, bodyShift, -19)
      ..close();
    canvas.drawPath(blueHead, Paint()..color = secondary);

    // Red accent stripe across the middle
    final redStripe = Path()
      ..moveTo(bodyShift - 6.5, -2)
      ..lineTo(bodyShift + 6.5, -2)
      ..lineTo(bodyShift + 6, 2)
      ..lineTo(bodyShift - 6, 2)
      ..close();
    canvas.drawPath(redStripe, Paint()..color = const Color(0xFFCC3333));

    // Gold pinstripe borders on the red stripe
    canvas.drawLine(
      Offset(bodyShift - 6.5, -2),
      Offset(bodyShift + 6.5, -2),
      Paint()
        ..color = detail
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(bodyShift - 6, 2),
      Offset(bodyShift + 6, 2),
      Paint()
        ..color = detail
        ..strokeWidth = 0.8,
    );

    // Blue belly below the red stripe (lower fuselage)
    final blueBelly = Path()
      ..moveTo(bodyShift - 6, 2)
      ..quadraticBezierTo(bodyShift - 5, 10, bodyShift - 3, 18)
      ..lineTo(bodyShift + 3, 18)
      ..quadraticBezierTo(bodyShift + 5, 10, bodyShift + 6, 2)
      ..close();
    canvas.drawPath(blueBelly, Paint()..color = secondary.withOpacity(0.35));

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

    // Flag accent at tail (small tricolour stripes)
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

    canvas.restore(); // End body roll transform

    // Four engines hung below wings (747-style pylons)
    final enginePaint = Paint()..color = const Color(0xFF999999);
    final engineNose = Paint()..color = const Color(0xFF777777);
    for (var x in [-leftSpan * 0.35, -leftSpan * 0.6]) {
      final ey = 8 + wingDip * 0.5; // below the wing surface
      // Pylon connecting engine to wing
      canvas.drawLine(
        Offset(x, 5 + wingDip * 0.4),
        Offset(x, ey - 3),
        Paint()
          ..color = const Color(0xFFAAAAAA)
          ..strokeWidth = 1.5,
      );
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
      final ey = 8 - wingDip * 0.5;
      canvas.drawLine(
        Offset(x, 5 - wingDip * 0.4),
        Offset(x, ey - 3),
        Paint()
          ..color = const Color(0xFFAAAAAA)
          ..strokeWidth = 1.5,
      );
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
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
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
    // Eagle wing with organic "wrist" bend and scalloped feather trailing edge
    final leftWing = Path()
      ..moveTo(-4 + bodyShift, -4)
      // Leading edge with wrist bend (eagles angle their wings at the carpus)
      ..quadraticBezierTo(
        -leftSpan * 0.4,
        -8 + wingDip * 0.3,
        -leftSpan * 0.7,
        -2 + wingDip * 0.7,
      )
      ..quadraticBezierTo(
        -leftSpan * 0.9,
        0 + wingDip * 0.9,
        -leftSpan,
        2 + wingDip,
      )
      // Scalloped trailing edge (individual flight feather tips)
      ..lineTo(-leftSpan + 2, 5 + wingDip)
      ..lineTo(-leftSpan + 5, 4 + wingDip * 0.9)
      ..lineTo(-leftSpan + 7, 6 + wingDip * 0.8)
      ..lineTo(-leftSpan * 0.6, 5 + wingDip * 0.6)
      ..lineTo(-leftSpan * 0.45, 6 + wingDip * 0.5)
      ..lineTo(-leftSpan * 0.3, 4 + wingDip * 0.3)
      ..lineTo(-4 + bodyShift, 2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // Feather detail lines on wing
    final featherPaint = Paint()
      ..color = _darken(leftWingColor, 0.25).withOpacity(0.35)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final t = 0.3 + i * 0.15;
      canvas.drawLine(
        Offset(-leftSpan * t, -1 + wingDip * t),
        Offset(-leftSpan * (t + 0.1), 4 + wingDip * (t + 0.1)),
        featherPaint,
      );
    }

    _wingJointAO(canvas, Offset(-4 + bodyShift, -1), radius: 5.0);

    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(4 + bodyShift, -4)
      ..quadraticBezierTo(
        rightSpan * 0.4,
        -8 - wingDip * 0.3,
        rightSpan * 0.7,
        -2 - wingDip * 0.7,
      )
      ..quadraticBezierTo(
        rightSpan * 0.9,
        0 - wingDip * 0.9,
        rightSpan,
        2 - wingDip,
      )
      // Scalloped trailing edge
      ..lineTo(rightSpan - 2, 5 - wingDip)
      ..lineTo(rightSpan - 5, 4 - wingDip * 0.9)
      ..lineTo(rightSpan - 7, 6 - wingDip * 0.8)
      ..lineTo(rightSpan * 0.6, 5 - wingDip * 0.6)
      ..lineTo(rightSpan * 0.45, 6 - wingDip * 0.5)
      ..lineTo(rightSpan * 0.3, 4 - wingDip * 0.3)
      ..lineTo(4 + bodyShift, 2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // Right wing feather details
    for (var i = 0; i < 4; i++) {
      final t = 0.3 + i * 0.15;
      canvas.drawLine(
        Offset(rightSpan * t, -1 - wingDip * t),
        Offset(rightSpan * (t + 0.1), 4 - wingDip * (t + 0.1)),
        featherPaint,
      );
    }

    _wingJointAO(canvas, Offset(4 + bodyShift, -1), radius: 5.0);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Fan-shaped tail feathers (spread like a real eagle's tail)
    final tailPath = Path()
      ..moveTo(bodyShift - 3, 10)
      ..lineTo(bodyShift - 7, 17) // left outer feather
      ..lineTo(bodyShift - 4, 16) // inner scallop
      ..lineTo(bodyShift - 2, 18) // inner feather
      ..lineTo(bodyShift, 15) // center notch
      ..lineTo(bodyShift + 2, 18) // inner feather
      ..lineTo(bodyShift + 4, 16) // inner scallop
      ..lineTo(bodyShift + 7, 17) // right outer feather
      ..lineTo(bodyShift + 3, 10)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = secondary);
    _pencilOutline(tailPath, canvas, secondary, strokeWidth: 1.0);
    // Tail feather detail lines
    for (final dx in [-5.0, -2.0, 0.0, 2.0, 5.0]) {
      canvas.drawLine(
        Offset(bodyShift + dx * 0.6, 10),
        Offset(bodyShift + dx, 17),
        Paint()
          ..color = _darken(secondary, 0.2).withOpacity(0.3)
          ..strokeWidth = 0.5,
      );
    }

    // Raptor body (tapered, streamlined)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16) // beak base
      ..quadraticBezierTo(4 + bodyShift, -10, 4 + bodyShift, -2)
      ..quadraticBezierTo(3 + bodyShift, 6, 2 + bodyShift, 12)
      ..lineTo(-2 + bodyShift, 12)
      ..quadraticBezierTo(-3 + bodyShift, 6, -4 + bodyShift, -2)
      ..quadraticBezierTo(-4 + bodyShift, -10, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Sketch outline on body — feathered, slightly organic
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.40).withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.42);

    // Hooked beak (eagles have a distinctive curved raptor beak)
    final beakPath = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(bodyShift + 1, -18, bodyShift, -20) // beak tip
      ..quadraticBezierTo(bodyShift - 0.5, -18, bodyShift, -16)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFDAA520));
    _pencilOutline(beakPath, canvas, const Color(0xFFDAA520), strokeWidth: 0.7);

    // Eagle eye (fierce, forward-facing)
    canvas.drawCircle(
      Offset(bodyShift + 1.5, -11),
      2.2,
      Paint()..color = const Color(0xFFDAA520), // golden iris
    );
    canvas.drawCircle(
      Offset(bodyShift + 1.5, -11),
      1.0,
      Paint()..color = const Color(0xFF1A1A1A), // pupil
    );
    // Eye highlight
    canvas.drawCircle(
      Offset(bodyShift + 1.0, -11.5),
      0.5,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Platinum shimmer highlights along body
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(bodyShift - 1.5 + i * 2.0, -4 + i * 3.5),
        1.0,
        Paint()..color = detail.withOpacity(0.5),
      );
    }

    canvas.restore(); // End body roll transform
  }
}
