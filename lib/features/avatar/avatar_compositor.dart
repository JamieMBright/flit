import '../../data/models/avatar_config.dart';

// Adventurer parts
import 'parts/adventurer_base.dart';
import 'parts/adventurer_earrings.dart';
import 'parts/adventurer_eyebrows.dart';
import 'parts/adventurer_eyes.dart';
import 'parts/adventurer_features.dart';
import 'parts/adventurer_glasses.dart';
import 'parts/adventurer_hair.dart';
import 'parts/adventurer_mouth.dart';

// Avataaars parts
import 'parts/avataaars_eyebrows.dart';
import 'parts/avataaars_eyes.dart';
import 'parts/avataaars_mouth.dart';
import 'parts/avataaars_nose.dart';
import 'parts/avataaars_top.dart';

// Big Ears parts
import 'parts/bigears_cheek.dart';
import 'parts/bigears_ear.dart';
import 'parts/bigears_eyes.dart';
import 'parts/bigears_face.dart';
import 'parts/bigears_front_hair.dart';
import 'parts/bigears_mouth.dart';
import 'parts/bigears_nose.dart';
import 'parts/bigears_sideburn.dart';

// Bottts parts
import 'parts/bottts_eyes.dart';
import 'parts/bottts_face.dart';
import 'parts/bottts_mouth.dart';
import 'parts/bottts_sides.dart';
import 'parts/bottts_top.dart';

// Lorelei parts
import 'parts/lorelei_beard.dart';
import 'parts/lorelei_earrings.dart';
import 'parts/lorelei_eyebrows.dart';
import 'parts/lorelei_eyes.dart';
import 'parts/lorelei_freckles.dart';
import 'parts/lorelei_glasses.dart';
import 'parts/lorelei_hair.dart';
import 'parts/lorelei_hair_accessories.dart';
import 'parts/lorelei_head.dart';
import 'parts/lorelei_mouth.dart';
import 'parts/lorelei_nose.dart';

// Micah parts
import 'parts/micah_base.dart';
import 'parts/micah_earrings.dart';
import 'parts/micah_ears.dart';
import 'parts/micah_eyebrows.dart';
import 'parts/micah_eyes.dart';
import 'parts/micah_facial_hair.dart';
import 'parts/micah_glasses.dart';
import 'parts/micah_hair.dart';
import 'parts/micah_mouth.dart';
import 'parts/micah_nose.dart';
import 'parts/micah_shirt.dart';

// Notionists parts
import 'parts/notionists_base.dart';
import 'parts/notionists_beard.dart';
import 'parts/notionists_body.dart';
import 'parts/notionists_brows.dart';
import 'parts/notionists_eyes.dart';
import 'parts/notionists_gesture.dart';
import 'parts/notionists_glasses.dart';
import 'parts/notionists_hair.dart';
import 'parts/notionists_lips.dart';
import 'parts/notionists_nose.dart';

// Open Peeps parts
import 'parts/openpeeps_accessories.dart';
import 'parts/openpeeps_face.dart';
import 'parts/openpeeps_facial_hair.dart';
import 'parts/openpeeps_head.dart';
import 'parts/openpeeps_mask.dart';

// Pixel Art parts
import 'parts/pixelart_accessories.dart';
import 'parts/pixelart_beard.dart';
import 'parts/pixelart_clothing.dart';
import 'parts/pixelart_eyes.dart';
import 'parts/pixelart_glasses.dart';
import 'parts/pixelart_hair.dart';
import 'parts/pixelart_hat.dart';
import 'parts/pixelart_mouth.dart';

// Thumbs parts
import 'parts/thumbs_eyes.dart';
import 'parts/thumbs_face.dart';
import 'parts/thumbs_mouth.dart';
import 'parts/thumbs_shape.dart';

/// Composes a complete SVG string locally from DiceBear parts.
///
/// Eliminates all network calls — parts are stored as compile-time Dart string
/// constants extracted from the DiceBear open-source repo (MIT license).
///
/// Supports all 10 DiceBear styles. For adventurer, config enum values map
/// directly to variants. For other styles, a deterministic hash of the config
/// selects variants so that different configs produce visually distinct avatars.
class AvatarCompositor {
  AvatarCompositor._();

