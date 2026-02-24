import 'package:flit/data/models/avatar_config.dart';
import 'package:flit/features/avatar/avatar_compositor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarConfig custom colors', () {
    test('serializes and deserializes custom/equipped color maps', () {
      const config = AvatarConfig(
        customColors: {'eyesColor': 'ff0000'},
        equippedCustomColors: {'eyesColor': 'ff0000', 'glassesColor': '00ff00'},
      );

      final restored = AvatarConfig.fromJson(config.toJson());

      expect(restored.customColors, equals(config.customColors));
      expect(
        restored.equippedCustomColors,
        equals(config.equippedCustomColors),
      );
    });

    test('colorOverride falls back for invalid values', () {
      const config = AvatarConfig(
        equippedCustomColors: {'eyesColor': 'notHex'},
      );

      expect(config.colorOverride('eyesColor', '#112233'), equals('#112233'));
      expect(config.colorOverride('missing', '#112233'), equals('#112233'));
    });
  });

  group('AvatarCompositor custom color usage', () {
    test('applies equipped lorelei glasses custom color', () {
      const config = AvatarConfig(
        style: AvatarStyle.lorelei,
        glasses: AvatarGlasses.variant01,
        equippedCustomColors: {'glassesColor': '123456'},
      );

      final svg = AvatarCompositor.compose(config);

      expect(svg, isNotNull);
      expect(svg, contains('#123456'));
    });

    test('applies equipped pixel art clothing custom color', () {
      const config = AvatarConfig(
        style: AvatarStyle.pixelArt,
        equippedCustomColors: {'clothingColor': 'abcdef'},
      );

      final svg = AvatarCompositor.compose(config);

      expect(svg, isNotNull);
      expect(svg, contains('#abcdef'));
    });
  });
}
