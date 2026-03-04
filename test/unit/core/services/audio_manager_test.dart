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

  group('SfxType', () {
    test('has 6 values', () {
      expect(SfxType.values, hasLength(6));
    });
  });
}