  /// Compose a complete SVG string for the given [config].
  ///
  /// Returns `null` only if composition fails unexpectedly.
  static String? compose(AvatarConfig config) => switch (config.style) {
    AvatarStyle.adventurer => _composeAdventurer(config),
    AvatarStyle.avataaars => _composeAvataaars(config),
    AvatarStyle.bigEars => _composeBigEars(config),
    AvatarStyle.lorelei => _composeLorelei(config),
    AvatarStyle.micah => _composeMicah(config),
    AvatarStyle.pixelArt => _composePixelArt(config),
    AvatarStyle.bottts => _composeBottts(config),
    AvatarStyle.notionists => _composeNotionists(config),
    AvatarStyle.openPeeps => _composeOpenPeeps(config),
    AvatarStyle.thumbs => _composeThumbs(config),
  };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Stable hash that depends only on the avatar style.
  ///
  /// Used for non-user-controllable parts (nose, face shape, etc.) so they
  /// remain fixed when the user changes individual features like eyes or mouth.
  static int _stableHash(AvatarConfig config) =>
      config.style.slug.hashCode.abs();

  /// Pick a variant from a map using a deterministic hash + salt.
  static String _pick(Map<String, String> parts, int hash, [int salt = 0]) {
    if (parts.isEmpty) return '';
    final keys = parts.keys.toList();
    final index = ((hash + salt * 31) % keys.length).abs();
    return parts[keys[index]] ?? '';
  }

  /// Wrap SVG content in a `<g transform="...">` group.
  static String _g(String svg, String transform) {
    if (svg.isEmpty) return '';
    return '<g transform="$transform">$svg</g>';
  }

