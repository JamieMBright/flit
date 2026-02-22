import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/user_preferences_service.dart';
import 'audio_manager.dart';

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
/// Settings are synced to Supabase via [UserPreferencesService] (debounced).
/// The singleton is accessed from both the settings UI and the Flame game loop.
class GameSettings extends ChangeNotifier {
  GameSettings._() {
    addListener(_syncToSupabase);
    addListener(_syncToLocal);
  }

  /// Singleton instance.
  static final GameSettings instance = GameSettings._();

  static const String _prefsKey = 'game_settings';

  bool _hydrating = false;

  void _syncToSupabase() {
    if (_hydrating) return;
    UserPreferencesService.instance.saveSettings(
      turnSensitivity: _turnSensitivity,
      invertControls: _invertControls,
      enableNight: _enableNight,
      mapStyle: _mapStyle.name,
      englishLabels: _englishLabels,
      difficulty: _difficulty.name,
      soundEnabled: _soundEnabled,
      musicVolume: _musicVolume,
      effectsVolume: _effectsVolume,
      notificationsEnabled: _notificationsEnabled,
      hapticEnabled: _hapticEnabled,
    );
  }

  /// Persist settings to SharedPreferences on every change so they survive
  /// browser refresh / app restart even when Supabase is unreachable.
  void _syncToLocal() {
    if (_hydrating) return;
    _saveToLocal();
  }

  /// Bulk-set all fields from Supabase snapshot without triggering writes back.
  Future<void> hydrateFrom({
    required double turnSensitivity,
    required bool invertControls,
    required bool enableNight,
    required bool englishLabels,
    required MapStyle mapStyle,
    required GameDifficulty difficulty,
    required bool soundEnabled,
    required double musicVolume,
    required double effectsVolume,
    required bool notificationsEnabled,
    required bool hapticEnabled,
  }) async {
    _hydrating = true;
    this.turnSensitivity = turnSensitivity;
    this.invertControls = invertControls;
    this.enableNight = enableNight;
    this.englishLabels = englishLabels;
    this.mapStyle = mapStyle;
    this.difficulty = difficulty;
    this.soundEnabled = soundEnabled;
    this.musicVolume = musicVolume;
    this.effectsVolume = effectsVolume;
    this.notificationsEnabled = notificationsEnabled;
    this.hapticEnabled = hapticEnabled;
    await _saveToLocal();
    _hydrating = false;
  }

  // ─── Local Persistence ──────────────────────────────────────────

