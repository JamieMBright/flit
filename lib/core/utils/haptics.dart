import 'package:flutter/services.dart';

import '../services/game_settings.dart';

/// Haptic feedback helpers gated by the user's "Haptic Feedback" setting.
///
/// These are the only sanctioned entry points for vibration — calling
/// [HapticFeedback] directly would bypass the settings toggle. Safe on
/// web/desktop where the engine treats haptics as a no-op.
void hapticLight() {
  if (GameSettings.instance.hapticEnabled) HapticFeedback.lightImpact();
}

void hapticMedium() {
  if (GameSettings.instance.hapticEnabled) HapticFeedback.mediumImpact();
}

void hapticSuccess() {
  if (GameSettings.instance.hapticEnabled) HapticFeedback.heavyImpact();
}
