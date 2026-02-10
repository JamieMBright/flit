import 'package:flutter/foundation.dart';

/// Game difficulty level — affects country selection and hint availability.
enum GameDifficulty {
  /// Well-known countries, extra hints, skip clue option.
  easy,

  /// Standard difficulty — balanced country pool, normal hints.
  normal,

  /// Obscure countries, fewer hints, no skip.
  hard,
}

/// Singleton that holds user-configurable game settings.
///
/// All settings are stored in memory. Persistence (SharedPreferences)
/// will be added in a future update. The singleton is accessed from
/// both the settings UI and from the Flame game loop.
class GameSettings extends ChangeNotifier {
  GameSettings._();

  /// Singleton instance.
  static final GameSettings instance = GameSettings._();

  // ─── Controls ───────────────────────────────────────────────────

  /// Turn sensitivity multiplier applied to drag input.
  /// Range: 0.2 (very sluggish) to 1.5 (very twitchy).
  /// Default: 0.5.
  double _turnSensitivity = 0.5;

  double get turnSensitivity => _turnSensitivity;

  set turnSensitivity(double value) {
    _turnSensitivity = value.clamp(0.2, 1.5);
    notifyListeners();
  }

  /// Human-readable label for the current sensitivity level.
  String get sensitivityLabel {
    if (_turnSensitivity <= 0.3) return 'Low';
    if (_turnSensitivity <= 0.6) return 'Medium';
    if (_turnSensitivity <= 1.0) return 'High';
    return 'Very High';
  }

  /// When true, dragging right banks the plane left (and vice versa).
  /// This is the default "natural" feel for a behind-the-plane camera.
  bool _invertControls = true;

  bool get invertControls => _invertControls;

  set invertControls(bool value) {
    _invertControls = value;
    notifyListeners();
  }

  // ─── Display ────────────────────────────────────────────────────

  /// When false, the globe renders the raw satellite texture with no
  /// diffuse lighting, ocean effects, foam, clouds, or atmosphere.
  bool _enableShading = true;

  bool get enableShading => _enableShading;

  set enableShading(bool value) {
    _enableShading = value;
    notifyListeners();
  }

  /// When false, the globe is always fully lit (daytime everywhere).
  /// No city lights, no terminator glow, no stars behind the globe.
  bool _enableNight = true;

  bool get enableNight => _enableNight;

  set enableNight(bool value) {
    _enableNight = value;
    notifyListeners();
  }

  // ─── Gameplay ───────────────────────────────────────────────────

  /// Game difficulty for non-daily modes (free flight, training, dogfight).
  /// Daily challenge ignores this setting.
  GameDifficulty _difficulty = GameDifficulty.normal;

  GameDifficulty get difficulty => _difficulty;

  set difficulty(GameDifficulty value) {
    _difficulty = value;
    notifyListeners();
  }

  /// Human-readable label for the current difficulty.
  String get difficultyLabel {
    switch (_difficulty) {
      case GameDifficulty.easy:
        return 'Easy';
      case GameDifficulty.normal:
        return 'Normal';
      case GameDifficulty.hard:
        return 'Hard';
    }
  }
}
