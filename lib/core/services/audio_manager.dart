import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../utils/game_log.dart';

final _log = GameLog.instance;

/// Engine sound category — each plane maps to one of these.
enum EngineType {
  /// Chuttering propeller (Classic Bi-Plane, Red Baron Triplane)
  biplane,

  /// Smooth propeller drone (Prop Plane, Warbird, Island Hopper)
  prop,

  /// Low heavy drone (Night Raider, Stealth Bomber)
  bomber,

  /// Smooth jet engine (Sleek Jet, Concorde, Padraigaer, Presidential, etc.)
  jet,

  /// Rocket roar (Rocket Ship)
  rocket,

  /// Just wind (Paper Plane)
  wind,
}

/// One-shot sound effect identifiers.
enum SfxType {
  /// Simple modern click when a clue pops up.
  cluePop,

  /// Satisfying confetti pop on successful landing.
  landingSuccess,

  /// Coin collect jingle.
  coinCollect,

  /// General UI tap/click.
  uiClick,

  /// Whoosh for altitude toggle.
  altitudeChange,

  /// Speed boost activation.
  boostStart,
}

/// Manages all game audio: background music, engine loops, and SFX.
///
/// Singleton — use [AudioManager.instance]. Call [initialize] once at startup.
/// The manager respects the user's sound toggle via [enabled].
///
/// Engine sounds loop continuously during gameplay. Volume responds to the
/// plane's turn intensity: louder when banking, quieter when flying straight.
class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  /// Whether audio is enabled (user preference).
  bool _enabled = true;

  bool get enabled => _enabled;

  set enabled(bool value) {
    final wasDisabled = !_enabled;
    _enabled = value;
    if (!value) {
      _stopAll();
    } else if (wasDisabled) {
      // Re-enabling audio — clear the failed-asset blacklist so tracks that
      // failed before the web audio context was unlocked get another chance.
      _failedAssets.clear();
      // Restart background music if it was previously playing.
      startMusic();
    }
  }

  /// Background music player.
  final AudioPlayer _musicPlayer = AudioPlayer();

  /// Engine loop player.
  final AudioPlayer _enginePlayer = AudioPlayer();

  /// Pool of SFX players (avoid creating per-play).
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());

  int _sfxPoolIndex = 0;

  /// Currently active engine type (null = none playing).
  EngineType? _currentEngine;

  /// Base volume for the engine (before turn modulation).
  static const double _engineBaseVolume = 0.12;

  /// Maximum additional volume added during full turn.
  static const double _engineTurnBoost = 0.08;

  /// Default background music volume.
  static const double _defaultMusicVolume = 0.25;

  /// Default SFX volume.
  static const double _defaultSfxVolume = 0.5;

  /// User-configurable music volume multiplier (0.0 = silent, 1.0 = full).
  double _musicVolume = 1.0;

  double get musicVolume => _musicVolume;

  set musicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    // Immediately update the playing music player volume.
    if (_enabled) {
      _musicPlayer.setVolume(_defaultMusicVolume * _musicVolume);
    }
  }

  /// User-configurable effects volume multiplier (0.0 = silent, 1.0 = full).
  /// Applies to both engine sounds and one-shot SFX.
  double _effectsVolume = 1.0;

  double get effectsVolume => _effectsVolume;

  set effectsVolume(double value) {
    _effectsVolume = value.clamp(0.0, 1.0);
    // Immediately update the playing engine volume.
    if (_enabled && _currentEngine != null) {
      _enginePlayer.setVolume(_engineBaseVolume * _effectsVolume);
    }
  }

  /// Whether [initialize] has been called.
  bool _initialized = false;

  /// Asset paths that have failed to load. Once an asset fails, we skip
  /// future attempts to avoid repeated errors (especially on Safari where
  /// MEDIA_ELEMENT_ERROR from missing files can destabilise the audio context).
  final Set<String> _failedAssets = {};

  // -----------------------------------------------------------------
  // Plane ID → Engine type mapping
  // -----------------------------------------------------------------

  /// Maps a cosmetic plane ID to its engine sound category.
  static EngineType engineTypeForPlane(String planeId) {
    switch (planeId) {
      // Chuttering propeller
      case 'plane_default': // Classic Bi-Plane
      case 'plane_red_baron': // Red Baron Triplane
        return EngineType.biplane;

      // Smooth propeller
      case 'plane_prop': // Prop Plane
      case 'plane_warbird': // Warbird
      case 'plane_seaplane': // Island Hopper
        return EngineType.prop;

      // Low drone
      case 'plane_night_raider': // Night Raider
      case 'plane_stealth': // Stealth Bomber
        return EngineType.bomber;

      // Rocket roar
      case 'plane_rocket': // Rocket Ship
        return EngineType.rocket;

      // Just wind
      case 'plane_paper': // Paper Plane
        return EngineType.wind;

      // Smooth jet (default for all jets, concordes, etc.)
      case 'plane_jet': // Sleek Jet
      case 'plane_padraigaer': // Padraigaer
      case 'plane_concorde_classic': // Concorde Classic
      case 'plane_presidential': // Presidential
      case 'plane_golden_jet': // Golden Private Jet
      case 'plane_diamond_concorde': // Diamond Concorde
      case 'plane_platinum_eagle': // Platinum Eagle
      default:
        return EngineType.jet;
    }
  }

  /// Asset path for an engine sound.
  static String _engineAsset(EngineType type) {
    switch (type) {
      case EngineType.biplane:
        return 'audio/engines/biplane_engine.mp3';
      case EngineType.prop:
        return 'audio/engines/prop_engine.mp3';
      case EngineType.bomber:
        return 'audio/engines/bomber_engine.mp3';
      case EngineType.jet:
        return 'audio/engines/jet_engine.mp3';
      case EngineType.rocket:
        return 'audio/engines/rocket_engine.mp3';
      case EngineType.wind:
        return 'audio/engines/wind.mp3';
    }
  }

  /// Asset path for a sound effect.
  static String _sfxAsset(SfxType type) {
    switch (type) {
      case SfxType.cluePop:
        return 'audio/sfx/clue_pop.mp3';
      case SfxType.landingSuccess:
        return 'audio/sfx/landing_success.mp3';
      case SfxType.coinCollect:
        return 'audio/sfx/coin_collect.mp3';
      case SfxType.uiClick:
        return 'audio/sfx/ui_click.mp3';
      case SfxType.altitudeChange:
        return 'audio/sfx/altitude_change.mp3';
      case SfxType.boostStart:
        return 'audio/sfx/boost_start.mp3';
    }
  }

  // -----------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------

  /// Initialise the audio system. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Set default release mode for all players.
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _enginePlayer.setReleaseMode(ReleaseMode.loop);
      for (final p in _sfxPool) {
        await p.setReleaseMode(ReleaseMode.release);
      }
      _log.info('audio', 'AudioManager initialized');
    } catch (e) {
      _log.warning('audio', 'AudioManager init failed', error: e);
    }
  }

  /// Release all players. Call on app dispose.
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _enginePlayer.dispose();
    for (final p in _sfxPool) {
      await p.dispose();
    }
    _initialized = false;
  }

  // -----------------------------------------------------------------
  // Background Music
  // -----------------------------------------------------------------

  /// Available music tracks (shuffled per session).
  static const List<String> _musicTracks = [
    'audio/music/lofi_track_01.mp3',
    'audio/music/lofi_track_02.mp3',
    'audio/music/lofi_track_03.mp3',
  ];

  int _currentTrackIndex = 0;

  /// Start playing background music. Shuffles track order.
  Future<void> startMusic() async {
    if (!_enabled) return;

    // Pick a random starting track.
    _currentTrackIndex = Random().nextInt(_musicTracks.length);
    await _playMusicTrack();
  }

  Future<void> _playMusicTrack() async {
    if (!_enabled) return;

    final asset = _musicTracks[_currentTrackIndex];

    // Skip assets that have already failed.
    if (_failedAssets.contains(asset)) return;

    try {
      await _musicPlayer.setVolume(_defaultMusicVolume * _musicVolume);
      await _musicPlayer.play(AssetSource(asset));
    } catch (e) {
      _log.warning('audio', 'Music track failed: $asset', error: e);
      _failedAssets.add(asset);
    }
  }

  /// Stop background music.
  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  /// Advance to next track (call from onPlayerComplete listener).
  Future<void> nextTrack() async {
    _currentTrackIndex = (_currentTrackIndex + 1) % _musicTracks.length;
    await _playMusicTrack();
  }

  // -----------------------------------------------------------------
  // Engine Sound
  // -----------------------------------------------------------------

  /// Start the engine loop for a given plane.
  ///
  /// Automatically selects the correct engine sound based on [planeId].
  /// If an engine is already playing for a different type, crossfades.
  Future<void> startEngine(String planeId) async {
    if (!_enabled) return;

    final type = engineTypeForPlane(planeId);

    // Already playing this engine type — no-op.
    if (_currentEngine == type) return;

    final asset = _engineAsset(type);

    // Skip assets that have already failed (avoids repeated errors on Safari).
    if (_failedAssets.contains(asset)) return;

    _currentEngine = type;

    try {
      await _enginePlayer.stop();
      await _enginePlayer.setVolume(_engineBaseVolume * _effectsVolume);
      await _enginePlayer.play(AssetSource(asset));
    } catch (e) {
      _log.warning('audio', 'Engine sound failed: $asset', error: e);
      _failedAssets.add(asset);
      _currentEngine =
          null; // Prevent updateEngineVolume from firing every frame
    }
  }

  /// Stop the engine loop.
  Future<void> stopEngine() async {
    _currentEngine = null;
    await _enginePlayer.stop();
  }

  /// Update engine volume based on turn intensity.
  ///
  /// Call this every frame from the game update loop.
  /// [turnAmount] should be the absolute value of the turn direction (0..1).
  Future<void> updateEngineVolume(double turnAmount) async {
    if (!_enabled || _currentEngine == null) return;

    final volume =
        ((_engineBaseVolume +
                    _engineTurnBoost * turnAmount.abs().clamp(0.0, 1.0)) *
                _effectsVolume)
            .clamp(0.0, 1.0);

    try {
      await _enginePlayer.setVolume(volume);
    } catch (e) {
      _log.warning('audio', 'Engine volume update failed', error: e);
    }
  }

  // -----------------------------------------------------------------
  // Sound Effects
  // -----------------------------------------------------------------

  /// Play a one-shot sound effect.
  Future<void> playSfx(SfxType type) async {
    if (!_enabled) return;

    final asset = _sfxAsset(type);

    // Skip assets that have already failed (avoids repeated errors on Safari).
    if (_failedAssets.contains(asset)) return;

    final player = _sfxPool[_sfxPoolIndex];
    _sfxPoolIndex = (_sfxPoolIndex + 1) % _sfxPool.length;

    try {
      await player.setVolume(_defaultSfxVolume * _effectsVolume);
      await player.play(AssetSource(asset));
    } catch (e) {
      _log.warning('audio', 'SFX failed: $asset', error: e);
      _failedAssets.add(asset);
    }
  }

  // -----------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------

  Future<void> _stopAll() async {
    await _musicPlayer.stop();
    await _enginePlayer.stop();
    for (final p in _sfxPool) {
      await p.stop();
    }
    _currentEngine = null;
  }
}
