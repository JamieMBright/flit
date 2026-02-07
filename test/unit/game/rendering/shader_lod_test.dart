import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/rendering/shader_lod.dart';

void main() {
  late ShaderLODManager manager;

  setUp(() {
    manager = ShaderLODManager(
      windowSize: 60,
      upgradeThresholdFps: 55.0,
      downgradeThresholdFps: 45.0,
      hysteresisFrames: 90,
    );
  });

  group('ShaderLODManager defaults', () {
    test('default LOD is high', () {
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });

    test('default average FPS is 60 when no frames recorded', () {
      expect(manager.averageFPS, closeTo(60.0, 0.01));
    });

    test('lodUniforms returns high-quality values by default', () {
      final uniforms = manager.lodUniforms;
      expect(uniforms['cloudIterations'], equals(8.0));
      expect(uniforms['foamQuality'], equals(1.0));
      expect(uniforms['atmosphereQuality'], equals(1.0));
      expect(uniforms['cityLightsEnabled'], equals(1.0));
    });
  });

  group('ShaderLODManager frame recording', () {
    test('average FPS is computed correctly', () {
      // Record 60 frames at 60fps (dt = 1/60 ~ 0.01667s)
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(1.0 / 60.0);
      }
      expect(manager.averageFPS, closeTo(60.0, 0.5));
    });

    test('ignores zero and negative frame times', () {
      manager.recordFrameTime(0.0);
      manager.recordFrameTime(-1.0);
      expect(manager.averageFPS, closeTo(60.0, 0.01)); // default
    });

    test('ignores absurdly large frame times (> 1 second)', () {
      manager.recordFrameTime(2.0);
      manager.recordFrameTime(5.0);
      expect(manager.averageFPS, closeTo(60.0, 0.01)); // default
    });
  });

  group('ShaderLODManager downgrade', () {
    test('recording sustained low FPS triggers downgrade to medium', () {
      // Fill window with 30fps frames
      const dt30fps = 1.0 / 30.0;
      // Fill the window first (60 frames)
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt30fps);
      }
      // Need 90 more frames at low FPS for hysteresis
      for (int i = 0; i < 90; i++) {
        manager.recordFrameTime(dt30fps);
      }

      expect(manager.currentLOD, equals(ShaderLOD.medium));
    });

    test('recording sustained low FPS triggers downgrade to low', () {
      const dt30fps = 1.0 / 30.0;
      // Fill window + hysteresis to go high -> medium
      for (int i = 0; i < 60 + 90; i++) {
        manager.recordFrameTime(dt30fps);
      }
      expect(manager.currentLOD, equals(ShaderLOD.medium));

      // Continue with low FPS for another hysteresis period to go medium -> low
      for (int i = 0; i < 90; i++) {
        manager.recordFrameTime(dt30fps);
      }
      expect(manager.currentLOD, equals(ShaderLOD.low));
    });

    test('already at low does not crash on further downgrades', () {
      manager.forceLevel(ShaderLOD.low);
      const dt30fps = 1.0 / 30.0;
      // Fill window + hysteresis
      for (int i = 0; i < 60 + 90; i++) {
        manager.recordFrameTime(dt30fps);
      }
      // Should stay at low without error
      expect(manager.currentLOD, equals(ShaderLOD.low));
    });
  });

  group('ShaderLODManager upgrade', () {
    test('recording sustained high FPS triggers upgrade from low to medium', () {
      manager.forceLevel(ShaderLOD.low);

      const dt60fps = 1.0 / 60.0;
      // Fill window (60 frames)
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt60fps);
      }
      // Hysteresis period (90 frames)
      for (int i = 0; i < 90; i++) {
        manager.recordFrameTime(dt60fps);
      }

      expect(manager.currentLOD, equals(ShaderLOD.medium));
    });

    test('recording sustained high FPS triggers upgrade from medium to high', () {
      manager.forceLevel(ShaderLOD.medium);

      const dt60fps = 1.0 / 60.0;
      // Fill window + hysteresis
      for (int i = 0; i < 60 + 90; i++) {
        manager.recordFrameTime(dt60fps);
      }

      expect(manager.currentLOD, equals(ShaderLOD.high));
    });

    test('already at high does not crash on further upgrades', () {
      const dt60fps = 1.0 / 60.0;
      for (int i = 0; i < 60 + 90; i++) {
        manager.recordFrameTime(dt60fps);
      }
      // Should stay at high without error
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });
  });

  group('ShaderLODManager hysteresis', () {
    test('brief FPS dip does not trigger downgrade', () {
      // Start with good FPS to fill window
      const dt60fps = 1.0 / 60.0;
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt60fps);
      }

      // Brief dip: 30 frames at low FPS (less than hysteresis threshold of 90)
      const dt30fps = 1.0 / 30.0;
      for (int i = 0; i < 30; i++) {
        manager.recordFrameTime(dt30fps);
      }

      // Return to good FPS
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt60fps);
      }

      // Should still be at high since the dip was too brief
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });

    test('alternating good/bad FPS does not trigger changes', () {
      const dt60fps = 1.0 / 60.0;
      const dt30fps = 1.0 / 30.0;

      // Fill window first
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt60fps);
      }

      // Alternate every 20 frames between good and bad
      for (int cycle = 0; cycle < 10; cycle++) {
        for (int i = 0; i < 20; i++) {
          manager.recordFrameTime(dt30fps);
        }
        for (int i = 0; i < 20; i++) {
          manager.recordFrameTime(dt60fps);
        }
      }

      // Should still be high because neither counter reaches hysteresis threshold
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });

    test('FPS in the OK zone resets counters', () {
      // Fill with good frames
      const dt60fps = 1.0 / 60.0;
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt60fps);
      }

      // Accumulate some downgrade pressure (but not enough)
      const dt30fps = 1.0 / 30.0;
      for (int i = 0; i < 50; i++) {
        manager.recordFrameTime(dt30fps);
      }

      // Inject frames in the "OK" zone (between 45-55 fps) to reset counters
      const dt50fps = 1.0 / 50.0;
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(dt50fps);
      }

      // Now add more bad frames (50 more, total NOT accumulated from before)
      for (int i = 0; i < 50; i++) {
        manager.recordFrameTime(dt30fps);
      }

      // Should still be high: the OK zone frames reset the counter
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });
  });

  group('ShaderLODManager lodUniforms', () {
    test('medium LOD has reduced cloud iterations', () {
      manager.forceLevel(ShaderLOD.medium);
      final uniforms = manager.lodUniforms;
      expect(uniforms['cloudIterations'], equals(4.0));
      expect(uniforms['foamQuality'], equals(0.0));
    });

    test('low LOD has no clouds and no foam', () {
      manager.forceLevel(ShaderLOD.low);
      final uniforms = manager.lodUniforms;
      expect(uniforms['cloudIterations'], equals(0.0));
      expect(uniforms['foamQuality'], equals(0.0));
      expect(uniforms['cityLightsEnabled'], equals(0.0));
    });

    test('all LOD levels have all required uniform keys', () {
      const requiredKeys = [
        'cloudIterations',
        'foamQuality',
        'atmosphereQuality',
        'cityLightsEnabled',
      ];

      for (final level in ShaderLOD.values) {
        manager.forceLevel(level);
        final uniforms = manager.lodUniforms;
        for (final key in requiredKeys) {
          expect(uniforms.containsKey(key), isTrue,
              reason: '${level.name} missing key: $key');
        }
      }
    });
  });

  group('ShaderLODManager reset', () {
    test('reset restores high LOD', () {
      manager.forceLevel(ShaderLOD.low);
      manager.reset();
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });

    test('reset clears frame history', () {
      for (int i = 0; i < 60; i++) {
        manager.recordFrameTime(1.0 / 30.0);
      }
      manager.reset();
      // Default FPS (no data) should be 60
      expect(manager.averageFPS, closeTo(60.0, 0.01));
    });
  });

  group('ShaderLODManager forceLevel', () {
    test('forceLevel sets the LOD directly', () {
      manager.forceLevel(ShaderLOD.low);
      expect(manager.currentLOD, equals(ShaderLOD.low));

      manager.forceLevel(ShaderLOD.medium);
      expect(manager.currentLOD, equals(ShaderLOD.medium));

      manager.forceLevel(ShaderLOD.high);
      expect(manager.currentLOD, equals(ShaderLOD.high));
    });
  });
}
