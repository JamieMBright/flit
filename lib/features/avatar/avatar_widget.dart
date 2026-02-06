import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// A pixel-art avatar portrait drawn entirely on a [Canvas].
///
/// Pass an [AvatarConfig] to control every visual aspect of the character.
/// The widget sizes itself to [size] x [size] logical pixels and is safe
/// to use anywhere a square widget is expected (lists, cards, profiles).
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
  });

  /// The avatar configuration that drives every visual element.
  final AvatarConfig config;

  /// Width and height of the square avatar. Defaults to 96.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _AvatarPainter(config: config),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({required this.config});

  final AvatarConfig config;

  // ---- Skin palette ----
  static const Map<AvatarSkin, Color> _skinColors = {
    AvatarSkin.light: Color(0xFFFDE7C8),
    AvatarSkin.fair: Color(0xFFF5D0A9),
    AvatarSkin.medium: Color(0xFFD4A373),
    AvatarSkin.tan: Color(0xFFC08B5C),
    AvatarSkin.brown: Color(0xFF8D5524),
    AvatarSkin.dark: Color(0xFF5C3310),
  };

  // Skin shadow (slightly darker variant)
  static const Map<AvatarSkin, Color> _skinShadowColors = {
    AvatarSkin.light: Color(0xFFE8D0AA),
    AvatarSkin.fair: Color(0xFFDCB890),
    AvatarSkin.medium: Color(0xFFBB8C5E),
    AvatarSkin.tan: Color(0xFFA67548),
    AvatarSkin.brown: Color(0xFF744418),
    AvatarSkin.dark: Color(0xFF462808),
  };

  // ---- Hair palette ----
  static const Map<AvatarHair, Color> _hairColors = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF3B2717),
    AvatarHair.medium: Color(0xFF5A3A1A),
    AvatarHair.long: Color(0xFF1A1A1A),
    AvatarHair.mohawk: Color(0xFFD4654A),
    AvatarHair.curly: Color(0xFF3B2717),
    AvatarHair.afro: Color(0xFF1A1A1A),
    AvatarHair.ponytail: Color(0xFF5A3A1A),
  };

  // Hair highlight
  static const Map<AvatarHair, Color> _hairHighlightColors = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF5A3E28),
    AvatarHair.medium: Color(0xFF7A5A30),
    AvatarHair.long: Color(0xFF333333),
    AvatarHair.mohawk: Color(0xFFE88070),
    AvatarHair.curly: Color(0xFF5A3E28),
    AvatarHair.afro: Color(0xFF333333),
    AvatarHair.ponytail: Color(0xFF7A5A30),
  };

  // ---- Outfit palette ----
  static const Map<AvatarOutfit, Color> _outfitColors = {
    AvatarOutfit.tshirt: Color(0xFF5C7A52),
    AvatarOutfit.pilot: Color(0xFF2A5674),
    AvatarOutfit.suit: Color(0xFF1A2A32),
    AvatarOutfit.leather: Color(0xFF5A3A1A),
    AvatarOutfit.spacesuit: Color(0xFFD0D0D0),
    AvatarOutfit.captain: Color(0xFF1E3340),
  };

  static const Map<AvatarOutfit, Color> _outfitHighlightColors = {
    AvatarOutfit.tshirt: Color(0xFF7A9E6D),
    AvatarOutfit.pilot: Color(0xFF3D7A9E),
    AvatarOutfit.suit: Color(0xFF2A3A42),
    AvatarOutfit.leather: Color(0xFF7A5A30),
    AvatarOutfit.spacesuit: Color(0xFFF0F0F0),
    AvatarOutfit.captain: Color(0xFF2A4A58),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double p = s / 32; // pixel size — 32x32 grid

    // Save canvas so we can clip to a circle.
    canvas.save();
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2));
    canvas.clipPath(circlePath);

    // -- Background --
    _drawBackground(canvas, s, p);

    // -- Outfit (behind head) --
    _drawOutfit(canvas, s, p);

    // -- Neck --
    _drawNeck(canvas, s, p);

    // -- Ears --
    _drawEars(canvas, s, p);

    // -- Face --
    _drawFace(canvas, s, p);

    // -- Eyes --
    _drawEyes(canvas, s, p);

    // -- Nose + Mouth --
    _drawNoseMouth(canvas, s, p);

    // -- Glasses (over eyes) --
    _drawGlasses(canvas, s, p);

    // -- Hair --
    _drawHair(canvas, s, p);

    // -- Hat (over hair) --
    _drawHat(canvas, s, p);

    // -- Accessory --
    _drawAccessory(canvas, s, p);

    // -- Companion --
    _drawCompanion(canvas, s, p);

    canvas.restore();

    // -- Circular border --
    _drawBorder(canvas, s);
  }

  /// Draw a single pixel-art block.
  void _px(Canvas canvas, double p, double col, double row, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(col * p, row * p, p, p),
      Paint()..color = color,
    );
  }

  /// Draw a filled rectangle of pixel blocks.
  void _pxRect(Canvas canvas, double p, double col, double row, double w,
      double h, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(col * p, row * p, w * p, h * p),
      Paint()..color = color,
    );
  }

  // ---------- Background ----------

  void _drawBackground(Canvas canvas, double s, double p) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s), Paint()..color = FlitColors.backgroundDark);
    // Subtle gradient overlay for depth
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FlitColors.backgroundLight.withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
  }

  // ---------- Neck ----------

  void _drawNeck(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shadow = _skinShadowColors[config.skin]!;
    // Neck: 4px wide, 3px tall, centered
    _pxRect(canvas, p, 14, 22, 4, 3, skin);
    // Shadow on sides
    _px(canvas, p, 14, 23, shadow);
    _px(canvas, p, 17, 23, shadow);
  }

  // ---------- Ears ----------

  void _drawEars(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shadow = _skinShadowColors[config.skin]!;
    // Left ear
    _pxRect(canvas, p, 8, 14, 2, 3, skin);
    _px(canvas, p, 8, 15, shadow);
    // Right ear
    _pxRect(canvas, p, 22, 14, 2, 3, skin);
    _px(canvas, p, 23, 15, shadow);
  }

  // ---------- Face ----------

  void _drawFace(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shadow = _skinShadowColors[config.skin]!;

    switch (config.face) {
      case AvatarFace.round:
        // 12px wide round face
        _pxRect(canvas, p, 11, 10, 10, 1, skin); // top
        _pxRect(canvas, p, 10, 11, 12, 10, skin); // main block
        _pxRect(canvas, p, 11, 21, 10, 1, skin); // chin
        // Cheek shading
        _pxRect(canvas, p, 10, 17, 2, 2, shadow);
        _pxRect(canvas, p, 20, 17, 2, 2, shadow);
        // Chin shadow
        _pxRect(canvas, p, 12, 20, 8, 1, shadow);

      case AvatarFace.oval:
        // Taller, narrower face
        _pxRect(canvas, p, 12, 9, 8, 1, skin);
        _pxRect(canvas, p, 11, 10, 10, 1, skin);
        _pxRect(canvas, p, 10, 11, 12, 8, skin);
        _pxRect(canvas, p, 11, 19, 10, 2, skin);
        _pxRect(canvas, p, 12, 21, 8, 1, skin);
        _pxRect(canvas, p, 13, 22, 6, 1, skin);
        // Cheek shadow
        _pxRect(canvas, p, 10, 16, 2, 2, shadow);
        _pxRect(canvas, p, 20, 16, 2, 2, shadow);

      case AvatarFace.square:
        // Blocky face
        _pxRect(canvas, p, 10, 10, 12, 12, skin);
        // Jawline shadow
        _pxRect(canvas, p, 10, 20, 12, 1, shadow);
        _px(canvas, p, 10, 19, shadow);
        _px(canvas, p, 21, 19, shadow);

      case AvatarFace.heart:
        // Wide forehead, narrow chin
        _pxRect(canvas, p, 10, 10, 12, 1, skin);
        _pxRect(canvas, p, 10, 11, 12, 6, skin);
        _pxRect(canvas, p, 11, 17, 10, 2, skin);
        _pxRect(canvas, p, 12, 19, 8, 1, skin);
        _pxRect(canvas, p, 13, 20, 6, 1, skin);
        _pxRect(canvas, p, 14, 21, 4, 1, skin);
        // Cheek blush
        _pxRect(canvas, p, 10, 14, 2, 2, shadow);
        _pxRect(canvas, p, 20, 14, 2, 2, shadow);

      case AvatarFace.diamond:
        // Narrow top and bottom, wide middle
        _pxRect(canvas, p, 14, 9, 4, 1, skin);
        _pxRect(canvas, p, 13, 10, 6, 1, skin);
        _pxRect(canvas, p, 12, 11, 8, 1, skin);
        _pxRect(canvas, p, 11, 12, 10, 1, skin);
        _pxRect(canvas, p, 10, 13, 12, 4, skin);
        _pxRect(canvas, p, 11, 17, 10, 1, skin);
        _pxRect(canvas, p, 12, 18, 8, 1, skin);
        _pxRect(canvas, p, 13, 19, 6, 1, skin);
        _pxRect(canvas, p, 14, 20, 4, 1, skin);
        // Side shadow
        _px(canvas, p, 10, 14, shadow);
        _px(canvas, p, 21, 14, shadow);
    }
  }

  // ---------- Eyes ----------

  void _drawEyes(Canvas canvas, double s, double p) {
    const white = Color(0xFFF5F5F5);
    const pupil = Color(0xFF1A1A1A);
    const iris = Color(0xFF4A6741);

    switch (config.eyes) {
      case AvatarEyes.round:
        // Left eye: 3x3 with white, iris, pupil
        _pxRect(canvas, p, 12, 14, 3, 3, white);
        _px(canvas, p, 13, 14, iris);
        _px(canvas, p, 13, 15, pupil);
        _px(canvas, p, 12, 14, pupil); // top-left outline
        _px(canvas, p, 14, 14, pupil); // top-right outline
        // Highlight
        _px(canvas, p, 12, 14, white);
        // Right eye
        _pxRect(canvas, p, 17, 14, 3, 3, white);
        _px(canvas, p, 18, 14, iris);
        _px(canvas, p, 18, 15, pupil);
        _px(canvas, p, 17, 14, pupil);
        _px(canvas, p, 19, 14, pupil);
        _px(canvas, p, 17, 14, white);

      case AvatarEyes.almond:
        // Almond shape: 4x2
        _px(canvas, p, 12, 15, white);
        _pxRect(canvas, p, 12, 14, 4, 2, white);
        _px(canvas, p, 13, 14, iris);
        _px(canvas, p, 14, 15, pupil);
        _px(canvas, p, 13, 15, pupil);
        // Right
        _px(canvas, p, 17, 15, white);
        _pxRect(canvas, p, 17, 14, 4, 2, white);
        _px(canvas, p, 18, 14, iris);
        _px(canvas, p, 19, 15, pupil);
        _px(canvas, p, 18, 15, pupil);

      case AvatarEyes.wide:
        // Big 4x3 eyes
        _pxRect(canvas, p, 11, 13, 4, 3, white);
        _pxRect(canvas, p, 12, 14, 2, 2, iris);
        _px(canvas, p, 13, 14, pupil);
        _px(canvas, p, 11, 13, const Color(0xFF222222)); // outline
        // Right
        _pxRect(canvas, p, 17, 13, 4, 3, white);
        _pxRect(canvas, p, 18, 14, 2, 2, iris);
        _px(canvas, p, 18, 14, pupil);
        _px(canvas, p, 20, 13, const Color(0xFF222222));

      case AvatarEyes.narrow:
        // Horizontal slits: 4x1
        _pxRect(canvas, p, 12, 15, 4, 1, const Color(0xFF222222));
        _px(canvas, p, 13, 15, pupil);
        _px(canvas, p, 14, 15, pupil);
        // Right
        _pxRect(canvas, p, 17, 15, 4, 1, const Color(0xFF222222));
        _px(canvas, p, 18, 15, pupil);
        _px(canvas, p, 19, 15, pupil);

      case AvatarEyes.wink:
        // Left eye open
        _pxRect(canvas, p, 12, 14, 3, 3, white);
        _px(canvas, p, 13, 14, iris);
        _px(canvas, p, 13, 15, pupil);
        _px(canvas, p, 12, 14, white);
        // Right eye winking (^)
        _px(canvas, p, 17, 15, const Color(0xFF222222));
        _px(canvas, p, 18, 14, const Color(0xFF222222));
        _px(canvas, p, 19, 15, const Color(0xFF222222));
    }
  }

  // ---------- Nose + Mouth ----------

  void _drawNoseMouth(Canvas canvas, double s, double p) {
    final shadow = _skinShadowColors[config.skin]!;
    // Nose: 2 pixels
    _px(canvas, p, 15, 17, shadow);
    _px(canvas, p, 16, 17, shadow);
    // Mouth: small line
    _pxRect(canvas, p, 14, 19, 4, 1, shadow);
    // Lip highlight
    _px(canvas, p, 15, 19, const Color(0xFFCC6666));
    _px(canvas, p, 16, 19, const Color(0xFFCC6666));
  }

  // ---------- Hair ----------

  void _drawHair(Canvas canvas, double s, double p) {
    if (config.hair == AvatarHair.none) return;

    final hair = _hairColors[config.hair]!;
    final highlight = _hairHighlightColors[config.hair]!;

    switch (config.hair) {
      case AvatarHair.none:
        break;

      case AvatarHair.short:
        // Flat top hair
        _pxRect(canvas, p, 10, 8, 12, 3, hair);
        _pxRect(canvas, p, 9, 10, 2, 3, hair);
        _pxRect(canvas, p, 21, 10, 2, 3, hair);
        // Highlight on top
        _pxRect(canvas, p, 12, 8, 4, 1, highlight);

      case AvatarHair.medium:
        // Side-parted
        _pxRect(canvas, p, 10, 7, 12, 4, hair);
        _pxRect(canvas, p, 9, 10, 2, 6, hair);
        _pxRect(canvas, p, 21, 10, 2, 6, hair);
        // Part line
        _pxRect(canvas, p, 13, 7, 1, 3, highlight);
        // Highlight
        _pxRect(canvas, p, 14, 7, 4, 1, highlight);

      case AvatarHair.long:
        // Long flowing hair
        _pxRect(canvas, p, 10, 7, 12, 4, hair);
        _pxRect(canvas, p, 8, 10, 3, 12, hair);
        _pxRect(canvas, p, 21, 10, 3, 12, hair);
        // Top highlight
        _pxRect(canvas, p, 12, 7, 6, 1, highlight);
        // Side strands
        _pxRect(canvas, p, 8, 18, 2, 4, highlight);
        _pxRect(canvas, p, 22, 18, 2, 4, highlight);

      case AvatarHair.mohawk:
        // Tall strip
        _pxRect(canvas, p, 14, 3, 4, 8, hair);
        _pxRect(canvas, p, 13, 5, 1, 4, hair);
        _pxRect(canvas, p, 18, 5, 1, 4, hair);
        // Highlight
        _pxRect(canvas, p, 15, 3, 2, 2, highlight);

      case AvatarHair.curly:
        // Curly clusters on top and sides
        _pxRect(canvas, p, 10, 7, 12, 4, hair);
        // Curl bumps on top
        _px(canvas, p, 11, 6, hair);
        _px(canvas, p, 13, 5, hair);
        _px(canvas, p, 15, 6, hair);
        _px(canvas, p, 17, 5, hair);
        _px(canvas, p, 19, 6, hair);
        _px(canvas, p, 21, 7, hair);
        // Side curls
        _pxRect(canvas, p, 9, 10, 2, 5, hair);
        _pxRect(canvas, p, 21, 10, 2, 5, hair);
        _px(canvas, p, 8, 12, hair);
        _px(canvas, p, 23, 12, hair);
        // Highlights
        _px(canvas, p, 13, 6, highlight);
        _px(canvas, p, 17, 6, highlight);

      case AvatarHair.afro:
        // Big round afro
        _pxRect(canvas, p, 10, 4, 12, 2, hair);
        _pxRect(canvas, p, 8, 6, 16, 6, hair);
        _pxRect(canvas, p, 7, 8, 2, 8, hair);
        _pxRect(canvas, p, 23, 8, 2, 8, hair);
        _pxRect(canvas, p, 9, 12, 2, 4, hair);
        _pxRect(canvas, p, 21, 12, 2, 4, hair);
        // Highlights
        _pxRect(canvas, p, 12, 4, 4, 1, highlight);
        _pxRect(canvas, p, 10, 6, 2, 2, highlight);
        _pxRect(canvas, p, 20, 6, 2, 2, highlight);

      case AvatarHair.ponytail:
        // Top + ponytail to right
        _pxRect(canvas, p, 10, 7, 12, 4, hair);
        _pxRect(canvas, p, 9, 10, 2, 3, hair);
        // Ponytail band
        _pxRect(canvas, p, 22, 10, 2, 2, const Color(0xFFCC4444));
        // Ponytail flowing
        _pxRect(canvas, p, 23, 11, 3, 2, hair);
        _pxRect(canvas, p, 24, 13, 3, 2, hair);
        _pxRect(canvas, p, 25, 15, 2, 3, hair);
        _pxRect(canvas, p, 24, 18, 2, 2, hair);
        // Highlight
        _pxRect(canvas, p, 12, 7, 4, 1, highlight);
        _px(canvas, p, 25, 14, highlight);
    }
  }

  // ---------- Outfit ----------

  void _drawOutfit(Canvas canvas, double s, double p) {
    final color = _outfitColors[config.outfit]!;
    final hl = _outfitHighlightColors[config.outfit]!;

    // Base torso/shoulders visible below the chin
    _pxRect(canvas, p, 6, 24, 20, 8, color);
    // Shoulder curve
    _pxRect(canvas, p, 4, 25, 2, 7, color);
    _pxRect(canvas, p, 26, 25, 2, 7, color);
    _pxRect(canvas, p, 3, 27, 1, 5, color);
    _pxRect(canvas, p, 28, 27, 1, 5, color);

    // Collar / neckline highlight
    _pxRect(canvas, p, 13, 24, 6, 1, hl);

    switch (config.outfit) {
      case AvatarOutfit.tshirt:
        // Simple round neckline
        _pxRect(canvas, p, 14, 23, 4, 1, hl);

      case AvatarOutfit.pilot:
        // Lapels
        _pxRect(canvas, p, 12, 25, 2, 3, FlitColors.gold);
        _pxRect(canvas, p, 18, 25, 2, 3, FlitColors.gold);
        // Epaulettes
        _pxRect(canvas, p, 6, 24, 3, 1, FlitColors.gold);
        _pxRect(canvas, p, 23, 24, 3, 1, FlitColors.gold);

      case AvatarOutfit.suit:
        // V-shaped lapel
        _px(canvas, p, 14, 24, hl);
        _px(canvas, p, 13, 25, hl);
        _px(canvas, p, 12, 26, hl);
        _px(canvas, p, 17, 24, hl);
        _px(canvas, p, 18, 25, hl);
        _px(canvas, p, 19, 26, hl);
        // Tie
        _px(canvas, p, 15, 25, FlitColors.accent);
        _px(canvas, p, 16, 25, FlitColors.accent);
        _pxRect(canvas, p, 15, 26, 2, 4, FlitColors.accent);

      case AvatarOutfit.leather:
        // Zip line
        _pxRect(canvas, p, 16, 24, 1, 8, const Color(0xFF888888));
        // Collar flap
        _pxRect(canvas, p, 12, 24, 3, 2, hl);
        _pxRect(canvas, p, 17, 24, 3, 2, hl);

      case AvatarOutfit.spacesuit:
        // Helmet collar ring
        _pxRect(canvas, p, 11, 23, 10, 1, const Color(0xFF999999));
        _pxRect(canvas, p, 11, 24, 1, 1, const Color(0xFF999999));
        _pxRect(canvas, p, 20, 24, 1, 1, const Color(0xFF999999));
        // Chest panel
        _pxRect(canvas, p, 14, 26, 4, 3, const Color(0xFF4A90B8));

      case AvatarOutfit.captain:
        // Double buttons
        for (var i = 0; i < 3; i++) {
          _px(canvas, p, 14, 25 + i.toDouble() * 2, FlitColors.gold);
          _px(canvas, p, 17, 25 + i.toDouble() * 2, FlitColors.gold);
        }
        // Shoulder stripes
        _pxRect(canvas, p, 5, 25, 4, 1, FlitColors.gold);
        _pxRect(canvas, p, 23, 25, 4, 1, FlitColors.gold);
    }
  }

  // ---------- Hat ----------

  void _drawHat(Canvas canvas, double s, double p) {
    if (config.hat == AvatarHat.none) return;

    switch (config.hat) {
      case AvatarHat.none:
        break;

      case AvatarHat.cap:
        // Baseball cap
        _pxRect(canvas, p, 9, 7, 14, 3, FlitColors.accent);
        _pxRect(canvas, p, 10, 6, 12, 1, FlitColors.accent);
        // Brim
        _pxRect(canvas, p, 7, 10, 14, 1, FlitColors.accent);
        _pxRect(canvas, p, 6, 10, 1, 1, FlitColors.accentDark);
        // Highlight
        _pxRect(canvas, p, 12, 6, 4, 1, FlitColors.accentLight);
        // Button on top
        _px(canvas, p, 15, 6, FlitColors.accentLight);

      case AvatarHat.aviator:
        // Leather aviator cap
        const leather = Color(0xFF5A3A1A);
        const leatherHl = Color(0xFF7A5A30);
        _pxRect(canvas, p, 10, 7, 12, 4, leather);
        _pxRect(canvas, p, 9, 9, 1, 3, leather);
        _pxRect(canvas, p, 22, 9, 1, 3, leather);
        // Ear flaps
        _pxRect(canvas, p, 8, 11, 2, 5, leather);
        _pxRect(canvas, p, 22, 11, 2, 5, leather);
        // Goggles strap
        _pxRect(canvas, p, 10, 10, 12, 1, FlitColors.gold);
        // Goggles
        _pxRect(canvas, p, 11, 9, 3, 2, const Color(0xFF4A90B8));
        _pxRect(canvas, p, 18, 9, 3, 2, const Color(0xFF4A90B8));
        // Highlight
        _pxRect(canvas, p, 12, 7, 4, 1, leatherHl);

      case AvatarHat.tophat:
        const hatColor = Color(0xFF1A1A1A);
        // Brim
        _pxRect(canvas, p, 8, 8, 16, 1, hatColor);
        // Crown
        _pxRect(canvas, p, 11, 2, 10, 6, hatColor);
        _pxRect(canvas, p, 10, 3, 12, 4, hatColor);
        // Band
        _pxRect(canvas, p, 11, 6, 10, 1, FlitColors.accent);
        // Highlight
        _pxRect(canvas, p, 12, 3, 2, 1, const Color(0xFF333333));

      case AvatarHat.crown:
        // Crown base
        _pxRect(canvas, p, 10, 7, 12, 2, FlitColors.gold);
        // Crown points
        _px(canvas, p, 10, 5, FlitColors.gold);
        _px(canvas, p, 10, 6, FlitColors.gold);
        _px(canvas, p, 13, 4, FlitColors.gold);
        _px(canvas, p, 13, 5, FlitColors.gold);
        _px(canvas, p, 13, 6, FlitColors.gold);
        _px(canvas, p, 16, 3, FlitColors.gold);
        _px(canvas, p, 15, 4, FlitColors.gold);
        _px(canvas, p, 16, 4, FlitColors.gold);
        _px(canvas, p, 16, 5, FlitColors.gold);
        _px(canvas, p, 16, 6, FlitColors.gold);
        _px(canvas, p, 19, 4, FlitColors.gold);
        _px(canvas, p, 19, 5, FlitColors.gold);
        _px(canvas, p, 19, 6, FlitColors.gold);
        _px(canvas, p, 21, 5, FlitColors.gold);
        _px(canvas, p, 21, 6, FlitColors.gold);
        // Jewels
        _px(canvas, p, 13, 5, FlitColors.accent);
        _px(canvas, p, 16, 4, const Color(0xFF4A90B8));
        _px(canvas, p, 19, 5, FlitColors.accent);
        // Band
        _pxRect(canvas, p, 10, 8, 12, 1, FlitColors.goldLight);

      case AvatarHat.helmet:
        const helm = Color(0xFF606060);
        const helmHl = Color(0xFF808080);
        // Dome
        _pxRect(canvas, p, 10, 5, 12, 6, helm);
        _pxRect(canvas, p, 9, 7, 1, 4, helm);
        _pxRect(canvas, p, 22, 7, 1, 4, helm);
        // Visor slit
        _pxRect(canvas, p, 11, 10, 10, 1, const Color(0xFF333333));
        // Center stripe
        _pxRect(canvas, p, 15, 5, 2, 5, FlitColors.accent);
        // Highlight
        _pxRect(canvas, p, 11, 6, 3, 1, helmHl);
    }
  }

  // ---------- Glasses ----------

  void _drawGlasses(Canvas canvas, double s, double p) {
    if (config.glasses == AvatarGlasses.none) return;

    switch (config.glasses) {
      case AvatarGlasses.none:
        break;

      case AvatarGlasses.round:
        const frame = Color(0xFF222222);
        // Left lens circle
        _pxRect(canvas, p, 11, 13, 5, 1, frame);
        _px(canvas, p, 11, 14, frame);
        _px(canvas, p, 15, 14, frame);
        _px(canvas, p, 11, 15, frame);
        _px(canvas, p, 15, 15, frame);
        _pxRect(canvas, p, 11, 16, 5, 1, frame);
        // Right lens circle
        _pxRect(canvas, p, 16, 13, 5, 1, frame);
        _px(canvas, p, 16, 14, frame);
        _px(canvas, p, 20, 14, frame);
        _px(canvas, p, 16, 15, frame);
        _px(canvas, p, 20, 15, frame);
        _pxRect(canvas, p, 16, 16, 5, 1, frame);
        // Bridge
        _px(canvas, p, 15, 14, frame);
        _px(canvas, p, 16, 14, frame);
        // Arms
        _px(canvas, p, 10, 14, frame);
        _px(canvas, p, 21, 14, frame);

      case AvatarGlasses.aviator:
        // Gold frame aviator glasses
        const frame = Color(0xFFD4A944);
        const lens = Color(0x404A90B8);
        // Left lens (teardrop-ish)
        _pxRect(canvas, p, 11, 13, 5, 4, lens);
        _pxRect(canvas, p, 11, 13, 5, 1, frame);
        _px(canvas, p, 11, 14, frame);
        _px(canvas, p, 15, 14, frame);
        _px(canvas, p, 11, 15, frame);
        _px(canvas, p, 15, 15, frame);
        _pxRect(canvas, p, 11, 16, 5, 1, frame);
        // Right lens
        _pxRect(canvas, p, 17, 13, 5, 4, lens);
        _pxRect(canvas, p, 17, 13, 5, 1, frame);
        _px(canvas, p, 17, 14, frame);
        _px(canvas, p, 21, 14, frame);
        _px(canvas, p, 17, 15, frame);
        _px(canvas, p, 21, 15, frame);
        _pxRect(canvas, p, 17, 16, 5, 1, frame);
        // Bridge
        _pxRect(canvas, p, 15, 14, 2, 1, frame);
        // Arms
        _px(canvas, p, 10, 14, frame);
        _px(canvas, p, 22, 14, frame);

      case AvatarGlasses.monocle:
        const frame = Color(0xFFD4A944);
        // Single lens on right eye
        _pxRect(canvas, p, 17, 13, 4, 1, frame);
        _px(canvas, p, 17, 14, frame);
        _px(canvas, p, 20, 14, frame);
        _px(canvas, p, 17, 15, frame);
        _px(canvas, p, 20, 15, frame);
        _pxRect(canvas, p, 17, 16, 4, 1, frame);
        // Chain
        _px(canvas, p, 19, 17, frame);
        _px(canvas, p, 18, 18, frame);
        _px(canvas, p, 17, 19, frame);
        _px(canvas, p, 16, 20, frame);

      case AvatarGlasses.futuristic:
        const frame = Color(0xFF4A90B8);
        const lens = Color(0x604A90B8);
        // Single visor band
        _pxRect(canvas, p, 10, 13, 12, 3, lens);
        _pxRect(canvas, p, 10, 13, 12, 1, frame);
        _pxRect(canvas, p, 10, 15, 12, 1, frame);
        _px(canvas, p, 10, 14, frame);
        _px(canvas, p, 21, 14, frame);
        // Arms
        _px(canvas, p, 9, 14, frame);
        _px(canvas, p, 22, 14, frame);
    }
  }

  // ---------- Accessory ----------

  void _drawAccessory(Canvas canvas, double s, double p) {
    if (config.accessory == AvatarAccessory.none) return;

    switch (config.accessory) {
      case AvatarAccessory.none:
        break;

      case AvatarAccessory.scarf:
        // Wrapped scarf
        _pxRect(canvas, p, 10, 22, 12, 2, FlitColors.accent);
        _pxRect(canvas, p, 11, 23, 10, 1, FlitColors.accentLight);
        // Hanging end
        _pxRect(canvas, p, 18, 24, 2, 4, FlitColors.accent);
        _pxRect(canvas, p, 19, 24, 1, 4, FlitColors.accentLight);
        // Stripe
        _pxRect(canvas, p, 18, 26, 2, 1, FlitColors.accentDark);

      case AvatarAccessory.medal:
        // Ribbon
        _px(canvas, p, 15, 26, FlitColors.accent);
        _px(canvas, p, 16, 26, FlitColors.accent);
        _pxRect(canvas, p, 15, 27, 2, 2, FlitColors.accent);
        // Medal
        _pxRect(canvas, p, 14, 29, 4, 2, FlitColors.gold);
        _pxRect(canvas, p, 15, 29, 2, 2, FlitColors.goldLight);

      case AvatarAccessory.earring:
        // Small gold earring on left ear
        _px(canvas, p, 8, 16, FlitColors.gold);
        _px(canvas, p, 8, 17, FlitColors.goldLight);

      case AvatarAccessory.goldChain:
        // Chain arc across chest
        _px(canvas, p, 11, 26, FlitColors.gold);
        _px(canvas, p, 12, 27, FlitColors.gold);
        _px(canvas, p, 13, 28, FlitColors.gold);
        _px(canvas, p, 14, 28, FlitColors.goldLight);
        _px(canvas, p, 15, 29, FlitColors.goldLight);
        _px(canvas, p, 16, 29, FlitColors.gold);
        _px(canvas, p, 17, 28, FlitColors.goldLight);
        _px(canvas, p, 18, 28, FlitColors.gold);
        _px(canvas, p, 19, 27, FlitColors.gold);
        _px(canvas, p, 20, 26, FlitColors.gold);
        // Pendant
        _pxRect(canvas, p, 15, 30, 2, 1, FlitColors.gold);

      case AvatarAccessory.parrot:
        // Small pixel parrot on right shoulder
        const green = Color(0xFF2ECC40);
        const greenDark = Color(0xFF1FA030);
        const beak = Color(0xFFD4A944);
        // Body
        _pxRect(canvas, p, 24, 22, 3, 3, green);
        _pxRect(canvas, p, 25, 21, 2, 1, green);
        // Head
        _pxRect(canvas, p, 26, 20, 2, 2, green);
        // Eye
        _px(canvas, p, 27, 20, const Color(0xFF1A1A1A));
        // Beak
        _px(canvas, p, 28, 21, beak);
        // Wing
        _px(canvas, p, 24, 23, greenDark);
        // Tail
        _px(canvas, p, 23, 25, FlitColors.accent);
        _px(canvas, p, 24, 25, green);
    }
  }

  // ---------- Companion ----------

  void _drawCompanion(Canvas canvas, double s, double p) {
    if (config.companion == AvatarCompanion.none) return;

    // Companions drawn in bottom-right corner of the portrait
    switch (config.companion) {
      case AvatarCompanion.none:
        break;

      case AvatarCompanion.sparrow:
        // Small brown sparrow
        const body = Color(0xFF8B6914);
        const belly = Color(0xFFD4A944);
        const beak = Color(0xFFCC8800);
        // Body
        _pxRect(canvas, p, 24, 27, 3, 2, body);
        _pxRect(canvas, p, 25, 26, 2, 1, body);
        // Belly
        _px(canvas, p, 25, 28, belly);
        // Head
        _pxRect(canvas, p, 26, 25, 2, 2, body);
        // Eye
        _px(canvas, p, 27, 25, const Color(0xFF1A1A1A));
        // Beak
        _px(canvas, p, 28, 26, beak);
        // Wing
        _px(canvas, p, 24, 27, const Color(0xFF6B4E10));
        // Tail
        _px(canvas, p, 23, 27, body);

      case AvatarCompanion.eagle:
        // Majestic eagle
        const body = Color(0xFF4A3520);
        const head = Color(0xFFF0E8DC);
        const beak = Color(0xFFD4A944);
        // Body
        _pxRect(canvas, p, 23, 27, 4, 3, body);
        _pxRect(canvas, p, 22, 28, 1, 2, body);
        // Wings spread
        _px(canvas, p, 21, 27, body);
        _px(canvas, p, 28, 27, body);
        // Head (white)
        _pxRect(canvas, p, 25, 25, 2, 2, head);
        // Eye
        _px(canvas, p, 26, 25, const Color(0xFF1A1A1A));
        // Beak
        _px(canvas, p, 27, 26, beak);
        _px(canvas, p, 28, 26, beak);

      case AvatarCompanion.parrot:
        // Colorful parrot
        const green = Color(0xFF2ECC40);
        const red = Color(0xFFCC4444);
        const blue = Color(0xFF4A90B8);
        const beak = Color(0xFFD4A944);
        // Body
        _pxRect(canvas, p, 23, 27, 3, 3, green);
        // Head
        _pxRect(canvas, p, 25, 25, 2, 2, green);
        // Eye
        _px(canvas, p, 26, 25, const Color(0xFF1A1A1A));
        // Beak
        _px(canvas, p, 27, 26, beak);
        // Wing
        _pxRect(canvas, p, 22, 28, 2, 2, blue);
        // Tail
        _px(canvas, p, 22, 30, red);
        _px(canvas, p, 23, 30, green);
        _px(canvas, p, 24, 30, blue);
        // Head crest
        _px(canvas, p, 25, 24, red);
        _px(canvas, p, 26, 24, red);

      case AvatarCompanion.phoenix:
        // Fiery phoenix
        const flame = Color(0xFFE88020);
        const flameLight = Color(0xFFFFCC44);
        const body = Color(0xFFCC4422);
        // Body
        _pxRect(canvas, p, 23, 26, 4, 3, body);
        // Wings (fire-like)
        _pxRect(canvas, p, 21, 25, 2, 3, flame);
        _pxRect(canvas, p, 27, 25, 2, 3, flame);
        _px(canvas, p, 20, 26, flameLight);
        _px(canvas, p, 29, 26, flameLight);
        // Head
        _pxRect(canvas, p, 25, 24, 2, 2, body);
        // Eye
        _px(canvas, p, 26, 24, flameLight);
        // Beak
        _px(canvas, p, 27, 25, FlitColors.gold);
        // Tail fire
        _px(canvas, p, 22, 29, flame);
        _px(canvas, p, 23, 30, flameLight);
        _px(canvas, p, 24, 29, flame);
        // Head plume
        _px(canvas, p, 25, 23, flame);
        _px(canvas, p, 26, 23, flameLight);

      case AvatarCompanion.dragon:
        // Mini dragon
        const bodyColor = Color(0xFF2A5674);
        const belly = Color(0xFF3D7A9E);
        const wing = Color(0xFF1E3340);
        // Body
        _pxRect(canvas, p, 22, 26, 5, 3, bodyColor);
        _pxRect(canvas, p, 23, 28, 3, 1, belly);
        // Head
        _pxRect(canvas, p, 26, 24, 3, 3, bodyColor);
        _px(canvas, p, 27, 25, belly);
        // Eye
        _px(canvas, p, 28, 24, FlitColors.accent);
        // Horns
        _px(canvas, p, 26, 23, bodyColor);
        _px(canvas, p, 28, 23, bodyColor);
        // Wings
        _pxRect(canvas, p, 23, 24, 3, 2, wing);
        _px(canvas, p, 22, 25, wing);
        _px(canvas, p, 21, 24, wing);
        // Tail
        _px(canvas, p, 21, 27, bodyColor);
        _px(canvas, p, 20, 28, bodyColor);
        _px(canvas, p, 19, 28, bodyColor);
        // Fire breath
        _px(canvas, p, 29, 25, FlitColors.accent);
        _px(canvas, p, 30, 25, const Color(0xFFE88020));
    }
  }

  // ---------- Circular border ----------

  void _drawBorder(Canvas canvas, double s) {
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s / 2 - 1,
      Paint()
        ..color = FlitColors.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      config != oldDelegate.config;
}
