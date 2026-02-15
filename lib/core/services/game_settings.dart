import 'package:flutter/foundation.dart';

/// Map tile style for descent mode — different visual themes.
/// All tile servers are free and open-license (no API key required).
enum MapStyle {
  /// OpenStreetMap default — light, detailed, familiar.
  standard,

  /// CARTO Dark Matter — dark background, subtle labels.
  dark,

  /// CARTO Voyager — colorful, modern, easy to read.
  voyager,

  /// OpenTopoMap — topographic with elevation contours.
  topo,
}

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

  /// When true, left input steers the plane right (and vice versa).
  /// Some players prefer this for a behind-the-plane camera feel.
  /// Default is false: left input = left turn (direct mapping).
  bool _invertControls = false;

  bool get invertControls => _invertControls;

  set invertControls(bool value) {
    _invertControls = value;
    notifyListeners();
  }

  // ─── Display ────────────────────────────────────────────────────

  /// When false, the globe is always fully lit (daytime everywhere).
  /// No city lights, no terminator glow, no stars behind the globe.
  bool _enableNight = true;

  bool get enableNight => _enableNight;

  set enableNight(bool value) {
    _enableNight = value;
    notifyListeners();
  }

  /// Map tile style for descent mode (OSM, dark, voyager, topo).
  MapStyle _mapStyle = MapStyle.dark;

  MapStyle get mapStyle => _mapStyle;

  set mapStyle(MapStyle value) {
    _mapStyle = value;
    notifyListeners();
  }

  /// Tile URL template for the selected map style.
  String get mapTileUrl {
    switch (_mapStyle) {
      case MapStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case MapStyle.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case MapStyle.topo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  /// Human-readable label for the selected map style.
  String get mapStyleLabel {
    switch (_mapStyle) {
      case MapStyle.standard:
        return 'Standard';
      case MapStyle.dark:
        return 'Dark';
      case MapStyle.voyager:
        return 'Voyager';
      case MapStyle.topo:
        return 'Topo';
    }
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
