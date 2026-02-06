import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// A pixel-art avatar portrait drawn entirely on a [Canvas].
///
/// Uses a 64x64 pixel grid for detailed pixel-art portraits.
/// Pass an [AvatarConfig] to control every visual aspect of the character.
/// The widget sizes itself to [size] x [size] logical pixels and is safe
/// to use anywhere a square widget is expected (lists, cards, profiles).
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
  });

  final AvatarConfig config;
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
// Painter — 64x64 pixel grid
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

  static const Map<AvatarSkin, Color> _skinShadow = {
    AvatarSkin.light: Color(0xFFE8D0AA),
    AvatarSkin.fair: Color(0xFFDCB890),
    AvatarSkin.medium: Color(0xFFBB8C5E),
    AvatarSkin.tan: Color(0xFFA67548),
    AvatarSkin.brown: Color(0xFF744418),
    AvatarSkin.dark: Color(0xFF462808),
  };

  static const Map<AvatarSkin, Color> _skinHighlight = {
    AvatarSkin.light: Color(0xFFFFF0DC),
    AvatarSkin.fair: Color(0xFFFDE0C0),
    AvatarSkin.medium: Color(0xFFE0B888),
    AvatarSkin.tan: Color(0xFFD4A070),
    AvatarSkin.brown: Color(0xFFA06830),
    AvatarSkin.dark: Color(0xFF6E3E18),
  };

  // ---- Hair palette ----
  static const Map<AvatarHair, Color> _hairBase = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF3B2717),
    AvatarHair.medium: Color(0xFF5A3A1A),
    AvatarHair.long: Color(0xFF1A1A1A),
    AvatarHair.mohawk: Color(0xFFD4654A),
    AvatarHair.curly: Color(0xFF3B2717),
    AvatarHair.afro: Color(0xFF1A1A1A),
    AvatarHair.ponytail: Color(0xFF5A3A1A),
  };

  static const Map<AvatarHair, Color> _hairLight = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF5A3E28),
    AvatarHair.medium: Color(0xFF7A5A30),
    AvatarHair.long: Color(0xFF333333),
    AvatarHair.mohawk: Color(0xFFE88070),
    AvatarHair.curly: Color(0xFF5A3E28),
    AvatarHair.afro: Color(0xFF333333),
    AvatarHair.ponytail: Color(0xFF7A5A30),
  };

  static const Map<AvatarHair, Color> _hairDark = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF2A1A0C),
    AvatarHair.medium: Color(0xFF3E2810),
    AvatarHair.long: Color(0xFF0E0E0E),
    AvatarHair.mohawk: Color(0xFFB04030),
    AvatarHair.curly: Color(0xFF2A1A0C),
    AvatarHair.afro: Color(0xFF0E0E0E),
    AvatarHair.ponytail: Color(0xFF3E2810),
  };

  // ---- Outfit palette ----
  static const Map<AvatarOutfit, Color> _outfitBase = {
    AvatarOutfit.tshirt: Color(0xFF5C7A52),
    AvatarOutfit.pilot: Color(0xFF2A5674),
    AvatarOutfit.suit: Color(0xFF1A2A32),
    AvatarOutfit.leather: Color(0xFF5A3A1A),
    AvatarOutfit.spacesuit: Color(0xFFD0D0D0),
    AvatarOutfit.captain: Color(0xFF1E3340),
  };

  static const Map<AvatarOutfit, Color> _outfitLight = {
    AvatarOutfit.tshirt: Color(0xFF7A9E6D),
    AvatarOutfit.pilot: Color(0xFF3D7A9E),
    AvatarOutfit.suit: Color(0xFF2A3A42),
    AvatarOutfit.leather: Color(0xFF7A5A30),
    AvatarOutfit.spacesuit: Color(0xFFF0F0F0),
    AvatarOutfit.captain: Color(0xFF2A4A58),
  };

  static const Map<AvatarOutfit, Color> _outfitDark = {
    AvatarOutfit.tshirt: Color(0xFF4A6438),
    AvatarOutfit.pilot: Color(0xFF1E4050),
    AvatarOutfit.suit: Color(0xFF101820),
    AvatarOutfit.leather: Color(0xFF3E2810),
    AvatarOutfit.spacesuit: Color(0xFFB0B0B0),
    AvatarOutfit.captain: Color(0xFF142028),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double p = s / 64; // pixel unit — 64x64 grid

    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2)));

    _drawBackground(canvas, s, p);
    _drawOutfit(canvas, s, p);
    _drawNeck(canvas, s, p);
    _drawEars(canvas, s, p);
    _drawFace(canvas, s, p);
    _drawEyebrows(canvas, s, p);
    _drawEyes(canvas, s, p);
    _drawNose(canvas, s, p);
    _drawMouth(canvas, s, p);
    _drawGlasses(canvas, s, p);
    _drawHair(canvas, s, p);
    _drawHat(canvas, s, p);
    _drawAccessory(canvas, s, p);
    _drawCompanion(canvas, s, p);

    canvas.restore();

    _drawBorder(canvas, s);
  }

  // -- Helpers --

  void _px(Canvas c, double p, double x, double y, Color color) {
    c.drawRect(Rect.fromLTWH(x * p, y * p, p, p), Paint()..color = color);
  }

  void _rect(Canvas c, double p, double x, double y, double w, double h,
      Color color) {
    c.drawRect(
        Rect.fromLTWH(x * p, y * p, w * p, h * p), Paint()..color = color);
  }

  // Horizontal line of pixels
  void _hline(Canvas c, double p, double x, double y, double w, Color color) {
    _rect(c, p, x, y, w, 1, color);
  }

  // ---------- Background ----------

  void _drawBackground(Canvas canvas, double s, double p) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s), Paint()..color = FlitColors.backgroundDark);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s * 0.6),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FlitColors.backgroundLight.withOpacity(0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, s, s * 0.6)),
    );
  }

  // ---------- Neck ----------

  void _drawNeck(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shd = _skinShadow[config.skin]!;
    // Neck: 8px wide, 5px tall
    _rect(canvas, p, 28, 44, 8, 5, skin);
    // Shadow edges
    _rect(canvas, p, 28, 46, 2, 3, shd);
    _rect(canvas, p, 34, 46, 2, 3, shd);
  }

  // ---------- Ears ----------

  void _drawEars(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shd = _skinShadow[config.skin]!;
    final hl = _skinHighlight[config.skin]!;
    // Left ear
    _rect(canvas, p, 16, 28, 3, 6, skin);
    _rect(canvas, p, 17, 30, 1, 2, shd);
    _px(canvas, p, 16, 28, hl);
    // Right ear
    _rect(canvas, p, 45, 28, 3, 6, skin);
    _rect(canvas, p, 46, 30, 1, 2, shd);
    _px(canvas, p, 47, 28, hl);
  }

  // ---------- Face ----------

  void _drawFace(Canvas canvas, double s, double p) {
    final skin = _skinColors[config.skin]!;
    final shd = _skinShadow[config.skin]!;
    final hl = _skinHighlight[config.skin]!;

    switch (config.face) {
      case AvatarFace.round:
        _hline(canvas, p, 22, 19, 20, skin);
        _hline(canvas, p, 21, 20, 22, skin);
        _rect(canvas, p, 20, 21, 24, 18, skin);
        _hline(canvas, p, 21, 39, 22, skin);
        _hline(canvas, p, 22, 40, 20, skin);
        _hline(canvas, p, 23, 41, 18, skin);
        _hline(canvas, p, 25, 42, 14, skin);
        _hline(canvas, p, 27, 43, 10, skin);
        // Cheek shadow
        _rect(canvas, p, 20, 33, 3, 4, shd);
        _rect(canvas, p, 41, 33, 3, 4, shd);
        // Cheek blush
        _rect(canvas, p, 21, 34, 2, 2, const Color(0x20E88080));
        _rect(canvas, p, 41, 34, 2, 2, const Color(0x20E88080));
        // Highlight on forehead
        _rect(canvas, p, 28, 20, 8, 2, hl);
        // Chin shadow
        _hline(canvas, p, 25, 41, 14, shd);

      case AvatarFace.oval:
        _hline(canvas, p, 24, 17, 16, skin);
        _hline(canvas, p, 23, 18, 18, skin);
        _hline(canvas, p, 22, 19, 20, skin);
        _rect(canvas, p, 21, 20, 22, 16, skin);
        _rect(canvas, p, 22, 36, 20, 3, skin);
        _hline(canvas, p, 23, 39, 18, skin);
        _hline(canvas, p, 24, 40, 16, skin);
        _hline(canvas, p, 25, 41, 14, skin);
        _hline(canvas, p, 26, 42, 12, skin);
        _hline(canvas, p, 27, 43, 10, skin);
        _hline(canvas, p, 28, 44, 8, skin);
        // Cheek shadow
        _rect(canvas, p, 21, 32, 3, 4, shd);
        _rect(canvas, p, 40, 32, 3, 4, shd);
        // Forehead highlight
        _rect(canvas, p, 28, 18, 8, 2, hl);
        // Chin
        _hline(canvas, p, 26, 42, 12, shd);

      case AvatarFace.square:
        _rect(canvas, p, 20, 19, 24, 24, skin);
        _hline(canvas, p, 21, 18, 22, skin);
        // Jaw shadow
        _rect(canvas, p, 20, 39, 24, 2, shd);
        _rect(canvas, p, 20, 37, 2, 2, shd);
        _rect(canvas, p, 42, 37, 2, 2, shd);
        // Forehead hl
        _rect(canvas, p, 27, 19, 10, 2, hl);

      case AvatarFace.heart:
        _hline(canvas, p, 20, 19, 24, skin);
        _rect(canvas, p, 19, 20, 26, 12, skin);
        _rect(canvas, p, 20, 32, 24, 4, skin);
        _rect(canvas, p, 21, 36, 22, 2, skin);
        _rect(canvas, p, 23, 38, 18, 2, skin);
        _rect(canvas, p, 25, 40, 14, 1, skin);
        _rect(canvas, p, 27, 41, 10, 1, skin);
        _rect(canvas, p, 28, 42, 8, 1, skin);
        _rect(canvas, p, 29, 43, 6, 1, skin);
        // Cheek shadow
        _rect(canvas, p, 19, 26, 3, 4, shd);
        _rect(canvas, p, 42, 26, 3, 4, shd);
        // Forehead hl
        _rect(canvas, p, 27, 20, 10, 2, hl);
        // Chin
        _hline(canvas, p, 27, 41, 10, shd);

      case AvatarFace.diamond:
        _hline(canvas, p, 28, 17, 8, skin);
        _hline(canvas, p, 26, 18, 12, skin);
        _hline(canvas, p, 24, 19, 16, skin);
        _hline(canvas, p, 22, 20, 20, skin);
        _rect(canvas, p, 20, 21, 24, 6, skin);
        _rect(canvas, p, 19, 27, 26, 6, skin);
        _rect(canvas, p, 20, 33, 24, 3, skin);
        _hline(canvas, p, 22, 36, 20, skin);
        _hline(canvas, p, 24, 37, 16, skin);
        _hline(canvas, p, 26, 38, 12, skin);
        _hline(canvas, p, 28, 39, 8, skin);
        _hline(canvas, p, 29, 40, 6, skin);
        // Side shadow
        _rect(canvas, p, 19, 28, 2, 4, shd);
        _rect(canvas, p, 43, 28, 2, 4, shd);
        // Forehead
        _rect(canvas, p, 29, 18, 6, 2, hl);
    }
  }

  // ---------- Eyebrows ----------

  void _drawEyebrows(Canvas canvas, double s, double p) {
    final dark = _skinShadow[config.skin]!;
    final isFeminine = config.bodyType == AvatarBodyType.feminine;

    if (isFeminine) {
      // Thinner, arched brows
      _hline(canvas, p, 24, 26, 5, dark);
      _px(canvas, p, 23, 27, dark);
      _hline(canvas, p, 35, 26, 5, dark);
      _px(canvas, p, 40, 27, dark);
    } else {
      // Standard brows
      _hline(canvas, p, 23, 26, 7, dark);
      _px(canvas, p, 22, 27, dark);
      _hline(canvas, p, 34, 26, 7, dark);
      _px(canvas, p, 41, 27, dark);
    }
  }

  // ---------- Eyes ----------

  void _drawEyes(Canvas canvas, double s, double p) {
    const white = Color(0xFFF5F5F5);
    const pupil = Color(0xFF111111);
    const iris1 = Color(0xFF4A6741);
    const iris2 = Color(0xFF3A5530);
    const outline = Color(0xFF1A1A1A);

    switch (config.eyes) {
      case AvatarEyes.round:
        // Left eye: 6x5 rounded
        _hline(canvas, p, 24, 28, 5, outline);
        _px(canvas, p, 23, 29, outline);
        _rect(canvas, p, 24, 29, 5, 3, white);
        _px(canvas, p, 29, 29, outline);
        _px(canvas, p, 23, 30, outline);
        _px(canvas, p, 29, 30, outline);
        _px(canvas, p, 23, 31, outline);
        _px(canvas, p, 29, 31, outline);
        _hline(canvas, p, 24, 32, 5, outline);
        // Iris + pupil
        _rect(canvas, p, 25, 29, 3, 3, iris1);
        _rect(canvas, p, 26, 29, 2, 1, iris2);
        _rect(canvas, p, 26, 30, 2, 2, pupil);
        // Highlight
        _px(canvas, p, 25, 29, white);

        // Right eye
        _hline(canvas, p, 35, 28, 5, outline);
        _px(canvas, p, 34, 29, outline);
        _rect(canvas, p, 35, 29, 5, 3, white);
        _px(canvas, p, 40, 29, outline);
        _px(canvas, p, 34, 30, outline);
        _px(canvas, p, 40, 30, outline);
        _px(canvas, p, 34, 31, outline);
        _px(canvas, p, 40, 31, outline);
        _hline(canvas, p, 35, 32, 5, outline);
        _rect(canvas, p, 36, 29, 3, 3, iris1);
        _rect(canvas, p, 37, 29, 2, 1, iris2);
        _rect(canvas, p, 37, 30, 2, 2, pupil);
        _px(canvas, p, 36, 29, white);

      case AvatarEyes.almond:
        // Left: tapered 7x3
        _px(canvas, p, 23, 29, outline);
        _hline(canvas, p, 24, 28, 5, outline);
        _px(canvas, p, 29, 29, outline);
        _rect(canvas, p, 24, 29, 5, 2, white);
        _px(canvas, p, 23, 30, outline);
        _hline(canvas, p, 24, 31, 5, outline);
        _px(canvas, p, 29, 30, outline);
        // Iris
        _rect(canvas, p, 25, 29, 3, 2, iris1);
        _rect(canvas, p, 26, 29, 2, 2, pupil);
        _px(canvas, p, 25, 29, white);

        // Right
        _px(canvas, p, 34, 29, outline);
        _hline(canvas, p, 35, 28, 5, outline);
        _px(canvas, p, 40, 29, outline);
        _rect(canvas, p, 35, 29, 5, 2, white);
        _px(canvas, p, 34, 30, outline);
        _hline(canvas, p, 35, 31, 5, outline);
        _px(canvas, p, 40, 30, outline);
        _rect(canvas, p, 36, 29, 3, 2, iris1);
        _rect(canvas, p, 37, 29, 2, 2, pupil);
        _px(canvas, p, 36, 29, white);

      case AvatarEyes.wide:
        // Left: big 8x5
        _hline(canvas, p, 22, 27, 7, outline);
        _px(canvas, p, 21, 28, outline);
        _rect(canvas, p, 22, 28, 7, 4, white);
        _px(canvas, p, 29, 28, outline);
        _px(canvas, p, 21, 29, outline);
        _px(canvas, p, 29, 29, outline);
        _px(canvas, p, 21, 30, outline);
        _px(canvas, p, 29, 30, outline);
        _px(canvas, p, 21, 31, outline);
        _px(canvas, p, 29, 31, outline);
        _hline(canvas, p, 22, 32, 7, outline);
        _rect(canvas, p, 24, 28, 4, 4, iris1);
        _rect(canvas, p, 25, 29, 3, 3, pupil);
        _px(canvas, p, 24, 28, white);
        _px(canvas, p, 25, 28, white);

        // Right
        _hline(canvas, p, 35, 27, 7, outline);
        _px(canvas, p, 34, 28, outline);
        _rect(canvas, p, 35, 28, 7, 4, white);
        _px(canvas, p, 42, 28, outline);
        _px(canvas, p, 34, 29, outline);
        _px(canvas, p, 42, 29, outline);
        _px(canvas, p, 34, 30, outline);
        _px(canvas, p, 42, 30, outline);
        _px(canvas, p, 34, 31, outline);
        _px(canvas, p, 42, 31, outline);
        _hline(canvas, p, 35, 32, 7, outline);
        _rect(canvas, p, 37, 28, 4, 4, iris1);
        _rect(canvas, p, 38, 29, 3, 3, pupil);
        _px(canvas, p, 37, 28, white);
        _px(canvas, p, 38, 28, white);

      case AvatarEyes.narrow:
        // Thin slits: 7x2
        _hline(canvas, p, 23, 29, 7, outline);
        _hline(canvas, p, 23, 30, 7, outline);
        _rect(canvas, p, 24, 29, 5, 2, const Color(0xFF222222));
        _rect(canvas, p, 25, 29, 3, 2, pupil);
        // Slit highlight
        _px(canvas, p, 24, 29, const Color(0xFF444444));

        _hline(canvas, p, 34, 29, 7, outline);
        _hline(canvas, p, 34, 30, 7, outline);
        _rect(canvas, p, 35, 29, 5, 2, const Color(0xFF222222));
        _rect(canvas, p, 36, 29, 3, 2, pupil);
        _px(canvas, p, 35, 29, const Color(0xFF444444));

      case AvatarEyes.wink:
        // Left eye open (same as round)
        _hline(canvas, p, 24, 28, 5, outline);
        _px(canvas, p, 23, 29, outline);
        _rect(canvas, p, 24, 29, 5, 3, white);
        _px(canvas, p, 29, 29, outline);
        _px(canvas, p, 23, 30, outline);
        _px(canvas, p, 29, 30, outline);
        _px(canvas, p, 23, 31, outline);
        _px(canvas, p, 29, 31, outline);
        _hline(canvas, p, 24, 32, 5, outline);
        _rect(canvas, p, 25, 29, 3, 3, iris1);
        _rect(canvas, p, 26, 30, 2, 2, pupil);
        _px(canvas, p, 25, 29, white);

        // Right eye winking (^) — chevron shape
        _px(canvas, p, 34, 31, outline);
        _px(canvas, p, 35, 30, outline);
        _px(canvas, p, 36, 29, outline);
        _px(canvas, p, 37, 28, outline);
        _px(canvas, p, 38, 29, outline);
        _px(canvas, p, 39, 30, outline);
        _px(canvas, p, 40, 31, outline);
    }

    // Feminine eyelashes
    if (config.bodyType == AvatarBodyType.feminine) {
      // Upper lash extensions
      _px(canvas, p, 23, 27, outline);
      _px(canvas, p, 29, 27, outline);
      _px(canvas, p, 34, 27, outline);
      _px(canvas, p, 40, 27, outline);
    }
  }

  // ---------- Nose ----------

  void _drawNose(Canvas canvas, double s, double p) {
    final shd = _skinShadow[config.skin]!;
    final hl = _skinHighlight[config.skin]!;
    // Nose bridge highlight
    _rect(canvas, p, 31, 32, 2, 3, hl);
    // Nostrils
    _px(canvas, p, 30, 35, shd);
    _px(canvas, p, 31, 35, shd);
    _px(canvas, p, 32, 35, shd);
    _px(canvas, p, 33, 35, shd);
    // Nostril shadow
    _px(canvas, p, 30, 36, shd);
    _px(canvas, p, 33, 36, shd);
  }

  // ---------- Mouth ----------

  void _drawMouth(Canvas canvas, double s, double p) {
    final shd = _skinShadow[config.skin]!;
    const lip = Color(0xFFBB5555);
    const lipHl = Color(0xFFCC7777);
    const lipDark = Color(0xFF994444);

    if (config.bodyType == AvatarBodyType.feminine) {
      // Fuller, more defined lips
      _hline(canvas, p, 28, 37, 8, shd);
      _hline(canvas, p, 28, 38, 8, lip);
      _hline(canvas, p, 29, 39, 6, lip);
      _hline(canvas, p, 29, 40, 6, lipDark);
      _hline(canvas, p, 30, 41, 4, lipDark);
      // Highlight (cupid's bow)
      _px(canvas, p, 30, 38, lipHl);
      _px(canvas, p, 33, 38, lipHl);
      _px(canvas, p, 31, 39, lipHl);
      _px(canvas, p, 32, 39, lipHl);
    } else {
      // Standard lips
      _hline(canvas, p, 28, 38, 8, shd);
      _hline(canvas, p, 29, 39, 6, lip);
      _hline(canvas, p, 30, 40, 4, lipDark);
      _px(canvas, p, 31, 39, lipHl);
      _px(canvas, p, 32, 39, lipHl);
    }
  }

  // ---------- Hair ----------

  void _drawHair(Canvas canvas, double s, double p) {
    if (config.hair == AvatarHair.none) return;

    final base = _hairBase[config.hair]!;
    final light = _hairLight[config.hair]!;
    final dark = _hairDark[config.hair]!;

    switch (config.hair) {
      case AvatarHair.none:
        break;

      case AvatarHair.short:
        // Flat top with fade on sides
        _hline(canvas, p, 22, 15, 20, base);
        _rect(canvas, p, 20, 16, 24, 5, base);
        // Side fade
        _rect(canvas, p, 18, 20, 3, 6, base);
        _rect(canvas, p, 43, 20, 3, 6, base);
        _rect(canvas, p, 18, 25, 2, 3, dark);
        _rect(canvas, p, 44, 25, 2, 3, dark);
        // Top highlight
        _rect(canvas, p, 26, 15, 12, 2, light);
        // Texture lines
        _hline(canvas, p, 22, 17, 4, light);
        _hline(canvas, p, 36, 17, 4, light);

      case AvatarHair.medium:
        // Side-parted, ear length
        _hline(canvas, p, 22, 14, 20, base);
        _rect(canvas, p, 20, 15, 24, 7, base);
        // Side hair covering ears
        _rect(canvas, p, 17, 20, 4, 12, base);
        _rect(canvas, p, 43, 20, 4, 12, base);
        // Part line
        _rect(canvas, p, 27, 14, 2, 5, light);
        // Top highlight
        _rect(canvas, p, 29, 14, 8, 2, light);
        // Volume/texture
        _hline(canvas, p, 22, 16, 4, dark);
        _hline(canvas, p, 38, 16, 4, dark);
        _rect(canvas, p, 17, 26, 2, 4, dark);
        _rect(canvas, p, 45, 26, 2, 4, dark);

      case AvatarHair.long:
        // Long flowing hair past shoulders
        _hline(canvas, p, 22, 13, 20, base);
        _rect(canvas, p, 20, 14, 24, 8, base);
        // Sides flowing down
        _rect(canvas, p, 16, 20, 5, 28, base);
        _rect(canvas, p, 43, 20, 5, 28, base);
        // Top highlight
        _rect(canvas, p, 26, 13, 12, 2, light);
        // Texture strands
        _rect(canvas, p, 16, 30, 2, 8, light);
        _rect(canvas, p, 46, 30, 2, 8, light);
        _rect(canvas, p, 18, 34, 1, 6, dark);
        _rect(canvas, p, 45, 34, 1, 6, dark);
        // Inner shadow near face
        _rect(canvas, p, 19, 22, 2, 10, dark);
        _rect(canvas, p, 43, 22, 2, 10, dark);

      case AvatarHair.mohawk:
        // Tall central strip
        _rect(canvas, p, 27, 4, 10, 18, base);
        _rect(canvas, p, 26, 8, 2, 10, base);
        _rect(canvas, p, 36, 8, 2, 10, base);
        // Tip highlight
        _rect(canvas, p, 29, 4, 6, 4, light);
        // Texture
        _rect(canvas, p, 28, 10, 2, 4, dark);
        _rect(canvas, p, 34, 10, 2, 4, dark);
        // Side stubble
        _rect(canvas, p, 20, 18, 6, 2, dark);
        _rect(canvas, p, 38, 18, 6, 2, dark);

      case AvatarHair.curly:
        // Curly volume on top and sides
        _rect(canvas, p, 20, 13, 24, 8, base);
        // Curl bumps on top (staggered)
        _rect(canvas, p, 21, 11, 4, 3, base);
        _rect(canvas, p, 26, 10, 4, 3, base);
        _rect(canvas, p, 31, 9, 4, 3, base);
        _rect(canvas, p, 36, 10, 4, 3, base);
        _rect(canvas, p, 41, 12, 3, 2, base);
        // Side curls
        _rect(canvas, p, 17, 19, 4, 10, base);
        _rect(canvas, p, 43, 19, 4, 10, base);
        _rect(canvas, p, 16, 22, 2, 6, base);
        _rect(canvas, p, 46, 22, 2, 6, base);
        // Highlight curls
        _rect(canvas, p, 27, 10, 2, 2, light);
        _rect(canvas, p, 33, 9, 2, 2, light);
        _rect(canvas, p, 22, 12, 2, 2, light);
        _rect(canvas, p, 39, 11, 2, 2, light);
        // Dark depth
        _rect(canvas, p, 18, 25, 2, 3, dark);
        _rect(canvas, p, 44, 25, 2, 3, dark);

      case AvatarHair.afro:
        // Big round afro
        _hline(canvas, p, 22, 6, 20, base);
        _hline(canvas, p, 20, 7, 24, base);
        _rect(canvas, p, 18, 8, 28, 4, base);
        _rect(canvas, p, 16, 12, 32, 6, base);
        _rect(canvas, p, 14, 16, 36, 6, base);
        _rect(canvas, p, 14, 22, 6, 10, base);
        _rect(canvas, p, 44, 22, 6, 10, base);
        // Highlights
        _rect(canvas, p, 26, 7, 12, 2, light);
        _rect(canvas, p, 20, 10, 4, 3, light);
        _rect(canvas, p, 40, 10, 4, 3, light);
        _rect(canvas, p, 16, 16, 3, 3, light);
        _rect(canvas, p, 45, 16, 3, 3, light);
        // Depth
        _rect(canvas, p, 14, 26, 3, 4, dark);
        _rect(canvas, p, 47, 26, 3, 4, dark);
        _rect(canvas, p, 22, 8, 3, 2, dark);
        _rect(canvas, p, 39, 8, 3, 2, dark);

      case AvatarHair.ponytail:
        // Top hair + flowing ponytail to right
        _hline(canvas, p, 22, 14, 20, base);
        _rect(canvas, p, 20, 15, 24, 6, base);
        _rect(canvas, p, 18, 19, 3, 5, base);
        // Ponytail band
        _rect(canvas, p, 44, 19, 3, 3, const Color(0xFFCC4444));
        // Ponytail flowing right and down
        _rect(canvas, p, 46, 20, 5, 3, base);
        _rect(canvas, p, 48, 23, 5, 3, base);
        _rect(canvas, p, 49, 26, 4, 4, base);
        _rect(canvas, p, 48, 30, 4, 4, base);
        _rect(canvas, p, 47, 34, 3, 4, base);
        // Ponytail highlights
        _rect(canvas, p, 49, 21, 2, 2, light);
        _rect(canvas, p, 50, 27, 2, 2, light);
        _rect(canvas, p, 48, 32, 2, 2, light);
        // Top highlight
        _rect(canvas, p, 26, 14, 10, 2, light);
        // Texture
        _rect(canvas, p, 47, 24, 2, 2, dark);
        _rect(canvas, p, 48, 35, 2, 2, dark);
    }
  }

  // ---------- Outfit ----------

  void _drawOutfit(Canvas canvas, double s, double p) {
    final base = _outfitBase[config.outfit]!;
    final light = _outfitLight[config.outfit]!;
    final dark = _outfitDark[config.outfit]!;
    final isFeminine = config.bodyType == AvatarBodyType.feminine;

    if (isFeminine) {
      // Narrower shoulders, tapered waist
      _rect(canvas, p, 14, 48, 36, 16, base);
      _rect(canvas, p, 10, 50, 4, 14, base);
      _rect(canvas, p, 50, 50, 4, 14, base);
      _rect(canvas, p, 8, 52, 2, 12, base);
      _rect(canvas, p, 54, 52, 2, 12, base);
      // Collar area highlight
      _hline(canvas, p, 26, 48, 12, light);
      _hline(canvas, p, 27, 47, 10, light);
      // Shoulder highlights
      _rect(canvas, p, 14, 48, 6, 2, light);
      _rect(canvas, p, 44, 48, 6, 2, light);
      // Lower shadow
      _rect(canvas, p, 14, 58, 36, 6, dark);
    } else {
      // Standard broader shoulders
      _rect(canvas, p, 12, 48, 40, 16, base);
      _rect(canvas, p, 8, 50, 4, 14, base);
      _rect(canvas, p, 52, 50, 4, 14, base);
      _rect(canvas, p, 6, 52, 2, 12, base);
      _rect(canvas, p, 56, 52, 2, 12, base);
      // Collar area highlight
      _hline(canvas, p, 26, 48, 12, light);
      _hline(canvas, p, 27, 47, 10, light);
      // Shoulder highlights
      _rect(canvas, p, 12, 48, 6, 2, light);
      _rect(canvas, p, 46, 48, 6, 2, light);
      // Lower shadow
      _rect(canvas, p, 12, 58, 40, 6, dark);
    }

    switch (config.outfit) {
      case AvatarOutfit.tshirt:
        // Simple collar
        _hline(canvas, p, 28, 46, 8, light);
        // Sleeve seams
        _rect(canvas, p, 12, 50, 1, 6, dark);
        _rect(canvas, p, 51, 50, 1, 6, dark);

      case AvatarOutfit.pilot:
        // Gold lapels
        _rect(canvas, p, 24, 49, 4, 6, FlitColors.gold);
        _rect(canvas, p, 36, 49, 4, 6, FlitColors.gold);
        // Epaulettes
        _rect(canvas, p, 10, 48, 6, 2, FlitColors.gold);
        _rect(canvas, p, 48, 48, 6, 2, FlitColors.gold);
        // Breast pocket
        _rect(canvas, p, 20, 52, 3, 3, dark);
        // Wings badge
        _rect(canvas, p, 38, 53, 2, 1, FlitColors.gold);
        _hline(canvas, p, 36, 54, 6, FlitColors.gold);
        _rect(canvas, p, 38, 55, 2, 1, FlitColors.gold);

      case AvatarOutfit.suit:
        // V lapels
        for (var i = 0; i < 6; i++) {
          _px(canvas, p, (28 - i).toDouble(), (48 + i).toDouble(), light);
          _px(canvas, p, (27 - i).toDouble(), (48 + i).toDouble(), light);
          _px(canvas, p, (35 + i).toDouble(), (48 + i).toDouble(), light);
          _px(canvas, p, (36 + i).toDouble(), (48 + i).toDouble(), light);
        }
        // Tie
        _rect(canvas, p, 31, 48, 2, 2, FlitColors.accent);
        _rect(canvas, p, 30, 50, 4, 1, FlitColors.accent);
        _rect(canvas, p, 31, 51, 2, 8, FlitColors.accent);
        _px(canvas, p, 31, 52, FlitColors.accentLight);
        // Pocket square
        _rect(canvas, p, 21, 52, 3, 2, FlitColors.textSecondary);

      case AvatarOutfit.leather:
        // Diagonal zip
        for (var i = 0; i < 10; i++) {
          _px(canvas, p, (30 + (i ~/ 2)).toDouble(), (48 + i).toDouble(),
              const Color(0xFF888888));
        }
        // Collar flaps
        _rect(canvas, p, 24, 47, 6, 3, light);
        _rect(canvas, p, 34, 47, 6, 3, light);
        // Pocket
        _rect(canvas, p, 20, 54, 4, 3, dark);
        _hline(canvas, p, 20, 54, 4, const Color(0xFF888888));

      case AvatarOutfit.spacesuit:
        // Helmet collar ring
        _rect(canvas, p, 22, 45, 20, 3, const Color(0xFF999999));
        _hline(canvas, p, 21, 46, 22, const Color(0xFF777777));
        // Chest panel with lights
        _rect(canvas, p, 28, 52, 8, 6, const Color(0xFF4A90B8));
        _rect(canvas, p, 29, 53, 6, 4, const Color(0xFF3A7090));
        // LED lights
        _px(canvas, p, 30, 54, const Color(0xFF44CC44));
        _px(canvas, p, 32, 54, const Color(0xFFCC4444));
        _px(canvas, p, 34, 54, const Color(0xFF4488CC));
        // Seam lines
        _rect(canvas, p, 24, 48, 1, 16, const Color(0xFFB0B0B0));
        _rect(canvas, p, 39, 48, 1, 16, const Color(0xFFB0B0B0));

      case AvatarOutfit.captain:
        // Double row of gold buttons
        for (var i = 0; i < 4; i++) {
          final y = 50 + i.toDouble() * 3;
          _rect(canvas, p, 28, y, 2, 2, FlitColors.gold);
          _rect(canvas, p, 34, y, 2, 2, FlitColors.gold);
        }
        // Shoulder epaulettes
        _rect(canvas, p, 9, 49, 7, 2, FlitColors.gold);
        _rect(canvas, p, 48, 49, 7, 2, FlitColors.gold);
        // Gold trim
        _hline(canvas, p, 26, 48, 12, FlitColors.gold);
        // Breast badge
        _rect(canvas, p, 20, 52, 4, 3, FlitColors.gold);
        _rect(canvas, p, 21, 53, 2, 1, FlitColors.goldLight);
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
        _rect(canvas, p, 20, 13, 24, 6, FlitColors.accent);
        _hline(canvas, p, 19, 12, 26, FlitColors.accent);
        _hline(canvas, p, 21, 11, 22, FlitColors.accent);
        // Brim
        _rect(canvas, p, 14, 19, 26, 2, FlitColors.accent);
        _hline(canvas, p, 12, 19, 2, FlitColors.accentDark);
        // Highlight
        _rect(canvas, p, 25, 11, 14, 2, FlitColors.accentLight);
        // Button on top
        _rect(canvas, p, 31, 10, 2, 2, FlitColors.accentLight);
        // Brim shadow
        _hline(canvas, p, 14, 20, 26, FlitColors.accentDark);

      case AvatarHat.aviator:
        const leather = Color(0xFF5A3A1A);
        const leatherHL = Color(0xFF7A5A30);
        const leatherDK = Color(0xFF3E2810);
        // Cap dome
        _rect(canvas, p, 20, 13, 24, 8, leather);
        _hline(canvas, p, 22, 12, 20, leather);
        _rect(canvas, p, 18, 18, 3, 5, leather);
        _rect(canvas, p, 43, 18, 3, 5, leather);
        // Ear flaps
        _rect(canvas, p, 15, 22, 4, 10, leather);
        _rect(canvas, p, 45, 22, 4, 10, leather);
        _rect(canvas, p, 16, 28, 2, 4, leatherDK);
        _rect(canvas, p, 46, 28, 2, 4, leatherDK);
        // Goggles strap
        _hline(canvas, p, 19, 19, 26, FlitColors.gold);
        _hline(canvas, p, 19, 20, 26, FlitColors.gold);
        // Goggles lenses
        _rect(canvas, p, 22, 17, 6, 3, const Color(0xFF4A90B8));
        _rect(canvas, p, 36, 17, 6, 3, const Color(0xFF4A90B8));
        _rect(canvas, p, 23, 17, 2, 1, const Color(0xFF8CC8E8)); // glint
        _rect(canvas, p, 37, 17, 2, 1, const Color(0xFF8CC8E8));
        // Top highlight
        _rect(canvas, p, 26, 12, 12, 2, leatherHL);

      case AvatarHat.tophat:
        const hat = Color(0xFF1A1A1A);
        const hatHL = Color(0xFF333333);
        // Brim
        _rect(canvas, p, 16, 16, 32, 2, hat);
        _hline(canvas, p, 15, 17, 34, hat);
        // Crown
        _rect(canvas, p, 21, 4, 22, 12, hat);
        _rect(canvas, p, 20, 6, 24, 8, hat);
        // Band
        _rect(canvas, p, 21, 13, 22, 2, FlitColors.accent);
        // Highlight
        _rect(canvas, p, 24, 5, 6, 2, hatHL);
        _rect(canvas, p, 22, 7, 2, 4, hatHL);

      case AvatarHat.crown:
        // Crown base
        _rect(canvas, p, 19, 14, 26, 4, FlitColors.gold);
        // Points
        _rect(canvas, p, 20, 10, 3, 4, FlitColors.gold);
        _rect(canvas, p, 26, 8, 3, 6, FlitColors.gold);
        _rect(canvas, p, 31, 6, 3, 8, FlitColors.gold);
        _rect(canvas, p, 36, 8, 3, 6, FlitColors.gold);
        _rect(canvas, p, 41, 10, 3, 4, FlitColors.gold);
        // Jewels
        _rect(canvas, p, 21, 11, 2, 2, FlitColors.accent);
        _rect(canvas, p, 27, 9, 2, 2, const Color(0xFF4A90B8));
        _rect(canvas, p, 31, 7, 3, 2, FlitColors.accent);
        _rect(canvas, p, 37, 9, 2, 2, const Color(0xFF2ECC40));
        _rect(canvas, p, 42, 11, 2, 2, FlitColors.accent);
        // Gold highlight band
        _hline(canvas, p, 19, 17, 26, FlitColors.goldLight);
        // Shadow on base
        _hline(canvas, p, 19, 16, 26, const Color(0xFFB08820));

      case AvatarHat.helmet:
        const helm = Color(0xFF606060);
        const helmHL = Color(0xFF888888);
        const helmDK = Color(0xFF444444);
        // Dome
        _hline(canvas, p, 22, 8, 20, helm);
        _rect(canvas, p, 20, 9, 24, 10, helm);
        _rect(canvas, p, 18, 12, 3, 8, helm);
        _rect(canvas, p, 43, 12, 3, 8, helm);
        // Visor slit
        _rect(canvas, p, 21, 19, 22, 2, helmDK);
        // Center stripe
        _rect(canvas, p, 30, 8, 4, 11, FlitColors.accent);
        // Ventilation holes
        _px(canvas, p, 24, 13, helmDK);
        _px(canvas, p, 26, 13, helmDK);
        _px(canvas, p, 37, 13, helmDK);
        _px(canvas, p, 39, 13, helmDK);
        // Highlight
        _rect(canvas, p, 22, 9, 6, 2, helmHL);
        _rect(canvas, p, 20, 11, 2, 4, helmHL);
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
        // Left lens: circular 8x6
        _hline(canvas, p, 23, 27, 7, frame);
        _px(canvas, p, 22, 28, frame);
        _px(canvas, p, 30, 28, frame);
        _px(canvas, p, 22, 29, frame);
        _px(canvas, p, 30, 29, frame);
        _px(canvas, p, 22, 30, frame);
        _px(canvas, p, 30, 30, frame);
        _px(canvas, p, 22, 31, frame);
        _px(canvas, p, 30, 31, frame);
        _hline(canvas, p, 23, 32, 7, frame);
        // Right lens
        _hline(canvas, p, 34, 27, 7, frame);
        _px(canvas, p, 33, 28, frame);
        _px(canvas, p, 41, 28, frame);
        _px(canvas, p, 33, 29, frame);
        _px(canvas, p, 41, 29, frame);
        _px(canvas, p, 33, 30, frame);
        _px(canvas, p, 41, 30, frame);
        _px(canvas, p, 33, 31, frame);
        _px(canvas, p, 41, 31, frame);
        _hline(canvas, p, 34, 32, 7, frame);
        // Bridge
        _hline(canvas, p, 30, 29, 3, frame);
        // Arms
        _hline(canvas, p, 19, 29, 3, frame);
        _hline(canvas, p, 42, 29, 3, frame);

      case AvatarGlasses.aviator:
        const frame = Color(0xFFD4A944);
        const lens = Color(0x404A90B8);
        // Left lens fill
        _rect(canvas, p, 22, 27, 9, 7, lens);
        // Frame
        _hline(canvas, p, 23, 27, 7, frame);
        _px(canvas, p, 22, 28, frame);
        _px(canvas, p, 30, 28, frame);
        _px(canvas, p, 22, 29, frame);
        _px(canvas, p, 30, 29, frame);
        _px(canvas, p, 22, 30, frame);
        _px(canvas, p, 30, 30, frame);
        _px(canvas, p, 22, 31, frame);
        _px(canvas, p, 30, 31, frame);
        _px(canvas, p, 22, 32, frame);
        _px(canvas, p, 30, 32, frame);
        _hline(canvas, p, 23, 33, 7, frame);
        // Right lens
        _rect(canvas, p, 33, 27, 9, 7, lens);
        _hline(canvas, p, 34, 27, 7, frame);
        _px(canvas, p, 33, 28, frame);
        _px(canvas, p, 41, 28, frame);
        _px(canvas, p, 33, 29, frame);
        _px(canvas, p, 41, 29, frame);
        _px(canvas, p, 33, 30, frame);
        _px(canvas, p, 41, 30, frame);
        _px(canvas, p, 33, 31, frame);
        _px(canvas, p, 41, 31, frame);
        _px(canvas, p, 33, 32, frame);
        _px(canvas, p, 41, 32, frame);
        _hline(canvas, p, 34, 33, 7, frame);
        // Bridge
        _hline(canvas, p, 30, 29, 3, frame);
        // Arms
        _hline(canvas, p, 19, 29, 3, frame);
        _hline(canvas, p, 42, 29, 3, frame);

      case AvatarGlasses.monocle:
        const frame = Color(0xFFD4A944);
        // Single round lens on right eye
        _hline(canvas, p, 34, 27, 7, frame);
        _px(canvas, p, 33, 28, frame);
        _px(canvas, p, 41, 28, frame);
        _px(canvas, p, 33, 29, frame);
        _px(canvas, p, 41, 29, frame);
        _px(canvas, p, 33, 30, frame);
        _px(canvas, p, 41, 30, frame);
        _px(canvas, p, 33, 31, frame);
        _px(canvas, p, 41, 31, frame);
        _hline(canvas, p, 34, 32, 7, frame);
        // Chain diagonal
        _px(canvas, p, 39, 33, frame);
        _px(canvas, p, 38, 34, frame);
        _px(canvas, p, 37, 35, frame);
        _px(canvas, p, 36, 36, frame);
        _px(canvas, p, 35, 37, frame);
        _px(canvas, p, 34, 38, frame);
        _px(canvas, p, 33, 39, frame);
        _px(canvas, p, 32, 40, frame);

      case AvatarGlasses.futuristic:
        const frame = Color(0xFF4A90B8);
        const lens = Color(0x604A90B8);
        // Single visor band
        _rect(canvas, p, 20, 27, 24, 5, lens);
        _hline(canvas, p, 20, 27, 24, frame);
        _hline(canvas, p, 20, 31, 24, frame);
        _rect(canvas, p, 20, 28, 1, 3, frame);
        _rect(canvas, p, 43, 28, 1, 3, frame);
        // Arms
        _hline(canvas, p, 17, 29, 3, frame);
        _hline(canvas, p, 44, 29, 3, frame);
        // Lens glint
        _hline(canvas, p, 22, 28, 4, const Color(0x808CC8E8));
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
        _rect(canvas, p, 20, 44, 24, 4, FlitColors.accent);
        _rect(canvas, p, 22, 45, 20, 2, FlitColors.accentLight);
        // Hanging end
        _rect(canvas, p, 38, 48, 4, 8, FlitColors.accent);
        _rect(canvas, p, 40, 48, 2, 8, FlitColors.accentLight);
        // Stripes
        _hline(canvas, p, 38, 52, 4, FlitColors.accentDark);
        _hline(canvas, p, 38, 54, 4, FlitColors.accentDark);
        // Wrap texture
        _hline(canvas, p, 22, 46, 16, FlitColors.accentDark);

      case AvatarAccessory.medal:
        // Ribbon
        _rect(canvas, p, 30, 52, 4, 2, FlitColors.accent);
        _rect(canvas, p, 31, 54, 2, 4, FlitColors.accent);
        // Medal circle
        _rect(canvas, p, 29, 58, 6, 4, FlitColors.gold);
        _rect(canvas, p, 30, 57, 4, 1, FlitColors.gold);
        _rect(canvas, p, 30, 62, 4, 1, FlitColors.gold);
        // Star center
        _rect(canvas, p, 31, 59, 2, 2, FlitColors.goldLight);
        // Ribbon V
        _px(canvas, p, 30, 52, FlitColors.accentDark);
        _px(canvas, p, 33, 52, FlitColors.accentDark);

      case AvatarAccessory.earring:
        // Gold hoop earring on left ear
        _rect(canvas, p, 15, 32, 2, 2, FlitColors.gold);
        _rect(canvas, p, 15, 34, 2, 2, FlitColors.goldLight);
        _px(canvas, p, 14, 33, FlitColors.gold);
        _px(canvas, p, 17, 33, FlitColors.gold);

      case AvatarAccessory.goldChain:
        // Chain arc across chest
        _px(canvas, p, 22, 52, FlitColors.gold);
        _px(canvas, p, 23, 53, FlitColors.gold);
        _px(canvas, p, 24, 54, FlitColors.gold);
        _px(canvas, p, 25, 55, FlitColors.gold);
        _px(canvas, p, 26, 55, FlitColors.goldLight);
        _px(canvas, p, 27, 56, FlitColors.goldLight);
        _px(canvas, p, 28, 56, FlitColors.gold);
        _px(canvas, p, 29, 57, FlitColors.gold);
        _px(canvas, p, 30, 57, FlitColors.goldLight);
        _px(canvas, p, 31, 58, FlitColors.goldLight);
        _px(canvas, p, 32, 58, FlitColors.goldLight);
        _px(canvas, p, 33, 57, FlitColors.gold);
        _px(canvas, p, 34, 57, FlitColors.goldLight);
        _px(canvas, p, 35, 56, FlitColors.gold);
        _px(canvas, p, 36, 56, FlitColors.goldLight);
        _px(canvas, p, 37, 55, FlitColors.gold);
        _px(canvas, p, 38, 55, FlitColors.gold);
        _px(canvas, p, 39, 54, FlitColors.gold);
        _px(canvas, p, 40, 53, FlitColors.gold);
        _px(canvas, p, 41, 52, FlitColors.gold);
        // Pendant
        _rect(canvas, p, 30, 59, 4, 3, FlitColors.gold);
        _rect(canvas, p, 31, 59, 2, 2, FlitColors.goldLight);

      case AvatarAccessory.parrot:
        // Pixel parrot on right shoulder
        const green = Color(0xFF2ECC40);
        const greenDk = Color(0xFF1FA030);
        const beak = Color(0xFFD4A944);
        // Body
        _rect(canvas, p, 48, 43, 5, 6, green);
        _rect(canvas, p, 49, 42, 4, 1, green);
        // Head
        _rect(canvas, p, 51, 39, 4, 4, green);
        _rect(canvas, p, 52, 38, 2, 1, green);
        // Eye
        _rect(canvas, p, 53, 40, 2, 2, const Color(0xFF1A1A1A));
        _px(canvas, p, 53, 40, const Color(0xFFF5F5F5));
        // Beak
        _rect(canvas, p, 55, 41, 3, 2, beak);
        _px(canvas, p, 57, 42, const Color(0xFFCC8800));
        // Wing
        _rect(canvas, p, 47, 44, 3, 4, greenDk);
        // Tail
        _px(canvas, p, 47, 49, FlitColors.accent);
        _px(canvas, p, 48, 49, green);
        _px(canvas, p, 49, 49, const Color(0xFF4A90B8));
    }
  }

  // ---------- Companion ----------

  void _drawCompanion(Canvas canvas, double s, double p) {
    if (config.companion == AvatarCompanion.none) return;

    switch (config.companion) {
      case AvatarCompanion.none:
        break;

      case AvatarCompanion.sparrow:
        const body = Color(0xFF8B6914);
        const belly = Color(0xFFD4A944);
        const wing = Color(0xFF6B4E10);
        const beak = Color(0xFFCC8800);
        // Body
        _rect(canvas, p, 48, 54, 6, 4, body);
        _rect(canvas, p, 49, 53, 4, 1, body);
        // Belly
        _rect(canvas, p, 49, 56, 4, 2, belly);
        // Head
        _rect(canvas, p, 52, 50, 4, 4, body);
        _rect(canvas, p, 53, 49, 2, 1, body);
        // Eye
        _rect(canvas, p, 54, 51, 2, 2, const Color(0xFF1A1A1A));
        _px(canvas, p, 54, 51, const Color(0xFFF5F5F5));
        // Beak
        _rect(canvas, p, 56, 52, 2, 1, beak);
        _px(canvas, p, 57, 53, beak);
        // Wing
        _rect(canvas, p, 47, 55, 3, 3, wing);
        // Tail
        _rect(canvas, p, 46, 54, 2, 1, body);
        _px(canvas, p, 45, 55, body);

      case AvatarCompanion.eagle:
        const body = Color(0xFF4A3520);
        const head = Color(0xFFF0E8DC);
        const wing = Color(0xFF332010);
        const beak = Color(0xFFD4A944);
        // Body
        _rect(canvas, p, 46, 54, 8, 5, body);
        _rect(canvas, p, 47, 53, 6, 1, body);
        // Wings spread
        _rect(canvas, p, 43, 53, 3, 4, wing);
        _rect(canvas, p, 54, 53, 3, 4, wing);
        _px(canvas, p, 42, 54, wing);
        _px(canvas, p, 57, 54, wing);
        // White head
        _rect(canvas, p, 51, 50, 4, 4, head);
        _rect(canvas, p, 52, 49, 2, 1, head);
        // Eye
        _rect(canvas, p, 53, 51, 2, 1, const Color(0xFF1A1A1A));
        // Beak (hooked)
        _rect(canvas, p, 55, 51, 2, 1, beak);
        _rect(canvas, p, 56, 52, 2, 1, beak);
        _px(canvas, p, 56, 53, beak);
        // Tail
        _rect(canvas, p, 44, 58, 3, 2, body);

      case AvatarCompanion.parrot:
        const green = Color(0xFF2ECC40);
        const red = Color(0xFFCC4444);
        const blue = Color(0xFF4A90B8);
        const beak = Color(0xFFD4A944);
        // Body
        _rect(canvas, p, 47, 54, 6, 5, green);
        _rect(canvas, p, 48, 53, 4, 1, green);
        // Head
        _rect(canvas, p, 51, 50, 4, 4, green);
        _rect(canvas, p, 52, 49, 2, 1, green);
        // Crest
        _rect(canvas, p, 51, 48, 2, 2, red);
        _px(canvas, p, 53, 48, red);
        // Eye
        _rect(canvas, p, 53, 51, 2, 2, const Color(0xFF1A1A1A));
        _px(canvas, p, 53, 51, const Color(0xFFF5F5F5));
        // Beak
        _rect(canvas, p, 55, 52, 2, 1, beak);
        _px(canvas, p, 56, 53, beak);
        // Wing
        _rect(canvas, p, 45, 55, 4, 3, blue);
        // Tail feathers
        _px(canvas, p, 45, 59, red);
        _px(canvas, p, 46, 59, green);
        _px(canvas, p, 47, 59, blue);
        _px(canvas, p, 48, 59, red);

      case AvatarCompanion.phoenix:
        const flame = Color(0xFFE88020);
        const flameLight = Color(0xFFFFCC44);
        const body = Color(0xFFCC4422);
        // Body
        _rect(canvas, p, 46, 52, 8, 5, body);
        _rect(canvas, p, 47, 51, 6, 1, body);
        // Wings (fiery)
        _rect(canvas, p, 42, 50, 4, 5, flame);
        _rect(canvas, p, 54, 50, 4, 5, flame);
        _rect(canvas, p, 41, 51, 1, 3, flameLight);
        _rect(canvas, p, 58, 51, 1, 3, flameLight);
        _px(canvas, p, 40, 52, flameLight);
        _px(canvas, p, 59, 52, flameLight);
        // Head
        _rect(canvas, p, 51, 48, 4, 4, body);
        _rect(canvas, p, 52, 47, 2, 1, body);
        // Eye (glowing)
        _rect(canvas, p, 53, 49, 2, 2, flameLight);
        // Beak
        _rect(canvas, p, 55, 50, 2, 1, FlitColors.gold);
        _px(canvas, p, 56, 51, FlitColors.gold);
        // Head plume
        _px(canvas, p, 51, 46, flame);
        _px(canvas, p, 52, 45, flameLight);
        _px(canvas, p, 53, 46, flame);
        // Tail fire
        _rect(canvas, p, 44, 57, 3, 2, flame);
        _px(canvas, p, 43, 58, flameLight);
        _px(canvas, p, 47, 58, flame);
        _px(canvas, p, 45, 59, flameLight);

      case AvatarCompanion.dragon:
        const bodyC = Color(0xFF2A5674);
        const belly = Color(0xFF3D7A9E);
        const wing = Color(0xFF1E3340);
        // Body
        _rect(canvas, p, 44, 52, 8, 6, bodyC);
        _rect(canvas, p, 45, 56, 6, 2, belly);
        // Head
        _rect(canvas, p, 51, 48, 6, 5, bodyC);
        _rect(canvas, p, 52, 50, 4, 2, belly);
        // Eye (glowing red)
        _rect(canvas, p, 55, 49, 2, 2, FlitColors.accent);
        _px(canvas, p, 55, 49, const Color(0xFFFF6644));
        // Horns
        _rect(canvas, p, 52, 46, 2, 2, bodyC);
        _rect(canvas, p, 55, 46, 2, 2, bodyC);
        _px(canvas, p, 52, 45, bodyC);
        _px(canvas, p, 56, 45, bodyC);
        // Snout
        _rect(canvas, p, 57, 50, 2, 2, bodyC);
        _px(canvas, p, 58, 50, belly);
        // Wings
        _rect(canvas, p, 45, 48, 6, 4, wing);
        _rect(canvas, p, 43, 49, 2, 3, wing);
        _px(canvas, p, 42, 50, wing);
        _px(canvas, p, 41, 49, wing);
        // Tail
        _rect(canvas, p, 42, 54, 2, 1, bodyC);
        _rect(canvas, p, 40, 55, 2, 1, bodyC);
        _rect(canvas, p, 38, 56, 2, 1, bodyC);
        _px(canvas, p, 37, 56, bodyC);
        // Tail spike
        _px(canvas, p, 36, 55, bodyC);
        _px(canvas, p, 36, 57, bodyC);
        // Fire breath
        _rect(canvas, p, 59, 50, 2, 1, FlitColors.accent);
        _px(canvas, p, 61, 50, const Color(0xFFE88020));
        _px(canvas, p, 60, 49, const Color(0xFFFFCC44));
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