  /// Serialises all current settings to SharedPreferences.
  /// Called after every Supabase hydration so the local cache stays current.
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'turn_sensitivity': _turnSensitivity,
        'invert_controls': _invertControls,
        'enable_night': _enableNight,
        'map_style': _mapStyle.name,
        'english_labels': _englishLabels,
        'difficulty': _difficulty.name,
        'sound_enabled': _soundEnabled,
        'music_volume': _musicVolume,
        'effects_volume': _effectsVolume,
        'notifications_enabled': _notificationsEnabled,
        'haptic_enabled': _hapticEnabled,
      };
      await prefs.setString(_prefsKey, json.encode(data));
    } catch (_) {
      // Best-effort local cache — don't crash on failure
    }
  }

  /// Reads settings from SharedPreferences and hydrates the singleton.
  ///
  /// Returns `true` if cached settings were found and applied, `false` if no
  /// cache exists yet (first launch, cleared storage, etc.).
  ///
  /// Call this early in `main()` — before `runApp()` — so the user sees their
  /// real settings immediately, even before Supabase has responded.
  Future<bool> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return false;
      final data = json.decode(raw) as Map<String, dynamic>;
      _hydrating = true;
      _turnSensitivity =
          (data['turn_sensitivity'] as num?)?.toDouble() ?? _turnSensitivity;
      _invertControls = data['invert_controls'] as bool? ?? _invertControls;
      _enableNight = data['enable_night'] as bool? ?? _enableNight;
      final mapStyleName = data['map_style'] as String?;
      if (mapStyleName != null) {
        _mapStyle = MapStyle.values.firstWhere(
          (s) => s.name == mapStyleName,
          orElse: () => _mapStyle,
        );
      }
      _englishLabels = data['english_labels'] as bool? ?? _englishLabels;
      final diffName = data['difficulty'] as String?;
      if (diffName != null) {
        _difficulty = GameDifficulty.values.firstWhere(
          (d) => d.name == diffName,
          orElse: () => _difficulty,
        );
      }
      _soundEnabled = data['sound_enabled'] as bool? ?? _soundEnabled;
      _musicVolume = (data['music_volume'] as num?)?.toDouble() ?? _musicVolume;
      _effectsVolume =
          (data['effects_volume'] as num?)?.toDouble() ?? _effectsVolume;
      _notificationsEnabled =
          data['notifications_enabled'] as bool? ?? _notificationsEnabled;
      _hapticEnabled = data['haptic_enabled'] as bool? ?? _hapticEnabled;
      // Sync audio manager state from loaded values — the setters above
      // bypassed the public setters which normally do this.
      AudioManager.instance.enabled = _soundEnabled;
      AudioManager.instance.musicVolume = _musicVolume;
      AudioManager.instance.effectsVolume = _effectsVolume;

      // Notify listeners while still hydrating so _syncToSupabase is blocked.
      // This prevents locally-cached settings from being written to Supabase
      // before loadFromSupabase has a chance to fetch the authoritative data.
      notifyListeners();
      _hydrating = false;
      return true;
    } catch (_) {
      return false;
    }
  }

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
  MapStyle _mapStyle = MapStyle.topo;

  MapStyle get mapStyle => _mapStyle;

  set mapStyle(MapStyle value) {
    _mapStyle = value;
    notifyListeners();
  }

  /// Tile URL template for the selected map style.
  /// Appends `?language=en` to CARTO tiles when [englishLabels] is true.
  String get mapTileUrl {
    final langSuffix = _englishLabels ? '?language=en' : '';
    switch (_mapStyle) {
      case MapStyle.standard:
        // OSM default tiles don't support language parameter.
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png$langSuffix';
      case MapStyle.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png$langSuffix';
      case MapStyle.topo:
        // OpenTopoMap doesn't support language parameter.
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

  /// Whether to force English labels on map tiles (where supported).
  /// CARTO tiles (dark, voyager) support `?language=en`.
  /// OpenStreetMap and OpenTopoMap always use local-language labels.
  bool _englishLabels = true;

  bool get englishLabels => _englishLabels;

  set englishLabels(bool value) {
    _englishLabels = value;
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

  // ─── Audio & Feedback ─────────────────────────────────────────

  /// Whether sound effects and music are enabled.
  /// Also drives [AudioManager.instance.enabled].
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  set soundEnabled(bool value) {
    _soundEnabled = value;
    AudioManager.instance.enabled = value;
    notifyListeners();
  }

  /// Background music volume (0.0 = silent, 1.0 = full).
  /// Multiplied with AudioManager's base music level.
  double _musicVolume = 1.0;

  double get musicVolume => _musicVolume;

  set musicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    AudioManager.instance.musicVolume = _musicVolume;
    notifyListeners();
  }

  /// Human-readable label for the music volume.
  String get musicVolumeLabel => '${(_musicVolume * 100).round()}%';

  /// Game effects volume (0.0 = silent, 1.0 = full).
  /// Applies to engine sounds and one-shot SFX.
  double _effectsVolume = 1.0;

  double get effectsVolume => _effectsVolume;

  set effectsVolume(double value) {
    _effectsVolume = value.clamp(0.0, 1.0);
    AudioManager.instance.effectsVolume = _effectsVolume;
    notifyListeners();
  }

  /// Human-readable label for the effects volume.
  String get effectsVolumeLabel => '${(_effectsVolume * 100).round()}%';

  /// Whether push notifications are enabled.
  bool _notificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;

  set notificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }

  /// Whether haptic feedback (vibrations) are enabled.
  bool _hapticEnabled = true;

  bool get hapticEnabled => _hapticEnabled;

  set hapticEnabled(bool value) {
    _hapticEnabled = value;
    notifyListeners();
  }
}
