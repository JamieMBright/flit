import '../../data/models/avatar_config.dart';
import 'parts/adventurer_base.dart';
import 'parts/adventurer_earrings.dart';
import 'parts/adventurer_eyebrows.dart';
import 'parts/adventurer_eyes.dart';
import 'parts/adventurer_features.dart';
import 'parts/adventurer_glasses.dart';
import 'parts/adventurer_hair.dart';
import 'parts/adventurer_mouth.dart';

/// Composes a complete SVG string locally from DiceBear Adventurer parts.
///
/// Eliminates all network calls — parts are stored as compile-time Dart string
/// constants extracted from the DiceBear open-source repo (MIT license).
///
/// Composition follows the exact DiceBear Adventurer layer order:
///   base (skin) → eyes → eyebrows → mouth → features → glasses → hair → earrings
///
/// The `base` layer uses the 762×762 viewBox coordinate space directly.
/// All other layers are wrapped in `<g transform="translate(-161 -83)">` to
/// shift from Figma's export coordinate space into the 762×762 viewBox.
class AvatarCompositor {
  AvatarCompositor._();

  /// Compose a complete SVG string for the given [config].
  ///
  /// Only the [AvatarStyle.adventurer] style is composited locally.
  /// Returns `null` for unsupported styles so callers can fall back.
  static String? compose(AvatarConfig config) {
    if (config.style != AvatarStyle.adventurer) return null;

    final skinHex = '#${config.skinColor.hex}';
    final hairHex = '#${config.hairColor.hex}';

    // Base layer — uses {{SKIN_COLOR}} placeholder.
    final base = adventurerBase.replaceAll('{{SKIN_COLOR}}', skinHex);

    // Feature layers — lookup from constant maps.
    final eyes = adventurerEyes[config.eyes.apiValue] ?? '';
    final eyebrows = adventurerEyebrows[config.eyebrows.apiValue] ?? '';
    final mouth = adventurerMouth[config.mouth.apiValue] ?? '';

    // Optional layers — empty string when "none" is selected.
    final features = config.feature == AvatarFeature.none
        ? ''
        : adventurerFeatures[config.feature.name] ?? '';

    final glasses = config.glasses == AvatarGlasses.none
        ? ''
        : adventurerGlasses[config.glasses.apiValue] ?? '';

    final hair = config.hair == AvatarHair.none
        ? ''
        : (adventurerHair[config.hair.apiValue] ?? '')
            .replaceAll('{{HAIR_COLOR}}', hairHex);

    final earrings = config.earrings == AvatarEarrings.none
        ? ''
        : adventurerEarrings[config.earrings.apiValue] ?? '';

    // Assemble — exact DiceBear layer order and transforms.
    final buf = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="0 0 762 762" fill="none" ')
      ..write('shape-rendering="auto">')
      ..write(base);

    void _addLayer(String svg) {
      if (svg.isNotEmpty) {
        buf
          ..write('<g transform="translate(-161 -83)">')
          ..write(svg)
          ..write('</g>');
      }
    }

    _addLayer(eyes);
    _addLayer(eyebrows);
    _addLayer(mouth);
    _addLayer(features);
    _addLayer(glasses);
    _addLayer(hair);
    _addLayer(earrings);

    buf.write('</svg>');
    return buf.toString();
  }
}
