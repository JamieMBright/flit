import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/services/user_preferences_service.dart';

void main() {
  group('real-time control settings', () {
    test('snapshot maps legacy joystick settings to the new mode', () {
      final snapshot = UserPreferencesSnapshot(
        profile: {'id': 'pilot'},
        settings: {'enable_joystick': true},
      );

      expect(snapshot.controlMode, 'joystick');
      expect(snapshot.controlPlacement, 'lowerCenter');
      expect(snapshot.clueTrigger, 'button');
    });

    test('invalid remote control values use safe defaults', () {
      final snapshot = UserPreferencesSnapshot(
        profile: {'id': 'pilot'},
        settings: {
          'control_mode': 'sideways',
          'control_placement': 42,
          'clue_trigger': 'hover',
          'enable_joystick': false,
        },
      );

      expect(snapshot.controlMode, 'classic');
      expect(snapshot.controlPlacement, 'lowerCenter');
      expect(snapshot.clueTrigger, 'button');
    });

    test('explicit control settings survive snapshot parsing', () {
      final snapshot = UserPreferencesSnapshot(
        profile: {'id': 'pilot'},
        settings: {
          'control_mode': 'dPad',
          'control_placement': 'right',
          'clue_trigger': 'controlDoubleTap',
        },
      );

      expect(snapshot.controlMode, 'dPad');
      expect(snapshot.controlPlacement, 'right');
      expect(snapshot.clueTrigger, 'controlDoubleTap');
    });
  });
}
