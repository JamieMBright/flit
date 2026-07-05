import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import 'watercolor_style.dart';

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

  /// Draws a soft watercolor edge along [path] — replaces the old hand-drawn
  /// sketch wobble with a blurred, paint-like edge that simulates pigment
  /// settling along a wet boundary.
  ///
  /// [rng] and [wobble] are kept in the signature for backward-compat but
  /// are no longer used; the watercolor blur handles visual softness.
  static void _sketchPath(
    Path path,
    Canvas canvas,
    Paint paint,
    Random rng, {
    double wobble = 0.4,
  }) {
    WatercolorStyle.wetEdge(
      canvas,
      path,
      paint.color,
      width: paint.strokeWidth > 0 ? paint.strokeWidth : 1.2,
      blur: 2.0,
      opacity: (paint.color.opacity * 0.7).clamp(0.1, 0.5),
    );
  }

  /// Draws a soft watercolor wet-edge around [path] — paint darkens where it
  /// pools at boundaries, creating the characteristic watercolour outline.
  ///
  /// Replaces the old pencil-sketch outline with a blurred, organic edge.
  static void _pencilOutline(
    Path path,
    Canvas canvas,
    Color baseColor, {
    double strokeWidth = 1.1,
    double opacity = 0.55,
  }) {
    WatercolorStyle.wetEdge(
      canvas,
      path,
      baseColor,
      width: strokeWidth * 1.4,
      blur: 2.2,
      opacity: opacity * 0.55,
    );
  }

  /// Draws a subtle watercolour wash gradient inside [bounds] to simulate
  /// uneven pigment distribution across a painted surface.
  ///
  /// Replaces the old diagonal cross-hatch lines with a soft colour variation
  /// that reads as natural watercolour texture rather than fabric weave.
  static void _crossHatch(
    Canvas canvas,
    Rect bounds,
    Color lineColor, {
    double spacing = 5.0,
    double opacity = 0.10,
  }) {
    // Normalise so left < right, top < bottom
    final normalised = Rect.fromLTRB(
      bounds.left < bounds.right ? bounds.left : bounds.right,
      bounds.top < bounds.bottom ? bounds.top : bounds.bottom,
      bounds.left < bounds.right ? bounds.right : bounds.left,
      bounds.top < bounds.bottom ? bounds.bottom : bounds.top,
    );

    if (normalised.width < 1 || normalised.height < 1) return;

    final clipPath = Path()..addRect(normalised);
    WatercolorStyle.washTexture(canvas, clipPath, lineColor, opacity: opacity);
    WatercolorStyle.granulate(
      canvas,
      clipPath,
      lineColor,
      count: 8,
      maxRadius: 1.2,
      opacity: opacity * 0.6,
      seed: '${normalised.hashCode}',
    );
  }

  /// Draw a path as a SOLID, readable mass with subtle watercolour texture.
  ///
  /// The plane silhouette must read at a glance, so this paints an opaque base
  /// first (no grey bleed-through, no soft external halo — the old washFill
  /// offset+blurred translucent layers *outside* the path, which read as a
  /// white wet-edge glow on light fuselages). Pigment variation is then layered
  /// clipped *inside* the shape so it stays a crisp silhouette while keeping
  /// the hand-painted feel.
  static void _wash(
    Canvas canvas,
    Path path,
    Color color, {
    String seed = '',
  }) {
    // Opaque base — the solid pigment that makes the shape read.
    canvas.drawPath(path, Paint()..color = color);

    // Internal pigment variation, clipped so it never spills past the edge.
    canvas.save();
    canvas.clipPath(path);
    final rng = Random(seed.hashCode);
    for (var i = 0; i < 3; i++) {
      final dx = (rng.nextDouble() - 0.5) * 1.4;
      final dy = (rng.nextDouble() - 0.5) * 1.4;
      final tint = i.isEven
          ? WatercolorStyle.darken(color, 0.13)
          : WatercolorStyle.lighten(color, 0.16);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = tint.withOpacity(0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1),
      );
      canvas.restore();
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

  /// Draws a spinning propeller at the nose tip: a faint translucent spin-disc
  /// (the motion blur of the arc), two thin blade strokes, and a small solid
  /// spinner hub. Replaces the old opaque grey "mushroom cap" nose ellipse so
  /// the nose reads as a real prop, not a blob. Shared by all propeller planes.
  static void _drawNoseProp(
    Canvas canvas, {
    required double cx,
    required double noseY,
    required double propAngle,
    required Color hubColor,
    double radius = 7.0,
  }) {
    const yScale = 0.5; // slight top-down foreshortening of the disc
    // Faint spin-disc — the translucent arc the blades sweep.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, noseY),
        width: radius * 2,
        height: radius * 2 * yScale,
      ),
      Paint()..color = const Color(0xFFEDEDED).withOpacity(0.14),
    );
    // Two thin blade strokes.
    final blade = Paint()
      ..color = const Color(0xFF3A3A3A).withOpacity(0.75)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final a = propAngle + i * pi;
      canvas.drawLine(
        Offset(cx + cos(a) * radius, noseY + sin(a) * radius * yScale),
        Offset(cx - cos(a) * radius, noseY - sin(a) * radius * yScale),
        blade,
      );
    }
    // Small spinner hub at the centre.
    canvas.drawCircle(Offset(cx, noseY), 1.8, Paint()..color = hubColor);
    canvas.drawCircle(
      Offset(cx - 0.4, noseY - 0.5),
      0.7,
      Paint()..color = WatercolorStyle.lighten(hubColor, 0.6),
    );
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
      case 'plane_hot_air_balloon':
        _renderHotAirBalloon(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_shuttle':
        _renderShuttle(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_hang_glider':
        // Seasonal summer "Beach Glider" silhouette. Not a catalog cosmetic —
        // injected only via SeasonalTheme.resolvePlaneShapeId during the event.
        _renderHangGlider(
          canvas,
          bankCos,
          bankSin,
          wingSpan,
          colorScheme,
          planeId,
        );
        break;
      case 'plane_santa_sleigh':
        // Seasonal Christmas silhouette — injected via resolvePlaneShapeId.
        _renderSantaSleigh(
            canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
        break;
      case 'plane_witch_broom':
        // Seasonal Halloween silhouette — injected via resolvePlaneShapeId.
        _renderWitchBroom(
            canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
        break;
      case 'plane_easter_carriage':
        // Seasonal Easter silhouette — injected via resolvePlaneShapeId.
        _renderEasterCarriage(
            canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
        break;
      case 'plane_cupid_arrow':
        // Seasonal Valentines silhouette — injected via resolvePlaneShapeId.
        _renderCupidArrow(
            canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
        break;
      case 'plane_clover_copter':
        // Seasonal St Patrick's Day silhouette — injected via resolvePlaneShapeId.
        _renderCloverCopter(
            canvas, bankCos, bankSin, wingSpan, colorScheme, planeId);
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

    final shade = bankSin;
    final leftWingColor =
        shade > 0 ? _lighten(detail, shade) : _darken(detail, -shade * 0.4);
    final rightWingColor =
        shade < 0 ? _lighten(detail, -shade) : _darken(detail, shade * 0.4);
    final bodyPaint = Paint()..color = primary;
    final accentPaint = Paint()..color = secondary;
    final highlightPaint = Paint()
      ..color = FlitColors.planeHighlight.withOpacity(0.35);
    final undersidePaint = Paint()..color = _darken(primary, 0.35);

    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = bankSin * 4.0;
    final bodyShift = bankSin * 1.5;

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
    _wash(canvas, lowerLeftWing, _darken(leftWingColor, 0.15), seed: planeId);
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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);

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
    _wash(canvas, lowerRightWing, _darken(rightWingColor, 0.15), seed: planeId);
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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);

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
    _wash(canvas, tailPath, _darken(detail, 0.1), seed: planeId);
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
    _wash(canvas, fuselagePath, bodyPaint.color, seed: planeId);

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

    // Fuselage roundel — a small circular insignia (purposeful mark that
    // replaces the old meaningless mid-body accent square).
    canvas.drawCircle(Offset(bodyShift, -1), 2.4, accentPaint);
    canvas.drawCircle(
      Offset(bodyShift, -1),
      1.1,
      Paint()..color = primary,
    );

    // Cockpit canopy
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
    canvas.restore(); // End body roll transform

    // Spinning propeller at the nose (thin disc + blades + spinner hub).
    _drawNoseProp(
      canvas,
      cx: bodyShift,
      noseY: -16,
      propAngle: propAngle,
      hubColor: _darken(detail, 0.1),
    );

    // Wing tip navigation lights (small — was oversized).
    canvas.drawCircle(Offset(-leftSpan + 1, 3.5 + leftDip), 0.8, accentPaint);
    canvas.drawCircle(
      Offset(rightSpan - 1, 3.5 + rightDip),
      0.8,
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = bankSin * 4.0;

    // Paper planes are a single folded shape — wings ARE the body.
    // Draw as unified triangular form with fold line, not separate parts.
    final leftWingColor = shade > 0 ? primary : secondary;
    final rightWingColor = shade < 0 ? primary : secondary;

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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);

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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);

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
    _wash(canvas, keelPath, primary, seed: planeId);

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

    final shade = bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Swept delta wings — inner (turning) wing darkens, outer stays lit.
    // The golden jet uses its rich primary gold for the wings (not the pale
    // detail) so they read as a solid precious-metal mass.
    final wingBase = planeId == 'plane_golden_jet' ? primary : detail;
    final leftWingColor =
        shade > 0 ? wingBase : Color.lerp(wingBase, Colors.black, 0.3)!;
    final rightWingColor =
        shade < 0 ? wingBase : Color.lerp(wingBase, Colors.black, 0.3)!;

    final leftSpan =
        dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    // Wing moved forward (Y -2), tapers from wide root to narrow tip
    final leftWing = Path()
      ..moveTo(-4 + bodyShift, -2) // root leading edge (wider)
      ..lineTo(-leftSpan, 4 + wingDip) // tip leading edge
      ..lineTo(-leftSpan + 2, 5 + wingDip) // narrow tip trailing edge
      ..lineTo(-3 + bodyShift, 3) // root trailing edge (wider)
      ..close();
    _wash(canvas, leftWing, leftWingColor, seed: planeId);
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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);
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
    _wash(canvas, stabLeft, leftWingColor, seed: planeId);
    _pencilOutline(stabLeft, canvas, leftWingColor, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(2 + bodyShift, 12)
      ..lineTo(stabSpan + bodyShift, 14 - wingDip * 0.2)
      ..lineTo(stabSpan - 3 + bodyShift, 15 - wingDip * 0.2)
      ..lineTo(1 + bodyShift, 13)
      ..close();
    _wash(canvas, stabRight, rightWingColor, seed: planeId);
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
    _wash(canvas, finPath, secondary, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

    // Legendary gold gradient — polished sheen from a bright highlight edge to a
    // richer bronze underside so the golden jet reads as precious metal, not
    // flat paint.
    if (planeId == 'plane_golden_jet') {
      canvas.save();
      canvas.clipPath(fuselagePath);
      final sheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _lighten(primary, 0.55),
            primary,
            _darken(primary, 0.30),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromLTRB(bodyShift - 3, -18, bodyShift + 3, 15),
        );
      canvas.drawPath(fuselagePath, sheen);
      canvas.restore();
    }

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

    if (planeId == 'plane_rocket') {
      // Porthole window — a purposeful mark (replaces the old blank white bar).
      canvas.drawCircle(
        Offset(bodyShift, -3),
        2.4,
        Paint()..color = const Color(0xFF2A2A2A),
      );
      canvas.drawCircle(
        Offset(bodyShift, -3),
        2.4,
        Paint()
          ..color = detail // orange rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        Offset(bodyShift, -3),
        1.5,
        Paint()..color = const Color(0xFF7EC8E3),
      );
      canvas.drawCircle(
        Offset(bodyShift - 0.5, -3.5),
        0.6,
        Paint()..color = Colors.white.withOpacity(0.8),
      );
    } else if (planeId == 'plane_golden_jet') {
      // Gold shine streaks — legendary sheen down the polished fuselage.
      canvas.drawLine(
        Offset(bodyShift - 1.3, -12),
        Offset(bodyShift - 1.6, 10),
        Paint()
          ..color = _lighten(detail, 0.7).withOpacity(0.85)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(bodyShift + 1.4, -10),
        Offset(bodyShift + 1.2, 6),
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Centred racing stripe (was off-centre — combined with the canopy it
      // read as a stray letter "P").
      canvas.drawLine(
        Offset(bodyShift, -13),
        Offset(bodyShift, 9),
        Paint()
          ..color = secondary
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    final leftWingColor = shade > 0 ? primary : secondary;
    final rightWingColor = shade < 0 ? primary : secondary;

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
      // Double-W sawtooth trailing edge — the B-2's signature serrated rear.
      // Deep alternating teeth (aft peaks / forward notches) so the serration
      // reads clearly at small size, not as a flat trailing edge.
      ..lineTo(-leftSpan * 0.90, 9.5 + wingDip) // outer tooth (aft)
      ..lineTo(-leftSpan * 0.68, 3.5 + wingDip * 0.7) // notch (forward)
      ..lineTo(-leftSpan * 0.46, 10.5 + wingDip * 0.5) // mid tooth (aft)
      ..lineTo(-leftSpan * 0.24, 4.0 + wingDip * 0.3) // notch (forward)
      ..lineTo(bodyShift, 13) // centre spike (deepest aft point)
      ..close();
    _wash(canvas, leftWing, leftWingColor, seed: planeId);

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
      ..lineTo(rightSpan * 0.90, 9.5 - wingDip) // outer tooth (aft)
      ..lineTo(rightSpan * 0.68, 3.5 - wingDip * 0.7) // notch (forward)
      ..lineTo(rightSpan * 0.46, 10.5 - wingDip * 0.5) // mid tooth (aft)
      ..lineTo(rightSpan * 0.24, 4.0 - wingDip * 0.3) // notch (forward)
      ..lineTo(bodyShift, 13) // centre spike (deepest aft point)
      ..close();
    _wash(canvas, rightWing, rightWingColor, seed: planeId);

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

    // Center body blended into wing — B-2 has no distinct fuselage, tapering
    // to the aft centre spike so the serrated planform stays continuous.
    final centerBody = Path()
      ..moveTo(bodyShift - 5, -8)
      ..quadraticBezierTo(bodyShift - 4.5, 2, bodyShift - 2.5, 12)
      ..lineTo(bodyShift + 2.5, 12)
      ..quadraticBezierTo(bodyShift + 4.5, 2, bodyShift + 5, -8)
      ..close();
    _wash(canvas, centerBody, detail, seed: planeId);
    _pencilOutline(centerBody, canvas, detail, strokeWidth: 0.8, opacity: 0.40);

    // Exhaust slots set into the trailing edge (flush, not protruding)
    final exhaustPaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bodyShift - 2.5, 8),
      Offset(bodyShift - 1, 8),
      exhaustPaint,
    );
    canvas.drawLine(
      Offset(bodyShift + 1, 8),
      Offset(bodyShift + 2.5, 8),
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Crimson RED wings (Fokker Dr.I fabric) — the Baron's signature. Slight
    // darkening toward the secondary shade on the inner (banking) wing.
    final wingColor =
        shade < 0 ? primary : Color.lerp(primary, secondary, 0.4)!;

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
    _wash(canvas, tailPath, wingColor, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

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

    // Open cockpit (leather-rimmed)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -8), width: 5, height: 6),
      Paint()..color = const Color(0xFF654321),
    );
    // Cockpit rim
    _pencilOutline(
      Path()
        ..addOval(
          Rect.fromCenter(center: Offset(bodyShift, -8), width: 5, height: 6),
        ),
      canvas,
      const Color(0xFF654321),
      strokeWidth: 0.8,
    );

    // Iron Cross roundel — BLACK cross on a WHITE disc so it reads against the
    // crimson fuselage (was dark-red-on-red and invisible).
    canvas.drawCircle(
      Offset(bodyShift, 0),
      3.4,
      Paint()..color = const Color(0xFFF2F2F2),
    );
    final crossPaint = Paint()
      ..color = detail // near-black
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(bodyShift - 3, 0),
      Offset(bodyShift + 3, 0),
      crossPaint,
    );
    canvas.drawLine(
      Offset(bodyShift, -3),
      Offset(bodyShift, 3),
      crossPaint,
    );
    canvas.restore(); // End body roll transform

    // Spinning propeller at the nose.
    _drawNoseProp(
      canvas,
      cx: bodyShift,
      noseY: -16,
      propAngle: propAngle,
      hubColor: const Color(0xFF555555),
      radius: 6.0,
    );
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.5;

    // Delta wing — inner (turning) wing darkens, outer stays lit.
    final leftWingColor =
        shade > 0 ? primary : Color.lerp(primary, Colors.grey, 0.2)!;
    final rightWingColor =
        shade < 0 ? primary : Color.lerp(primary, Colors.grey, 0.2)!;

    // Ogival (ogee) delta wings — Concorde's signature double-curve leading
    // edge. Narrow + long: a slim, deeply-swept delta (not a broad manta).
    final leftSpan =
        dynamicWingSpan * 0.72 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 1.0);
    _wingJointAO(canvas, Offset(bodyShift - 2, -4), radius: 5.5);

    final rightSpan =
        dynamicWingSpan * 0.72 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

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
    _wash(canvas, droopNose, secondary, seed: planeId);
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

    // Four Olympus engines as rectangular nacelle boxes slung UNDER the wing
    // trailing edge, each ATTACHED by a short pylon (were floating on the wing).
    final enginePaint = Paint()..color = const Color(0xFF555555);
    final exhaustPaint = Paint()..color = const Color(0xFF2E2E2E);
    final pylonPaint = Paint()
      ..color = _darken(primary, 0.25)
      ..strokeWidth = 1.4;

    void drawNacelle(double x, double ey) {
      // Pylon fairing joining the nacelle to the wing above it.
      canvas.drawLine(Offset(x, ey - 5), Offset(x, ey - 1), pylonPaint);
      // Nacelle box.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ey), width: 3.4, height: 6),
          const Radius.circular(1.2),
        ),
        enginePaint,
      );
      // Dark exhaust at the aft end.
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, ey + 2.6), width: 3.4, height: 1.4),
        exhaustPaint,
      );
    }

    for (var x in [-leftSpan * 0.34, -leftSpan * 0.56]) {
      drawNacelle(x, 11 + wingDip * 0.5);
    }
    for (var x in [rightSpan * 0.34, rightSpan * 0.56]) {
      drawNacelle(x, 11 - wingDip * 0.5);
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

    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = bankSin * 4.0;

    // Draw the main body FIRST so the floats and their bracing struts sit
    // clearly in front of the wings. Drawn underneath, the wings painted over
    // the struts and the pontoons looked detached.
    _renderBiPlane(
      canvas,
      bankCos,
      bankSin,
      wingSpan,
      colorScheme,
      propAngle,
      planeId,
    );

    final lx = -dynamicWingSpan * 0.5;
    final rx = dynamicWingSpan * 0.5;
    // Floats slung low, well below the wing, so the struts have a clear span.
    final ly = 17 + wingDip;
    final ry = 17 - wingDip;

    // Bold bracing struts — dark, drawn before the pontoon bodies so each float
    // reads as hung from two visible legs up to the fuselage belly.
    final strutColor = _darken(secondary, 0.2);
    void drawFloatStruts(double fx, double fy, double dip) {
      final strut = Paint()
        ..color = strutColor
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      final bellyX = bodyShift + (fx < 0 ? -2.5 : 2.5);
      // Two splayed legs from the float deck up to the fuselage belly.
      canvas.drawLine(
          Offset(fx - 2, fy - 8), Offset(bellyX, 4 + dip * 0.4), strut);
      canvas.drawLine(
          Offset(fx + 2, fy - 8), Offset(bellyX, 8 + dip * 0.4), strut);
      // Horizontal deck brace tying the two legs together at the float top.
      canvas.drawLine(
          Offset(fx - 2.5, fy - 8),
          Offset(fx + 2.5, fy - 8),
          Paint()
            ..color = strutColor
            ..strokeWidth = 1.4);
    }

    drawFloatStruts(lx, ly, wingDip);
    drawFloatStruts(rx, ry, -wingDip);

    // Hull-shaped floats with a planing step (boat-hull pontoons).
    Path hullFloat(double fx, double fy) => Path()
      ..moveTo(fx, fy - 9) // bow (pointed nose)
      ..quadraticBezierTo(fx + 3.5, fy - 7, fx + 3.5, fy - 2) // hull curve
      ..lineTo(fx + 3, fy) // step break
      ..lineTo(fx + 2.5, fy + 6) // aft section (narrower after step)
      ..quadraticBezierTo(fx, fy + 8, fx - 2.5, fy + 6) // stern
      ..lineTo(fx - 3, fy) // step on other side
      ..lineTo(fx - 3.5, fy - 2)
      ..quadraticBezierTo(fx - 3.5, fy - 7, fx, fy - 9) // back to bow
      ..close();

    for (final f in [
      [lx, ly],
      [rx, ry],
    ]) {
      final fx = f[0];
      final fy = f[1];
      final float = hullFloat(fx, fy);
      _wash(canvas, float, detail, seed: planeId);
      _pencilOutline(float, canvas, detail, strokeWidth: 0.9, opacity: 0.45);
      // Planing-step line.
      canvas.drawLine(
        Offset(fx - 3, fy),
        Offset(fx + 3, fy),
        Paint()
          ..color = _darken(detail, 0.2).withOpacity(0.4)
          ..strokeWidth = 0.7,
      );
    }
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Wide swept wings — inner (turning) wing darkens, outer stays lit.
    final leftWingColor =
        shade > 0 ? detail : Color.lerp(detail, Colors.grey, 0.3)!;
    final rightWingColor =
        shade < 0 ? detail : Color.lerp(detail, Colors.grey, 0.3)!;

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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);
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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);
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
    _wash(canvas, stabLeft, detail, seed: planeId);
    _pencilOutline(stabLeft, canvas, detail, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(3 + bodyShift, 13)
      ..lineTo(stabSpan + bodyShift, 15 - wingDip * 0.2)
      ..lineTo(stabSpan - 4 + bodyShift, 16 - wingDip * 0.2)
      ..lineTo(2 + bodyShift, 14)
      ..close();
    _wash(canvas, stabRight, detail, seed: planeId);
    _pencilOutline(stabRight, canvas, detail, strokeWidth: 0.9);

    // Vertical stabilizer
    final finPath = Path()
      ..moveTo(bodyShift, 12)
      ..quadraticBezierTo(-2 + bodyShift, 14, bodyShift, 17)
      ..quadraticBezierTo(2 + bodyShift, 14, bodyShift, 12)
      ..close();
    _wash(canvas, finPath, secondary, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

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

    final shade = bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Swept-back wings — inner (turning) wing darkens, outer stays lit.
    final leftWingColor =
        shade > 0 ? primary : Color.lerp(primary, Colors.grey, 0.15)!;
    final rightWingColor =
        shade < 0 ? primary : Color.lerp(primary, Colors.grey, 0.15)!;

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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);
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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);
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
    _wash(canvas, stabLeft, primary, seed: planeId);
    _pencilOutline(stabLeft, canvas, primary, strokeWidth: 0.9);
    final stabRight = Path()
      ..moveTo(2 + bodyShift, 15)
      ..lineTo(stabSpan + bodyShift, 17 - wingDip * 0.2)
      ..lineTo(stabSpan - 3 + bodyShift, 18 - wingDip * 0.2)
      ..lineTo(1 + bodyShift, 16)
      ..close();
    _wash(canvas, stabRight, primary, seed: planeId);
    _pencilOutline(stabRight, canvas, primary, strokeWidth: 0.9);

    // Tall vertical fin — distinctive T-tail
    final finPath = Path()
      ..moveTo(bodyShift - 1, 11)
      ..quadraticBezierTo(bodyShift - 3, 14, bodyShift - 1.5, 19)
      ..lineTo(bodyShift + 1.5, 19)
      ..quadraticBezierTo(bodyShift + 3, 14, bodyShift + 1, 11)
      ..close();
    _wash(canvas, finPath, secondary, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

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
    _wash(canvas, blueHead, secondary, seed: planeId);

    // Red accent stripe across the middle
    final redStripe = Path()
      ..moveTo(bodyShift - 6.5, -2)
      ..lineTo(bodyShift + 6.5, -2)
      ..lineTo(bodyShift + 6, 2)
      ..lineTo(bodyShift - 6, 2)
      ..close();
    _wash(canvas, redStripe, const Color(0xFFCC3333), seed: planeId);

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
    _wash(canvas, blueBelly, secondary.withOpacity(0.35), seed: planeId);

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

    // Navigation lights (small — shared wingtip-light sizing).
    final navRed = Paint()..color = const Color(0xFFCC3333);
    final navGreen = Paint()..color = FlitColors.success;
    canvas.drawCircle(Offset(-leftSpan + 2, 6 + wingDip), 0.8, navRed);
    canvas.drawCircle(Offset(rightSpan - 2, 6 - wingDip), 0.8, navGreen);
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

    final shade = bankSin;
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Swept eagle wings — inner (turning) wing darkens, outer stays lit.
    final leftWingColor =
        shade > 0 ? secondary : Color.lerp(secondary, Colors.black, 0.3)!;
    final rightWingColor =
        shade < 0 ? secondary : Color.lerp(secondary, Colors.black, 0.3)!;

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
    _wash(canvas, leftWing, leftWingColor, seed: planeId);

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
    _wash(canvas, rightWing, rightWingColor, seed: planeId);

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
    _wash(canvas, tailPath, secondary, seed: planeId);
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
    _wash(canvas, fuselagePath, primary, seed: planeId);

    // Sketch outline on body — feathered, slightly organic
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.40).withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.42);

    // Compact hooked beak — a short, wide gold triangle at the head front
    // (was a thin tall spike that read as an antenna).
    final beakPath = Path()
      ..moveTo(bodyShift - 2, -14.5)
      ..lineTo(bodyShift, -18.5) // beak tip (short, not a spire)
      ..lineTo(bodyShift + 2, -14.5)
      ..quadraticBezierTo(bodyShift, -13.5, bodyShift - 2, -14.5)
      ..close();
    _wash(canvas, beakPath, const Color(0xFFDAA520), seed: planeId);
    _pencilOutline(beakPath, canvas, const Color(0xFFC8901A), strokeWidth: 0.7);

    // TWO small top-down eye dots on the sides of the head (no iris rings
    // or glints — big forward eyes read as an owl face from above).
    for (final ex in [-1.9, 1.9]) {
      canvas.drawCircle(
        Offset(bodyShift + ex, -12),
        0.8,
        Paint()..color = const Color(0xFF1A1A1A),
      );
    }

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

  // ─── Hot Air Balloon ────────────────────────────────────────────────

  static void _renderHotAirBalloon(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFFE03030); // Red envelope
    final secondary = _secondary(colorScheme, 0xFFF0C040); // Yellow stripes
    final detail = _detail(colorScheme, 0xFF6B3A1E); // Wicker brown

    final bodyShift = bankSin * 0.8; // Balloons sway gently, not bank hard
    final sway = bankSin * 2.5; // Basket sways more than the balloon

    // --- Body group ---
    canvas.save();
    final rollScale = 0.7 + bankCos.abs() * 0.3; // Subtle roll
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Suspension cables (behind envelope, from basket rim to envelope base)
    final cablePaint = Paint()
      ..color = _darken(detail, 0.2).withOpacity(0.7)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    // Four cables from basket corners to balloon base
    for (final dx in [-3.5, -1.5, 1.5, 3.5]) {
      canvas.drawLine(
        Offset(bodyShift + dx * 0.8, 4), // Balloon base attachment
        Offset(bodyShift + sway * 0.15 + dx * 0.5, 14), // Basket rim
        cablePaint,
      );
    }

    // --- Balloon envelope (the big round part) ---
    // Main envelope shape — a big upside-down teardrop
    final envelopePath = Path()
      ..moveTo(bodyShift, -22) // Crown (top)
      ..quadraticBezierTo(
        bodyShift + 14,
        -18,
        bodyShift + 13,
        -6,
      ) // Right bulge
      ..quadraticBezierTo(
        bodyShift + 11,
        2,
        bodyShift + 5,
        5,
      ) // Right taper to throat
      ..lineTo(bodyShift - 5, 5) // Throat (bottom opening)
      ..quadraticBezierTo(bodyShift - 11, 2, bodyShift - 13, -6) // Left taper
      ..quadraticBezierTo(
        bodyShift - 14,
        -18,
        bodyShift,
        -22,
      ) // Left bulge back to crown
      ..close();
    _wash(canvas, envelopePath, primary, seed: planeId);

    // Coloured gore stripes (vertical panels) — alternating secondary colour
    canvas.save();
    canvas.clipPath(envelopePath);
    final stripePaint = Paint()..color = secondary;
    // Draw vertical stripes across the balloon
    for (var i = -2; i <= 2; i++) {
      final x = bodyShift + i * 5.0;
      final stripeRect = Rect.fromLTWH(x - 1.2, -23, 2.4, 29);
      canvas.drawRect(stripeRect, stripePaint);
    }
    canvas.restore();

    // Sketch outline on envelope
    final envelopeSketchPaint = Paint()
      ..color = _darken(primary, 0.40).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(envelopePath, canvas, envelopeSketchPaint, rng, wobble: 0.35);

    // Crown circle (reinforcement patch at top)
    canvas.drawCircle(
      Offset(bodyShift, -21.5),
      2.0,
      Paint()..color = _darken(primary, 0.15),
    );

    // Throat opening (dark circle at bottom of envelope)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 5), width: 10, height: 3),
      Paint()..color = _darken(primary, 0.35),
    );

    // Burner flame (small orange glow beneath throat)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 6.5), width: 3, height: 4),
      Paint()..color = const Color(0xFFFF8800).withOpacity(0.7),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 6.0), width: 1.5, height: 2.5),
      Paint()..color = const Color(0xFFFFDD44).withOpacity(0.8),
    );

    // --- Basket (wicker gondola) ---
    final basketShift = bodyShift + sway * 0.15;

    // Basket body (trapezoid — wider at top, narrower at bottom)
    final basketPath = Path()
      ..moveTo(basketShift - 4, 14) // Top left rim
      ..lineTo(basketShift + 4, 14) // Top right rim
      ..lineTo(basketShift + 3, 20) // Bottom right
      ..lineTo(basketShift - 3, 20) // Bottom left
      ..close();
    _wash(canvas, basketPath, detail, seed: planeId);

    // Basket weave texture — horizontal lines
    final weavePaint = Paint()
      ..color = _darken(detail, 0.25).withOpacity(0.5)
      ..strokeWidth = 0.5;
    for (var y = 15.5; y < 20; y += 1.5) {
      final t = (y - 14) / 6; // 0..1 from top to bottom
      final halfW = 4 - t * 1.0; // Narrows toward bottom
      canvas.drawLine(
        Offset(basketShift - halfW, y),
        Offset(basketShift + halfW, y),
        weavePaint,
      );
    }

    // Basket rim (dark ring at top)
    canvas.drawLine(
      Offset(basketShift - 4.5, 14),
      Offset(basketShift + 4.5, 14),
      Paint()
        ..color = _darken(detail, 0.3)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Pencil outline on basket
    _pencilOutline(basketPath, canvas, detail, strokeWidth: 0.9);

    canvas.restore(); // End body roll transform
  }

  // ─── Space Shuttle (Challenger) ────────────────────────────────────

  static void _renderShuttle(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFFF5F5F5); // NASA white
    final secondary = _secondary(colorScheme, 0xFF1A1A1A); // Heat shield
    final detail = _detail(colorScheme, 0xFF3366CC); // NASA blue

    final shade = bankSin;
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Delta wings with black heat-shield underside
    final leftWingColor =
        shade > 0 ? secondary : Color.lerp(secondary, Colors.black, 0.3)!;
    final rightWingColor =
        shade < 0 ? secondary : Color.lerp(secondary, Colors.black, 0.3)!;

    final leftSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    // Stubby delta wings (shuttle has short wingspan relative to length)
    final leftWing = Path()
      ..moveTo(-3 + bodyShift, -2)
      ..lineTo(-leftSpan, 6 + wingDip) // Wing tip (mid-body)
      ..lineTo(-leftSpan + 2, 8 + wingDip) // Trailing edge tip
      ..lineTo(-2 + bodyShift, 8) // Wing root trailing edge
      ..close();
    _wash(canvas, leftWing, leftWingColor, seed: planeId);
    _pencilOutline(leftWing, canvas, leftWingColor, strokeWidth: 0.9);
    _wingJointAO(canvas, Offset(-3 + bodyShift, 2), radius: 3.5);

    final rightSpan =
        dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(3 + bodyShift, -2)
      ..lineTo(rightSpan, 6 - wingDip)
      ..lineTo(rightSpan - 2, 8 - wingDip)
      ..lineTo(2 + bodyShift, 8)
      ..close();
    _wash(canvas, rightWing, rightWingColor, seed: planeId);
    _pencilOutline(rightWing, canvas, rightWingColor, strokeWidth: 0.9);
    _wingJointAO(canvas, Offset(3 + bodyShift, 2), radius: 3.5);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Vertical stabilizer (tall tail fin)
    final finPath = Path()
      ..moveTo(bodyShift, 8)
      ..quadraticBezierTo(bodyShift - 4, 12, bodyShift - 2, 18)
      ..lineTo(bodyShift + 1, 18)
      ..quadraticBezierTo(bodyShift + 1, 14, bodyShift, 8)
      ..close();
    _wash(canvas, finPath, primary, seed: planeId);
    _pencilOutline(finPath, canvas, primary, strokeWidth: 0.8);

    // OMS pods (small bumps on either side of tail)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift - 2.5, 14), width: 2, height: 4),
      Paint()..color = primary,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift + 2.5, 14), width: 2, height: 4),
      Paint()..color = primary,
    );

    // Fuselage — blunt nose, cylindrical body
    final fuselagePath = Path()
      ..moveTo(bodyShift, -20) // Nose tip
      ..quadraticBezierTo(
        bodyShift + 3,
        -17,
        bodyShift + 4,
        -10,
      ) // Right side of nose
      ..lineTo(bodyShift + 3.5, 14) // Right side body
      ..lineTo(bodyShift - 3.5, 14) // Left side body
      ..lineTo(bodyShift - 4, -10) // Left side
      ..quadraticBezierTo(
        bodyShift - 3,
        -17,
        bodyShift,
        -20,
      ) // Left side of nose
      ..close();
    _wash(canvas, fuselagePath, primary, seed: planeId);

    // Sketch outline on fuselage
    final fuselageSketchPaint = Paint()
      ..color = _darken(primary, 0.35).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _sketchPath(fuselagePath, canvas, fuselageSketchPaint, rng, wobble: 0.3);

    // Black heat-shield tiles on underside/nose
    final heatShieldPath = Path()
      ..moveTo(bodyShift, -20)
      ..quadraticBezierTo(bodyShift + 2, -17, bodyShift + 2.5, -12)
      ..lineTo(bodyShift - 2.5, -12)
      ..quadraticBezierTo(bodyShift - 2, -17, bodyShift, -20)
      ..close();
    _wash(canvas, heatShieldPath, secondary, seed: planeId);

    // Payload bay doors (lines along body)
    final doorPaint = Paint()
      ..color = _darken(primary, 0.15).withOpacity(0.4)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(bodyShift, -8), Offset(bodyShift, 8), doorPaint);
    // Door hinge lines
    canvas.drawLine(
      Offset(bodyShift - 3.2, -6),
      Offset(bodyShift - 3.2, 6),
      doorPaint,
    );
    canvas.drawLine(
      Offset(bodyShift + 3.2, -6),
      Offset(bodyShift + 3.2, 6),
      doorPaint,
    );

    // NASA "worm" accent stripe
    canvas.drawLine(
      Offset(bodyShift - 2, -9),
      Offset(bodyShift - 2, 4),
      Paint()
        ..color = detail
        ..strokeWidth = 1.5,
    );

    // "USA" flag accent (small rectangle)
    canvas.drawRect(
      Rect.fromLTWH(bodyShift + 1, -6, 2, 1.5),
      Paint()..color = detail,
    );

    // Cockpit windows (row of small windows at nose)
    final windowPaint = Paint()..color = const Color(0xFF4A90B8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -14), width: 4, height: 3),
      windowPaint,
    );
    // Window frame
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -14), width: 4, height: 3),
      Paint()
        ..color = _darken(primary, 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Main engine cluster (three SSME nozzles at the tail)
    for (final dx in [-2.0, 0.0, 2.0]) {
      // Nozzle
      canvas.drawCircle(
        Offset(bodyShift + dx, 15),
        1.5,
        Paint()..color = const Color(0xFF555555),
      );
    }

    // Massive exhaust plume — multi-layer afterburner
    // Outer yellow-white plume
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 22), width: 10, height: 18),
      Paint()..color = const Color(0xFFFFDD44).withOpacity(0.25),
    );
    // Orange flame core
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 20), width: 7, height: 14),
      Paint()..color = const Color(0xFFFF6600).withOpacity(0.45),
    );
    // White-hot inner core
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 18), width: 4, height: 8),
      Paint()..color = const Color(0xFFFFEECC).withOpacity(0.7),
    );
    // Bright center
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, 17), width: 2, height: 4),
      Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.8),
    );

    canvas.restore(); // End body roll transform
  }

  // ─── Hang Glider (seasonal summer "Beach Glider") ───────────────────

  /// Draws a hang-glider silhouette: a swept delta fabric wing (canopy) with a
  /// central keel spine and a small pilot slung beneath on an A-frame control
  /// bar. Top-down/behind view, nose pointing up (−Y), matching the watercolour
  /// conventions of the other plane shapes.
  ///
  /// Colours: primary = sail/canopy fabric, secondary = keel + sail accent
  /// stripes + control bar, detail = pilot/harness. The seasonal Beach Glider
  /// palette (cyan / yellow / white) is wired in via the passed [colorScheme].
  static void _renderHangGlider(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final rng = _sketchRng(planeId);
    final primary = _primary(colorScheme, 0xFF00CED1); // sail fabric (cyan)
    final secondary = _secondary(colorScheme, 0xFFFFD700); // keel / accents
    final detail = _detail(colorScheme, 0xFFFFFFFF); // pilot / harness

    final shade = bankSin;
    final bodyShift = bankSin * 1.5;
    // The delta wing is broad — give it a generous span like the flying-wing
    // shapes so the triangular canopy reads clearly at small sizes.
    final dynamicWingSpan = wingSpan * bankCos.abs() * 1.25;
    final wingDip = -bankSin * 3.0;

    // Inner (turning) half darkens, outer half stays lit — same banking
    // treatment used by the jet / shuttle deltas.
    final leftSailColor =
        shade > 0 ? primary : Color.lerp(primary, Colors.black, 0.22)!;
    final rightSailColor =
        shade < 0 ? primary : Color.lerp(primary, Colors.black, 0.22)!;

    // Apex of the delta (nose / leading point) sits forward of centre.
    const noseY = -16.0;
    // Trailing edge sweeps back to the rear corners.
    const trailY = 12.0;

    final leftSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final rightSpan =
        dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;

    // --- Left sail half (delta triangle: nose → left tip → keel tail) ---
    final leftSail = Path()
      ..moveTo(bodyShift, noseY) // nose apex
      ..lineTo(-leftSpan, trailY - 4 + wingDip) // swept-back left tip
      ..quadraticBezierTo(
        -leftSpan * 0.45,
        trailY + 1 + wingDip * 0.5,
        bodyShift,
        trailY, // keel tail (centre trailing point)
      )
      ..close();
    _wash(canvas, leftSail, leftSailColor, seed: planeId);
    _crossHatch(
      canvas,
      Rect.fromLTRB(-leftSpan, noseY, bodyShift, trailY + wingDip),
      leftSailColor,
      spacing: 5.5,
      opacity: 0.09,
    );
    _pencilOutline(leftSail, canvas, leftSailColor, strokeWidth: 1.0);

    // --- Right sail half ---
    final rightSail = Path()
      ..moveTo(bodyShift, noseY)
      ..lineTo(rightSpan, trailY - 4 - wingDip)
      ..quadraticBezierTo(
        rightSpan * 0.45,
        trailY + 1 - wingDip * 0.5,
        bodyShift,
        trailY,
      )
      ..close();
    _wash(canvas, rightSail, rightSailColor, seed: planeId);
    _crossHatch(
      canvas,
      Rect.fromLTRB(bodyShift, noseY, rightSpan, trailY - wingDip),
      rightSailColor,
      spacing: 5.5,
      opacity: 0.09,
    );
    _pencilOutline(rightSail, canvas, rightSailColor, strokeWidth: 1.0);

    // Sail accent stripes (one per half) running nose → tip, secondary colour.
    final stripePaint = Paint()
      ..color = secondary.withOpacity(0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bodyShift, noseY),
      Offset(-leftSpan * 0.62, trailY - 5 + wingDip * 0.6),
      stripePaint,
    );
    canvas.drawLine(
      Offset(bodyShift, noseY),
      Offset(rightSpan * 0.62, trailY - 5 - wingDip * 0.6),
      stripePaint,
    );

    // Sail highlight on the lit half (soft watercolour glint near the nose).
    final highlightPaint = Paint()
      ..color = FlitColors.planeHighlight.withOpacity(0.30);
    if (shade <= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(bodyShift, noseY + 1)
          ..lineTo(-leftSpan * 0.5, trailY - 6 + wingDip * 0.5)
          ..lineTo(-leftSpan * 0.3, trailY - 5 + wingDip * 0.5)
          ..lineTo(bodyShift, noseY + 4)
          ..close(),
        highlightPaint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(bodyShift, noseY + 1)
          ..lineTo(rightSpan * 0.5, trailY - 6 - wingDip * 0.5)
          ..lineTo(rightSpan * 0.3, trailY - 5 - wingDip * 0.5)
          ..lineTo(bodyShift, noseY + 4)
          ..close(),
        highlightPaint,
      );
    }

    // --- Body group (keel spine + control bar + slung pilot) ---
    // Wrapped in the same roll transform as the other shapes so the underslung
    // assembly foreshortens correctly when banking.
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Keel spine — the central tube/batten from nose to tail.
    final keelPath = Path()
      ..moveTo(bodyShift, noseY)
      ..lineTo(bodyShift + 1.3, trailY)
      ..lineTo(bodyShift - 1.3, trailY)
      ..close();
    _wash(canvas, keelPath, secondary, seed: planeId);
    final keelSketchPaint = Paint()
      ..color = _darken(secondary, 0.35).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    _sketchPath(keelPath, canvas, keelSketchPaint, rng, wobble: 0.3);

    // Cross-bar (the spanwise batten across the wing, behind the pilot).
    canvas.drawLine(
      Offset(bodyShift - dynamicWingSpan * 0.5, -1),
      Offset(bodyShift + dynamicWingSpan * 0.5, -1),
      Paint()
        ..color = _darken(secondary, 0.15).withOpacity(0.55)
        ..strokeWidth = 0.9,
    );

    // A-frame control bar — triangle of struts hanging below the keel that the
    // pilot holds. Drawn as thin lines for a wireframe look.
    const hangApexY = -2.0; // hang point on the keel
    const barY = 9.0; // base bar (where hands grip)
    const barHalf = 4.5;
    final framePaint = Paint()
      ..color = _darken(secondary, 0.2)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bodyShift, hangApexY),
      Offset(bodyShift - barHalf, barY),
      framePaint,
    );
    canvas.drawLine(
      Offset(bodyShift, hangApexY),
      Offset(bodyShift + barHalf, barY),
      framePaint,
    );
    // Base bar (control bar the pilot grips).
    canvas.drawLine(
      Offset(bodyShift - barHalf, barY),
      Offset(bodyShift + barHalf, barY),
      framePaint,
    );

    // --- Pilot slung beneath, prone (head forward, body trailing aft) ---
    // Suspension strap from the hang point down to the harness.
    canvas.drawLine(
      Offset(bodyShift, hangApexY),
      Offset(bodyShift, 4),
      Paint()
        ..color = _darken(detail, 0.4)
        ..strokeWidth = 1.0,
    );

    // Harness / pilot torso — a slim capsule lying along the keel.
    final pilotPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bodyShift, 3), width: 5, height: 13),
          const Radius.circular(2.5),
        ),
      );
    _wash(canvas, pilotPath, detail, seed: planeId);
    _pencilOutline(pilotPath, canvas, detail, strokeWidth: 0.9);

    // Pilot head (small circle near the nose/front of the harness).
    canvas.drawCircle(
      Offset(bodyShift, -3),
      2.2,
      Paint()..color = _darken(detail, 0.12),
    );
    canvas.drawCircle(
      Offset(bodyShift - 0.5, -3.5),
      0.9,
      Paint()..color = _lighten(detail, 0.6),
    );

    // Hands gripping the control bar (two small dots at the base bar).
    final handPaint = Paint()..color = _darken(detail, 0.25);
    canvas.drawCircle(Offset(bodyShift - 2.4, barY), 1.0, handPaint);
    canvas.drawCircle(Offset(bodyShift + 2.4, barY), 1.0, handPaint);

    canvas.restore(); // End body roll transform

    // Nose-tip nav highlight (tiny bright point at the leading apex).
    canvas.drawCircle(
      Offset(bodyShift, noseY),
      1.4,
      Paint()..color = secondary,
    );
  }

  // ─── Santa's Sleigh (seasonal Christmas) ────────────────────────────

  /// Draws Santa's sleigh: a curved-runner body (viewed from the side/above)
  /// with a bulging gift sack at the rear, two curved runners extending left
  /// and right (as "wings" to imply forward motion), and a reins line
  /// projecting forward.
  ///
  /// Colours: primary = sleigh body (red), secondary = runners/gilt trim (gold),
  /// detail = snow/gift accents (white).
  static void _renderSantaSleigh(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFFCC0000); // deep red
    final secondary = _secondary(colorScheme, 0xFFFFD700); // gold
    final detail = _detail(colorScheme, 0xFFFFFFFF); // white/snow

    final bodyShift = bankSin * 1.5;
    final cx = bodyShift;

    // SIDE PROFILE. The sleigh's length runs along the travel axis (Y, nose =
    // −Y = up), so it stays narrow — never stretched into wide "wings" (that
    // top-down throne read was the whole bug). Iconic cues: a big scroll curl
    // at the front, a seat tub, a curled runner blade below, a gift sack aft.

    // --- Body group (mild horizontal roll only — side view barely squishes) ---
    canvas.save();
    final rollScale = 0.78 + bankCos.abs() * 0.22;
    canvas.translate(cx, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-cx, 0);

    // Slight 3/4 side view: the sleigh sits low with its length across the
    // frame — a flat keel at the BOTTOM, a prow sweeping UP and curling at the
    // front (right), an open seat with a tall back at the rear (left), and a
    // single sled runner beneath the keel. A bottom runner reads as a sled base
    // (the "insect" bug came from runners spread L+R like wings — avoided here).
    //
    // Tilt the whole side profile so the prow points up-track: the same
    // diagonal trick the witch broom uses, so the sleigh reads as gliding
    // forward rather than standing on its tail.
    canvas.translate(cx, 0);
    canvas.rotate(-0.55);
    canvas.translate(-cx, 0);

    // --- Sled runner (gold): bold blade under the keel, curling up at the front.
    final runnerStroke = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final runner = Path()
      ..moveTo(cx - 7, 12) // rear tip
      ..lineTo(cx + 4, 12) // along the bottom to the front
      ..quadraticBezierTo(cx + 7.5, 12, cx + 7.5, 8) // curl up at the front
      ..quadraticBezierTo(cx + 7.5, 5.5, cx + 4.5, 6.5); // scroll back
    canvas.drawPath(runner, runnerStroke);
    // Two stanchions from the runner up to the keel.
    final strutPaint = Paint()
      ..color = _darken(secondary, 0.12)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 5, 12), Offset(cx - 5, 9), strutPaint);
    canvas.drawLine(Offset(cx + 2, 12), Offset(cx + 2, 9), strutPaint);

    // Gift sack (white, tied with gold) piled in the open seat — drawn
    // first so the dash and seat-back overlap its base.
    final sackPath = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(cx - 1, -2), width: 9, height: 9),
      );
    _wash(canvas, sackPath, detail, seed: planeId);
    _pencilOutline(sackPath, canvas, _darken(detail, 0.15), strokeWidth: 0.9);
    canvas.drawCircle(Offset(cx + 1.5, -5.5), 1.1, Paint()..color = secondary);

    // --- Sleigh body (red): classic profile — keel bottom, LOW front dash
    // ending in a small scroll curl, open seat holding the sack, and a TALL
    // curved seat-back at the rear. ---
    final body = Path()
      ..moveTo(cx - 6, 9) // rear-bottom of keel
      ..lineTo(cx + 3, 9) // keel bottom to the front
      ..quadraticBezierTo(cx + 6.5, 8, cx + 6, 3) // front riser
      ..quadraticBezierTo(cx + 5.5, 0, cx + 8, -2) // sweep to the prow tip
      ..quadraticBezierTo(cx + 9.5, -3.5, cx + 7, -4.5) // small scroll over
      ..quadraticBezierTo(cx + 5.5, -4.5, cx + 5, -2) // scroll inner
      ..quadraticBezierTo(cx + 3.5, 1, cx + 1, 1.5) // dash slopes to seat
      ..lineTo(cx - 3, 1.5) // seat pan
      ..quadraticBezierTo(cx - 4.5, 1, cx - 5, -5) // seat-back inner edge
      ..quadraticBezierTo(cx - 5.2, -7.5, cx - 7, -7) // rounded back top
      ..quadraticBezierTo(cx - 7.5, -3, cx - 6, 9) // tall outer back edge
      ..close();
    _wash(canvas, body, primary, seed: planeId);
    _pencilOutline(body, canvas, _darken(primary, 0.2), strokeWidth: 1.1);

    // Gold trim: prow scroll + seat-back top edge.
    final trimStroke = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(cx + 6, 3)
        ..quadraticBezierTo(cx + 5.5, 0, cx + 8, -2)
        ..quadraticBezierTo(cx + 9.5, -3.5, cx + 7, -4.5),
      trimStroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 5, -5)
        ..quadraticBezierTo(cx - 5.2, -7.5, cx - 7, -7),
      trimStroke,
    );

    canvas.restore();
  }

  // ─── Witch's Broom (seasonal Halloween) ─────────────────────────────

  /// Draws a witch's broom flying horizontally (nose = top, bristles at
  /// bottom/rear). A long handle, a fan of bristles spread at the rear, and
  /// a tiny seated witch silhouette + trailing smoke wisp.
  ///
  /// Colours: primary = handle/broom shaft (near-black), secondary = bristles
  /// (orange), detail = witch/wisp (purple).
  static void _renderWitchBroom(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFF1A0A2E); // near-black purple
    final secondary = _secondary(colorScheme, 0xFFFF6600); // orange bristles
    final detail = _detail(colorScheme, 0xFF6B21A8); // purple witch

    final bodyShift = bankSin * 1.5;
    final cx = bodyShift;

    // A single DIAGONAL broomstick: the shaft runs from the nose (top, tilted
    // slightly right) back to a bristle fan at the rear (bottom-left). A small
    // witch rides astride it. No floating smoke worm — the shaft + bristle fan
    // are the whole silhouette.
    final tipX = cx + 5.0; // nose end of the shaft (leans right)
    const tipY = -19.0;
    final rootX = cx - 4.0; // bristle root (rear)
    const rootY = 9.0;

    // Body group (mild roll only — the broom is a side-on line).
    canvas.save();
    final rollScale = 0.72 + bankCos.abs() * 0.28;
    canvas.translate(cx, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-cx, 0);

    // --- Bristle fan at the rear (spreads from the root, pointing down-rear) ---
    const bristleCount = 7;
    const fanCentre = 2.05; // radians: down-and-left (rearward)
    const fanSpread = 0.85;
    for (var i = 0; i < bristleCount; i++) {
      final t = i / (bristleCount - 1); // 0..1
      final ang = fanCentre + (t - 0.5) * fanSpread;
      final len = 11.0 - (t - 0.5).abs() * 3.0;
      final bristleColor =
          (i < bristleCount / 2) ? secondary : _darken(secondary, 0.18);
      canvas.drawLine(
        Offset(rootX, rootY),
        Offset(rootX + cos(ang) * len, rootY + sin(ang) * len),
        Paint()
          ..color = bristleColor
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    // Binding band where the bristles are lashed to the shaft.
    canvas.drawCircle(
      Offset(rootX, rootY),
      2.4,
      Paint()..color = _darken(secondary, 0.15),
    );

    // --- Broom shaft (single tapered diagonal stick) ---
    final shaftPaint = Paint()
      ..color = primary
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(tipX, tipY), Offset(rootX, rootY), shaftPaint);
    // Slim highlight along the shaft (a little polished-wood sheen).
    canvas.drawLine(
      Offset(tipX - 0.6, tipY + 1),
      Offset(rootX - 0.6, rootY - 1),
      Paint()
        ..color = _lighten(primary, 0.5).withOpacity(0.4)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );

    // --- Witch riding astride the shaft (small hatted silhouette) ---
    final midX = (tipX + rootX) / 2 + 1.5;
    const midY = -5.0;
    // Cloaked body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(midX, midY), width: 6, height: 8),
      Paint()..color = detail,
    );
    // Head.
    canvas.drawCircle(
      Offset(midX + 0.5, midY - 4),
      1.8,
      Paint()..color = _lighten(detail, 0.4),
    );
    // Witch hat — brim + bent cone.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(midX + 0.5, midY - 5.4), width: 7, height: 2),
      Paint()..color = primary,
    );
    final hatPath = Path()
      ..moveTo(midX - 2.6, midY - 5.6)
      ..lineTo(midX + 2.6, midY - 5.6)
      ..lineTo(midX + 3.6, midY - 12) // tip bends to the side
      ..quadraticBezierTo(midX + 2, midY - 9, midX, midY - 6)
      ..close();
    _wash(canvas, hatPath, primary, seed: planeId);

    canvas.restore();
  }

  // ─── Easter Egg Express Carriage (seasonal Easter) ───────────────────

  /// Draws a rounded egg-shaped carriage with small wheels, decorated with
  /// painted-egg band accents. Viewed from the side/above; "nose" is top (−Y).
  ///
  /// Colours: primary = egg shell (pastel pink), secondary = carriage frame /
  /// wheels (pastel blue), detail = painted-egg accent stripes (pastel yellow).
  static void _renderEasterCarriage(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFFFFB6C1); // pastel pink
    final secondary = _secondary(colorScheme, 0xFFADD8E6); // pastel blue
    final detail = _detail(colorScheme, 0xFFFFFF99); // pastel yellow

    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs() * 0.9;
    final wingDip = -bankSin * 3.0;

    final leftColor =
        bankSin > 0 ? secondary : Color.lerp(secondary, Colors.black, 0.2)!;
    final rightColor =
        bankSin < 0 ? secondary : Color.lerp(secondary, Colors.black, 0.2)!;

    // --- Carriage wheels: round spoked wheels ATTACHED to the body by visible
    // axles (were flat ovals floating out at the sides). ---
    const wheelR = 4.2;
    final axlePaint = Paint()
      ..color = _darken(secondary, 0.35)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    void drawWheel(double s, Color rim) {
      final wx = s * (dynamicWingSpan * 0.5) + bodyShift;
      final wy = 9 + s * wingDip * 0.4;
      // Axle from the lower body flank to the hub.
      canvas.drawLine(Offset(bodyShift + s * 5, 8), Offset(wx, wy), axlePaint);
      // Tyre (dark rim for contrast).
      canvas.drawCircle(
          Offset(wx, wy), wheelR, Paint()..color = _darken(rim, 0.3));
      canvas.drawCircle(Offset(wx, wy), wheelR - 1.1, Paint()..color = rim);
      // Spokes.
      final spoke = Paint()
        ..color = _darken(rim, 0.35)
        ..strokeWidth = 0.7;
      for (var k = 0; k < 4; k++) {
        final a = k * pi / 4;
        canvas.drawLine(
          Offset(wx - cos(a) * (wheelR - 1.2), wy - sin(a) * (wheelR - 1.2)),
          Offset(wx + cos(a) * (wheelR - 1.2), wy + sin(a) * (wheelR - 1.2)),
          spoke,
        );
      }
      // Hub.
      canvas.drawCircle(Offset(wx, wy), 1.2, Paint()..color = detail);
    }

    drawWheel(-1, leftColor);
    drawWheel(1, rightColor);

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Egg-shaped carriage body (tall oval, pointed top, rounded base).
    final bodyPath = Path()
      ..moveTo(bodyShift, -18) // pointed top / "nose"
      ..cubicTo(
        bodyShift + 7,
        -14,
        bodyShift + 8,
        -2,
        bodyShift + 7,
        10,
      ) // right curve
      ..quadraticBezierTo(bodyShift, 16, bodyShift - 7, 10) // base curve
      ..cubicTo(
        bodyShift - 8,
        -2,
        bodyShift - 7,
        -14,
        bodyShift,
        -18,
      )
      ..close();
    _wash(canvas, bodyPath, primary, seed: planeId);
    _pencilOutline(bodyPath, canvas, primary, strokeWidth: 1.1);

    // Decorative horizontal bands (painted-egg style).
    final bandPaint = Paint()
      ..color = detail.withOpacity(0.80)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final y in [-8.0, -1.0, 6.0]) {
      // Clip bands to stay inside the egg outline — approximate with short lines.
      final halfW = (y < -12 || y > 13) ? 3.0 : (y.abs() < 4 ? 7.5 : 6.0);
      canvas.drawLine(
        Offset(bodyShift - halfW, y),
        Offset(bodyShift + halfW, y),
        bandPaint,
      );
    }

    // Secondary-colour frame ring at the equator (widest point).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift, -1),
        width: 16,
        height: 4,
      ),
      Paint()
        ..color = secondary.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Small circular window (porthole).
    canvas.drawCircle(
      Offset(bodyShift, -7),
      3.0,
      Paint()..color = secondary.withOpacity(0.6),
    );
    canvas.drawCircle(
      Offset(bodyShift, -7),
      3.0,
      Paint()
        ..color = _darken(secondary, 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    canvas.restore();
  }

  // ─── Cupid's Arrow (seasonal Valentines) ────────────────────────────

  /// Draws a large horizontal arrow travelling upward (−Y = nose), with a
  /// heart-shaped arrowhead at the front and feathered fletching at the rear.
  /// A trail of small petals/hearts streams behind.
  ///
  /// Colours: primary = arrow shaft (pink), secondary = heart tip (crimson),
  /// detail = feathers / petal trail (white).
  static void _renderCupidArrow(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFFFF69B4); // hot pink
    final secondary = _secondary(colorScheme, 0xFFDC143C); // crimson
    final detail = _detail(colorScheme, 0xFFFFFFFF); // white feathers

    final bodyShift = bankSin * 1.5;

    // --- Body group ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Arrow shaft (slim rectangle along the centreline).
    final shaftPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bodyShift, 2), width: 4, height: 34),
          const Radius.circular(2),
        ),
      );
    _wash(canvas, shaftPath, primary, seed: planeId);
    _pencilOutline(shaftPath, canvas, primary, strokeWidth: 0.8);

    // Heart-shaped arrowhead at the front/top.
    // Drawn as two overlapping circles + a triangle point below.
    final heartLeft = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(bodyShift - 2.8, -16), width: 5.6, height: 5.6));
    final heartRight = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(bodyShift + 2.8, -16), width: 5.6, height: 5.6));
    final heartPoint = Path()
      ..moveTo(bodyShift - 5, -14.5)
      ..lineTo(bodyShift, -10)
      ..lineTo(bodyShift + 5, -14.5)
      ..close();
    for (final p in [heartLeft, heartRight, heartPoint]) {
      _wash(canvas, p, secondary, seed: planeId);
    }
    _pencilOutline(
      Path()
        ..addPath(heartLeft, Offset.zero)
        ..addPath(heartRight, Offset.zero)
        ..addPath(heartPoint, Offset.zero),
      canvas,
      secondary,
      strokeWidth: 1.0,
    );

    // Tail fletching: two angled feather vanes on the shaft axis at the rear.
    // Swept back like real arrow feathers — pink barbs with a white rib — so
    // the tail reads as fletching, not stray marks.
    for (final sign in [-1.0, 1.0]) {
      final vane = Path()
        ..moveTo(bodyShift + sign * 1.4, 9) // upper attach on the shaft
        ..lineTo(bodyShift + sign * 7.5, 13) // outer leading barb
        ..lineTo(bodyShift + sign * 6.2, 20) // outer trailing barb
        ..lineTo(bodyShift + sign * 1.4, 18) // lower attach on the shaft
        ..close();
      _wash(canvas, vane, primary, seed: planeId);
      _pencilOutline(vane, canvas, _darken(primary, 0.3), strokeWidth: 0.8);
      // White quill rib down the centre of each vane.
      canvas.drawLine(
        Offset(bodyShift + sign * 1.6, 11),
        Offset(bodyShift + sign * 6.4, 16.5),
        Paint()
          ..color = detail.withOpacity(0.9)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round,
      );
    }
    // Nock at the very tail of the shaft.
    canvas.drawCircle(
        Offset(bodyShift, 19), 1.6, Paint()..color = _darken(primary, 0.35));

    canvas.restore();
  }

  // ─── Lucky Clover Copter (seasonal St Patrick's Day) ─────────────────

  /// Draws a helicopter whose rotor reads as a 4-leaf clover (four heart-leaf
  /// blades arranged in a + pattern). A small rounded cockpit sits below the
  /// rotor hub. Viewed from above, nose pointing up (−Y).
  ///
  /// Colours: primary = clover blades (green), secondary = cockpit (gold),
  /// detail = highlights / stem (white).
  static void _renderCloverCopter(
    Canvas canvas,
    double bankCos,
    double bankSin,
    double wingSpan,
    Map<String, int>? colorScheme,
    String planeId,
  ) {
    final primary = _primary(colorScheme, 0xFF228B22); // forest green
    final secondary = _secondary(colorScheme, 0xFFFFD700); // gold
    final detail = _detail(colorScheme, 0xFFFFFFFF); // white

    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs() * 1.1;
    final wingDip = -bankSin * 3.5;

    // --- 4-leaf clover rotor: four heart-lobes whose points all MEET at a
    // central hub over the pod, arranged in an X so they read as one clover
    // (was four detached green blobs). Banking darkens the descending side. ---
    final cx = bodyShift;
    final r = dynamicWingSpan * 0.30; // leaf-centre distance from the hub
    const lobe = 9.0; // lobe diameter
    const off = 2.6; // half-gap between a leaf's two lobes

    // Green stems radiating from the hub out under each leaf.
    final stemPaint = Paint()
      ..color = _darken(primary, 0.28)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Draw order: stems first, then lobes on top so they fuse at the hub.
    Path leafAt(double ang) {
      final lx = cx + cos(ang) * r;
      final ly = sin(ang) * r + wingDip * cos(ang) * 0.3;
      final px = -sin(ang); // perpendicular for the twin lobes
      final py = cos(ang);
      return Path()
        ..addOval(Rect.fromCenter(
            center: Offset(lx + px * off, ly + py * off),
            width: lobe,
            height: lobe))
        ..addOval(Rect.fromCenter(
            center: Offset(lx - px * off, ly - py * off),
            width: lobe,
            height: lobe));
    }

    // X arrangement (diagonals) keeps the tail boom clear at the bottom.
    const angles = [pi / 4, 3 * pi / 4, 5 * pi / 4, 7 * pi / 4];
    for (final ang in angles) {
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx + cos(ang) * r * 0.7, sin(ang) * r * 0.7),
        stemPaint,
      );
    }
    for (final ang in angles) {
      final leafX = cos(ang);
      final leafColor = (leafX * bankSin > 0.05)
          ? Color.lerp(primary, Colors.black, 0.22)!
          : primary;
      final leaf = leafAt(ang);
      _wash(canvas, leaf, leafColor, seed: planeId);
      _pencilOutline(leaf, canvas, leafColor, strokeWidth: 0.9);
    }

    // --- Body group (cockpit) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Cockpit body — a small rounded capsule / bubble.
    final cockpitPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(bodyShift, 0), width: 7, height: 12),
          const Radius.circular(4),
        ),
      );
    _wash(canvas, cockpitPath, secondary, seed: planeId);
    _pencilOutline(cockpitPath, canvas, secondary, strokeWidth: 1.0);

    // Rotor hub (gold disc at centre).
    canvas.drawCircle(
      Offset(bodyShift, 0),
      2.5,
      Paint()..color = secondary,
    );
    canvas.drawCircle(
      Offset(bodyShift, 0),
      1.2,
      Paint()..color = detail,
    );

    // Cockpit bubble window.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -2), width: 4.5, height: 5),
      Paint()..color = const Color(0xFF87CEEB).withOpacity(0.7),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bodyShift, -2), width: 4.5, height: 5),
      Paint()
        ..color = _darken(secondary, 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // Tail boom (slim line at the back, pointing downward/rear).
    final tailPath = Path()
      ..moveTo(bodyShift, 6)
      ..lineTo(bodyShift + 1, 15)
      ..lineTo(bodyShift - 1, 15)
      ..close();
    _wash(canvas, tailPath, secondary, seed: planeId);
    _pencilOutline(tailPath, canvas, secondary, strokeWidth: 0.8);

    // Small tail rotor disc.
    canvas.drawCircle(
      Offset(bodyShift, 15),
      2.0,
      Paint()..color = _darken(primary, 0.1),
    );

    canvas.restore();
  }
}