  /// Darken a hex color string by a given factor (0.0 = black, 1.0 = no change).
  static String _darkenHex(String hex, double factor) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return hex;
    final r = int.tryParse(clean.substring(0, 2), radix: 16) ?? 128;
    final g = int.tryParse(clean.substring(2, 4), radix: 16) ?? 128;
    final b = int.tryParse(clean.substring(4, 6), radix: 16) ?? 128;
    final dr = (r * factor).round().clamp(0, 255);
    final dg = (g * factor).round().clamp(0, 255);
    final db = (b * factor).round().clamp(0, 255);
    return '#${dr.toRadixString(16).padLeft(2, '0')}'
        '${dg.toRadixString(16).padLeft(2, '0')}'
        '${db.toRadixString(16).padLeft(2, '0')}';
  }

  /// Generate a deterministic hex color from hash + salt.
  static String _hashColor(int hash, int salt) {
    final h = ((hash + salt * 71) % 360).abs();
    // Convert HSL to hex with saturation ~65%, lightness ~55%.
    final c = (1.0 - ((2.0 * 0.55 - 1.0).abs())) * 0.65;
    final x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    final m = 0.55 - c / 2.0;
    double r, g, b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    final ri = ((r + m) * 255).round().clamp(0, 255);
    final gi = ((g + m) * 255).round().clamp(0, 255);
    final bi = ((b + m) * 255).round().clamp(0, 255);
    return '#${ri.toRadixString(16).padLeft(2, '0')}'
        '${gi.toRadixString(16).padLeft(2, '0')}'
        '${bi.toRadixString(16).padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Adventurer (762 x 762)
  // ---------------------------------------------------------------------------

  static String? _composeAdventurer(AvatarConfig config) {
    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';

    final base = adventurerBase.replaceAll('{{SKIN_COLOR}}', skinHex);

    final eyes = adventurerEyes[config.eyes.apiValue] ?? '';
    final eyebrows = adventurerEyebrows[config.eyebrows.apiValue] ?? '';
    final mouth = adventurerMouth[config.mouth.apiValue] ?? '';

    final features = config.feature == AvatarFeature.none
        ? ''
        : adventurerFeatures[config.feature.name] ?? '';

    final glasses = config.glasses == AvatarGlasses.none
        ? ''
        : adventurerGlasses[config.glasses.apiValue] ?? '';

    final hair = config.hair == AvatarHair.none
        ? ''
        : (adventurerHair[config.hair.apiValue] ?? '').replaceAll(
            '{{HAIR_COLOR}}',
            hairHex,
          );

    final earrings = config.earrings == AvatarEarrings.none
        ? ''
        : adventurerEarrings[config.earrings.apiValue] ?? '';

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 762 762" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write(base);

    void addLayer(String svg) {
      if (svg.isNotEmpty) {
        buf
          ..write('<g transform="translate(-161 -83)">')
          ..write(svg)
          ..write('</g>');
      }
    }

    addLayer(eyes);
    addLayer(eyebrows);
    addLayer(mouth);
    addLayer(features);
    addLayer(glasses);
    addLayer(hair);
    addLayer(earrings);

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Avataaars (280 x 280)
  // ---------------------------------------------------------------------------

  static String? _composeAvataaars(AvatarConfig config) {
    final sh = _stableHash(config);

    final nose = _pick(avataaarsNose, sh, 1);
    final mouth = _pick(avataarsMouth, config.mouth.index, 2);
    final eyes = _pick(avataaarsEyes, config.eyes.index, 3);
    final eyebrows = _pick(avataaarsEyebrows, config.eyebrows.index, 4);
    final top = _pick(avataaarsTop, config.hair.index, 5);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 280 280" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write('<g transform="translate(8 0)">');

    // Background body shape (circle + shoulders).
    buf.write(
      '<circle cx="132" cy="132" r="120" fill="#e8e3e3"/>'
      '<mask id="a" maskUnits="userSpaceOnUse" x="12" y="12" width="240" height="240">'
      '<circle cx="132" cy="132" r="120" fill="#fff"/></mask>'
      '<g mask="url(#a)">',
    );

    // Layer order: nose → mouth → eyes → eyebrows → top.
    if (nose.isNotEmpty) buf.write(_g(nose, 'translate(76 100)'));
    if (mouth.isNotEmpty) buf.write(_g(mouth, 'translate(76 154)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(0 0)'));
    if (eyebrows.isNotEmpty) buf.write(_g(eyebrows, 'translate(0 0)'));
    if (top.isNotEmpty) buf.write(_g(top, 'translate(0 0)'));

    buf.write('</g></g></svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Big Ears (440 x 440)
  // ---------------------------------------------------------------------------

  static String? _composeBigEars(AvatarConfig config) {
    final sh = _stableHash(config);
    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';

    final face = _pick(
      bigearsFace,
      sh,
      1,
    ).replaceAll('{{SKIN_COLOR}}', skinHex);
    final ear = _pick(bigearsEar, sh, 2).replaceAll('{{SKIN_COLOR}}', skinHex);
    final sideburn = _pick(
      bigearsSideburn,
      sh,
      3,
    ).replaceAll('{{HAIR_COLOR}}', hairHex);
    final cheek = _pick(bigearsCheek, sh, 4);
    final nose = _pick(bigearsNose, sh, 5);
    final mouth = _pick(bigearsMouth, config.mouth.index, 6);
    final eyes = _pick(bigearsEyes, config.eyes.index, 7);
    final frontHair = _pick(
      bigearsFrontHair,
      config.hair.index,
      8,
    ).replaceAll('{{HAIR_COLOR}}', hairHex);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 440 440" fill="none" ')
      ..write('shape-rendering="auto">');

    // Face (centered).
    buf.write(_g(face, 'translate(30 51)'));

    // Left ear + right ear (mirrored).
    if (ear.isNotEmpty) {
      buf.write(_g(ear, 'translate(-20 115)'));
      buf.write('<g transform="translate(350 115) scale(-1 1)">$ear</g>');
    }

    // Left sideburn + right sideburn (mirrored).
    if (sideburn.isNotEmpty) {
      buf.write(_g(sideburn, 'translate(14 160)'));
      buf.write('<g transform="translate(375 160) scale(-1 1)">$sideburn</g>');
    }

    // Cheek, nose, mouth, eyes.
    if (cheek.isNotEmpty) buf.write(_g(cheek, 'translate(86 188)'));
    if (nose.isNotEmpty) buf.write(_g(nose, 'translate(129 175)'));
    if (mouth.isNotEmpty) buf.write(_g(mouth, 'translate(190 250)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(74 131)'));

    // Front hair.
    if (frontHair.isNotEmpty) buf.write(_g(frontHair, 'translate(6 0)'));

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Lorelei (980 x 980)
  // ---------------------------------------------------------------------------

  static String? _composeLorelei(AvatarConfig config) {
    final sh = _stableHash(config);
    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';

    final head = _pick(
      loreleiHead,
      sh,
      1,
    ).replaceAll('{{SKIN_COLOR}}', skinHex);
    final freckles = _pick(
      loreleiFreckles,
      config.feature.index,
      2,
    ).replaceAll('{{FRECKLES_COLOR}}', _darkenHex(skinHex, 0.85));
    final eyebrows = _pick(
      loreleiEyebrows,
      config.eyebrows.index,
      3,
    ).replaceAll('{{EYEBROWS_COLOR}}', hairHex);
    final eyes = _pick(loreleiEyes, config.eyes.index, 4);
    final nose = _pick(
      loreleiNose,
      sh,
      5,
    ).replaceAll('{{NOSE_COLOR}}', _darkenHex(skinHex, 0.9));
    final mouth = _pick(loreleiMouth, config.mouth.index, 6).replaceAll(
      '{{MOUTH_COLOR}}',
      _mouthColors[config.skinColor.index % _mouthColors.length],
    );
    final glasses = _pick(
      loreleiGlasses,
      config.glasses.index,
      7,
    ).replaceAll('{{GLASSES_COLOR}}', '#4a4a4a');
    final earrings = _pick(
      loreleiEarrings,
      config.earrings.index,
      8,
    ).replaceAll('{{EARRINGS_COLOR}}', '#d4af37');
    final hair = _pick(
      loreleiHair,
      config.hair.index,
      9,
    ).replaceAll('{{HAIR_COLOR}}', hairHex);
    final hairAccessories = _pick(
      loreleiHairAccessories,
      sh,
      10,
    ).replaceAll('{{HAIRACCESSORIES_COLOR}}', _hashColor(sh, 55));
    final beard = _pick(loreleiBeard, sh, 11)
        .replaceAll('{{BEARD_COLOR}}', hairHex)
        .replaceAll('{{HAIR_COLOR}}', hairHex);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 980 980" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write('<g transform="translate(10 -60)">');

    buf.write(head);
    if (freckles.isNotEmpty) buf.write(_g(freckles, 'translate(198 410)'));
    if (eyebrows.isNotEmpty) buf.write(_g(eyebrows, 'translate(198 310)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(198 370)'));
    if (nose.isNotEmpty) buf.write(_g(nose, 'translate(330 490)'));
    if (mouth.isNotEmpty) buf.write(_g(mouth, 'translate(270 590)'));
    if (glasses.isNotEmpty) buf.write(_g(glasses, 'translate(136 330)'));
    if (earrings.isNotEmpty) buf.write(_g(earrings, 'translate(110 460)'));
    if (hair.isNotEmpty) buf.write(hair);
    if (hairAccessories.isNotEmpty) buf.write(hairAccessories);
    if (beard.isNotEmpty) buf.write(_g(beard, 'translate(210 610)'));

    buf.write('</g></svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Micah (360 x 360)
  // ---------------------------------------------------------------------------

  /// Natural eye colors for Micah (and other realistic styles).
  static const _naturalEyeColors = [
    '#6B4423', // Brown
    '#3B6AA0', // Blue
    '#4A7C59', // Green
    '#8B6914', // Hazel / Amber
    '#5C3317', // Dark Brown
    '#7B9EB0', // Light Blue / Gray
    '#2E5E4E', // Teal / Dark Green
  ];

  /// Lip / mouth colors derived from natural skin tones.
  static const _mouthColors = [
    '#d29985', // Light lip
    '#c98276', // Medium lip
    '#b06a4f', // Tan lip
    '#a0604a', // Deep lip
    '#7a3d1a', // Dark lip
  ];

  static String? _composeMicah(AvatarConfig config) {
    final sh = _stableHash(config);
    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';
    // Pick a natural eye color that varies with the eyes selection.
    final eyeColor = _naturalEyeColors[
        (sh + config.eyes.index * 3) % _naturalEyeColors.length];
    final shirtColor = _hashColor(sh, 77);
    // Eye shadow: slightly darker/muted version via hash.
    final eyeShadow = _hashColor(sh, 88);
    // Mouth color: pick from natural lip palette based on skin tone.
    final mouthColor =
        _mouthColors[config.skinColor.index % _mouthColors.length];

    // Micah glasses embed inside eyes via {{GLASSES}} placeholder.
    final glassesRaw = config.glasses == AvatarGlasses.none
        ? ''
        : _pick(
            micahGlasses,
            config.glasses.index,
            10,
          ).replaceAll('{{GLASSES_COLOR}}', '#4a4a4a');
    // Micah facialHair embeds inside base via {{FACIAL_HAIR}} placeholder.
    final facialHairRaw = _pick(
      micahFacialHair,
      sh,
      11,
    ).replaceAll('{{FACIAL_HAIR_COLOR}}', hairHex);

    final base = micahBase
        .replaceAll('{{BASE_COLOR}}', skinHex)
        .replaceAll('{{FACIAL_HAIR}}', facialHairRaw);
    final mouth = _pick(
      micahMouth,
      config.mouth.index,
      2,
    ).replaceAll('{{MOUTH_COLOR}}', mouthColor);
    final eyebrows = _pick(
      micahEyebrows,
      config.eyebrows.index,
      3,
    ).replaceAll('{{EYEBROWS_COLOR}}', hairHex);
    final hair = _pick(
      micahHair,
      config.hair.index,
      4,
    ).replaceAll('{{HAIR_COLOR}}', hairHex);
    final eyes = _pick(micahEyes, config.eyes.index, 5)
        .replaceAll('{{EYES_COLOR}}', eyeColor)
        .replaceAll('{{EYE_SHADOW_COLOR}}', eyeShadow)
        .replaceAll('{{GLASSES}}', glassesRaw);
    final nose = _pick(micahNose, sh, 6);
    final ears = _pick(micahEars, sh, 7).replaceAll('{{EAR_COLOR}}', skinHex);
    final earrings = config.earrings == AvatarEarrings.none
        ? ''
        : _pick(
            micahEarrings,
            config.earrings.index,
            8,
          ).replaceAll('{{EARRING_COLOR}}', '#d4af37');
    final shirt = _pick(
      micahShirt,
      sh,
      9,
    ).replaceAll('{{SHIRT_COLOR}}', shirtColor);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 360 360" fill="none" ')
      ..write('shape-rendering="auto">');

    // Layer order matches DiceBear micah.
    buf.write(_g(base, 'translate(80 23)'));
    if (mouth.isNotEmpty) buf.write(_g(mouth, 'translate(170 183)'));
    if (eyebrows.isNotEmpty) buf.write(_g(eyebrows, 'translate(110 102)'));
    if (hair.isNotEmpty) buf.write(_g(hair, 'translate(49 11)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(142 119)'));
    if (nose.isNotEmpty) {
      buf.write(
        '<g transform="rotate(-8 179 167) translate(179 167)">$nose</g>',
      );
    }
    if (ears.isNotEmpty) buf.write(_g(ears, 'translate(84 154)'));
    if (earrings.isNotEmpty) buf.write(_g(earrings, 'translate(84 184)'));
    if (shirt.isNotEmpty) buf.write(_g(shirt, 'translate(53 272)'));

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Pixel Art (16 x 16)
  // ---------------------------------------------------------------------------

  static String? _composePixelArt(AvatarConfig config) {
    final sh = _stableHash(config);
    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';
    final eyeColor = _hashColor(sh, 33);
    final accColor = _hashColor(sh, 55);

    final clothing = _pick(
      pixelartClothing,
      sh,
      1,
    ).replaceAll('{{CLOTHING_COLOR}}', _hashColor(sh, 66));
    final eyes = _pick(
      pixelartEyes,
      config.eyes.index,
      2,
    ).replaceAll('{{EYES_COLOR}}', eyeColor);
    final mouth = _pick(
      pixelartMouth,
      config.mouth.index,
      3,
    ).replaceAll('{{MOUTH_COLOR}}', '#d2691e');
    final hair = _pick(
      pixelartHair,
      config.hair.index,
      4,
    ).replaceAll('{{HAIR_COLOR}}', hairHex);
    final beard = _pick(pixelartBeard, sh, 5)
        .replaceAll('{{BEARD_COLOR}}', hairHex)
        .replaceAll('{{HAIR_COLOR}}', hairHex);
    final glasses = _pick(
      pixelartGlasses,
      config.glasses.index,
      6,
    ).replaceAll('{{GLASSES_COLOR}}', '#4a4a4a');
    final hat = _pick(
      pixelartHat,
      sh,
      7,
    ).replaceAll('{{HAT_COLOR}}', _hashColor(sh, 44));
    final accessories = _pick(
      pixelartAccessories,
      config.earrings.index,
      8,
    ).replaceAll('{{ACCESSORIES_COLOR}}', accColor);

    // Pixel art base is a simple skin-colored head shape.
    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 16 16" fill="none" ')
      ..write('shape-rendering="crispEdges">')
      // Skin base.
      ..write('<path fill="$skinHex" d="M4 3h8v8H4z"/>')
      ..write('<path fill="$skinHex" d="M3 4h1v7H3zM12 4h1v7h-1z"/>');

    // Clothing at bottom.
    if (clothing.isNotEmpty) buf.write(clothing);
    // Eyes.
    if (eyes.isNotEmpty) buf.write(eyes);
    // Mouth.
    if (mouth.isNotEmpty) buf.write(mouth);
    // Hair.
    if (hair.isNotEmpty) buf.write(hair);
    // Beard.
    if (beard.isNotEmpty) buf.write(beard);
    // Glasses.
    if (glasses.isNotEmpty) buf.write(glasses);
    // Hat.
    if (hat.isNotEmpty) buf.write(hat);
    // Accessories (earrings etc).
    if (accessories.isNotEmpty) buf.write(accessories);

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Bottts (180 x 180)
  // ---------------------------------------------------------------------------

  static String? _composeBottts(AvatarConfig config) {
    final sh = _stableHash(config);
    final baseColor = _hashColor(sh, 10);

    final sides = _pick(botttsSides, sh, 1);
    final top = _pick(botttsTop, sh, 2);
    // Face has {{BASE_COLOR}} and {{TEXTURE}} placeholders.
    final face = _pick(botttsFace, sh, 3)
        .replaceAll('{{BASE_COLOR}}', baseColor)
        .replaceAll('{{TEXTURE}}', ''); // No texture files extracted.
    final mouth = _pick(botttsMouth, config.mouth.index, 4);
    final eyes = _pick(botttsEyes, config.eyes.index, 5);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 180 180" fill="none" ')
      ..write('shape-rendering="auto">');

    // Layer order: sides → top → face → mouth → eyes.
    if (sides.isNotEmpty) buf.write(_g(sides, 'translate(0 66)'));
    if (top.isNotEmpty) buf.write(_g(top, 'translate(41 0)'));
    if (face.isNotEmpty) buf.write(_g(face, 'translate(25 44)'));
    if (mouth.isNotEmpty) buf.write(_g(mouth, 'translate(52 124)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(38 76)'));

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Notionists (1744 x 1744)
  // ---------------------------------------------------------------------------

  static String? _composeNotionists(AvatarConfig config) {
    final sh = _stableHash(config);

    final base = _pick(notionistsBase, sh, 1);
    final body = _pick(notionistsBody, sh, 2);
    final hair = _pick(notionistsHair, config.hair.index, 3);
    final lips = _pick(notionistsLips, config.mouth.index, 4);
    final beard = _pick(notionistsBeard, sh, 5);
    final nose = _pick(notionistsNose, sh, 6);
    final eyes = _pick(notionistsEyes, config.eyes.index, 7);
    final glasses = _pick(notionistsGlasses, config.glasses.index, 8);
    final brows = _pick(notionistsBrows, config.eyebrows.index, 9);
    final gesture = _pick(notionistsGesture, sh, 10);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 1744 1744" fill="none" ')
      ..write('shape-rendering="auto">');

    // Layer order from DiceBear notionists index.ts.
    if (base.isNotEmpty) buf.write(_g(base, 'translate(531 487)'));
    if (body.isNotEmpty) buf.write(_g(body, 'translate(178 1057)'));
    if (hair.isNotEmpty) buf.write(_g(hair, 'translate(266 207)'));
    if (lips.isNotEmpty) buf.write(_g(lips, 'translate(791 871)'));
    if (beard.isNotEmpty) buf.write(_g(beard, 'translate(653 805)'));
    if (nose.isNotEmpty) buf.write(_g(nose, 'translate(901 668)'));
    if (eyes.isNotEmpty) buf.write(_g(eyes, 'translate(610 680)'));
    if (glasses.isNotEmpty) buf.write(_g(glasses, 'translate(610 680)'));
    if (brows.isNotEmpty) buf.write(_g(brows, 'translate(774 657)'));
    if (gesture.isNotEmpty) buf.write(_g(gesture, 'translate(0 559)'));

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Open Peeps (704 x 704)
  // ---------------------------------------------------------------------------

  static String? _composeOpenPeeps(AvatarConfig config) {
    final sh = _stableHash(config);
    final skinHex = '#${config.skinColor.hex}';
    final contrastHex = _darkenHex(skinHex, 0.8);
    final clothingColor = _hashColor(sh, 77);

    final head = _pick(openpeepsHead, config.hair.index, 1)
        .replaceAll('{{SKIN_COLOR}}', skinHex)
        .replaceAll('{{HEADCONTRAST_COLOR}}', contrastHex)
        .replaceAll('{{CLOTHING_COLOR}}', clothingColor);
    final face = _pick(openpeepsFace, config.eyes.index, 2);
    final facialHair = _pick(openpeepsFacialHair, sh, 3);
    final accessories = _pick(openpeepsAccessories, config.glasses.index, 4);
    final mask = _pick(openpeepsMask, sh, 5);

    // Open Peeps body base (bust silhouette).
    final body =
        '<path d="M325 580c-35 0-68 10-96 30-20 14-36 33-48 55l-2 4v35h346v-35'
        'l-2-4c-12-22-28-41-48-55-28-20-61-30-96-30h-54Z" fill="$skinHex"/>';

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 704 704" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write(body);

    // Head (contains hair + head shape + outline).
    if (head.isNotEmpty) {
      buf.write('<g transform="matrix(0.84 0 0 0.84 88 36)">$head</g>');
    }
    // Face expression.
    if (face.isNotEmpty) {
      buf.write(_g(face, 'translate(220 240)'));
    }
    // Facial hair.
    if (facialHair.isNotEmpty) {
      buf.write(_g(facialHair, 'translate(220 340)'));
    }
    // Accessories (piercings, headphones, etc.).
    if (accessories.isNotEmpty) {
      buf.write(_g(accessories, 'translate(170 180)'));
    }
    // Mask.
    if (mask.isNotEmpty) {
      buf.write(_g(mask, 'translate(210 300)'));
    }

    buf.write('</svg>');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Thumbs (100 x 100)
  // ---------------------------------------------------------------------------

  static String? _composeThumbs(AvatarConfig config) {
    final sh = _stableHash(config);
    final shapeColor = _hashColor(sh, 20);
    final eyeColor = _hashColor(sh, 30);
    final mouthColor = _hashColor(sh, 40);

    // Thumbs uses width-matched variants for eyes. Pick a base variant
    // plus a width suffix. Width offsets: 10, 12, 14, 16.
    final widths = ['W10', 'W12', 'W14', 'W16'];
    final widthIdx = (sh % widths.length).abs();
    final widthSuffix = widths[widthIdx];

    // Pick eyes variant base (variant1-variant9), append width suffix.
    final eyesKeys = thumbsEyes.keys
        .where((k) => k.endsWith(widthSuffix))
        .toList();
    final eyesSvg = eyesKeys.isNotEmpty
        ? (thumbsEyes[eyesKeys[(config.eyes.index % eyesKeys.length).abs()]] ??
                  '')
              .replaceAll('{{EYES_COLOR}}', eyeColor)
        : '';

    final mouthSvg = _pick(
      thumbsMouth,
      config.mouth.index,
      2,
    ).replaceAll('{{MOUTH_COLOR}}', mouthColor);

    // Face embeds eyes + mouth via placeholders.
    final faceSvg = _pick(
      thumbsFace,
      sh,
      3,
    ).replaceAll('{{EYES}}', eyesSvg).replaceAll('{{MOUTH}}', mouthSvg);

    // Shape embeds face.
    final shapeSvg = _pick(
      thumbsShape,
      sh,
      4,
    ).replaceAll('{{SHAPE_COLOR}}', shapeColor).replaceAll('{{FACE}}', faceSvg);

    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 100 100" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write(shapeSvg)
      ..write('</svg>');
    return buf.toString();
  }
}
