import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/audio_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the audioplayers plugin to avoid MissingPluginException
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (MethodCall methodCall) async {
            // Mock all audioplayers method calls
            switch (methodCall.method) {
              case 'create':
                return 'player-id-${DateTime.now().millisecondsSinceEpoch}';
              case 'setUrl':
              case 'setVolume':
              case 'setReleaseMode':
              case 'resume':
              case 'pause':
              case 'stop':
              case 'release':
              case 'seek':
              case 'setPlaybackRate':
              case 'getDuration':
              case 'getCurrentPosition':
              case 'setSourceUrl':
              case 'setSourceBytes':
              case 'setSourceAsset':
                return null;
              default:
                return null;
            }
          },
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          null,
        );
  });

  group('AudioManager - Singleton', () {
    test('returns the same instance every time', () {
      final a = AudioManager.instance;
      final b = AudioManager.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('AudioManager - Enabled Toggle', () {
    test('defaults to enabled', () {
      expect(AudioManager.instance.enabled, isTrue);
    });

    test('can be disabled and re-enabled', () {
      final manager = AudioManager.instance;
      manager.enabled = false;
      expect(manager.enabled, isFalse);
      manager.enabled = true;
      expect(manager.enabled, isTrue);
    });
  });

  group('AudioManager - Engine Type Mapping', () {
    test('Classic Bi-Plane maps to biplane engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_default'),
        EngineType.biplane,
      );
    });

    test('Red Baron Triplane maps to biplane engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_red_baron'),
        EngineType.biplane,
      );
    });

    test('Paper Plane maps to wind', () {
      expect(AudioManager.engineTypeForPlane('plane_paper'), EngineType.wind);
    });

    test('Prop Plane maps to prop engine', () {
      expect(AudioManager.engineTypeForPlane('plane_prop'), EngineType.prop);
    });

    test('Warbird maps to prop engine', () {
      expect(AudioManager.engineTypeForPlane('plane_warbird'), EngineType.prop);
    });

    test('Island Hopper maps to prop engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_seaplane'),
        EngineType.prop,
      );
    });

    test('Night Raider maps to bomber engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_night_raider'),
        EngineType.bomber,
      );
    });

    test('Stealth Bomber maps to bomber engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_stealth'),
        EngineType.bomber,
      );
    });

    test('Sleek Jet maps to jet engine', () {
      expect(AudioManager.engineTypeForPlane('plane_jet'), EngineType.jet);
    });

    test('Padraigaer maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_padraigaer'),
        EngineType.jet,
      );
    });

    test('Concorde Classic maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_concorde_classic'),
        EngineType.jet,
      );
    });

    test('Presidential maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_presidential'),
        EngineType.jet,
      );
    });

    test('Golden Private Jet maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_golden_jet'),
        EngineType.jet,
      );
    });

    test('Diamond Concorde maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_diamond_concorde'),
        EngineType.jet,
      );
    });

    test('Platinum Eagle maps to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_platinum_eagle'),
        EngineType.jet,
      );
    });

    test('Rocket Ship maps to rocket engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_rocket'),
        EngineType.rocket,
      );
    });

    test('unknown plane ID falls back to jet engine', () {
      expect(
        AudioManager.engineTypeForPlane('plane_unknown_future'),
        EngineType.jet,
      );
    });
  });

  group('EngineType', () {
    test('has 6 values', () {
      expect(EngineType.values, hasLength(6));
    });
  });

  group('SfxType', () {
    test('has 6 values', () {
      expect(SfxType.values, hasLength(6));
    });
  });
}
