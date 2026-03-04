import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../utils/game_log.dart';

final _log = GameLog.instance;

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

/// Manages all game audio: background music and one-shot SFX.
///
/// Singleton — use [AudioManager.instance]. Call [initialize] once at startup.
/// The manager respects the user's sound toggle via [enabled].
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
      _setEnabledAsync(false);
    } else if (wasDisabled) {
      _setEnabledAsync(true);
    }
  }

  /// Serialise enable/disable operations so stop() completes before play().
  Future<void>? _pendingToggle;

  Future<void> _setEnabledAsync(bool enabling) async {
    // Wait for any previous toggle to finish before starting a new one.
    final prev = _pendingToggle;
    final future = _doSetEnabled(enabling, prev);
    _pendingToggle = future;
    await future;
  }

  Future<void> _doSetEnabled(bool enabling, Future<void>? prev) async {
    try {
      await prev;
    } catch (_) {}
    if (enabling) {
      if (!_enabled) return; // User toggled off again while we waited.
      _failedAssets.clear();
      await startMusic();
    } else {
      await _stopAll();
    }
  }

  /// Background music player.
  final AudioPlayer _musicPlayer = AudioPlayer();

  /// Pool of SFX players (avoid creating per-play).
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());

  int _sfxPoolIndex = 0;

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
      _applyMusicVolume();
    }
  }

  /// Apply the current music volume to the music player.
  Future<void> _applyMusicVolume() async {
    await _musicPlayer.setVolume(_defaultMusicVolume * _musicVolume);
  }

  /// User-configurable effects volume multiplier (0.0 = silent, 1.0 = full).
  /// Applies to one-shot SFX.
  double _effectsVolume = 1.0;

  double get effectsVolume => _effectsVolume;

  set effectsVolume(double value) {
    _effectsVolume = value.clamp(0.0, 1.0);
    // Note: On iOS Safari, programmatic volume control is ignored by the
    // browser — only the hardware volume buttons affect audio. This is a
    // WebKit limitation and cannot be worked around.
  }

  /// Whether [initialize] has been called.
  bool _initialized = false;

  /// Asset paths that have failed to load. Once an asset fails, we skip
  /// future attempts to avoid repeated errors (especially on Safari where
  /// MEDIA_ELEMENT_ERROR from missing files can destabilise the audio context).
  final Set<String> _failedAssets = {};

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
      final msg = e.toString();
      if (msg.contains('NotAllowedError') || msg.contains('not allowed')) {
        return; // Temporary — clears after user gesture.
      }
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
      // Don't blacklist on NotAllowedError — this is a temporary browser
      // autoplay restriction that clears after the first user gesture.
      final msg = e.toString();
      if (msg.contains('NotAllowedError') || msg.contains('not allowed')) {
        return;
      }
      _log.warning('audio', 'SFX failed: $asset', error: e);
      _failedAssets.add(asset);
    }
  }

  // -----------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------

  Future<void> _stopAll() async {
    await _musicPlayer.stop();
    for (final p in _sfxPool) {
      await p.stop();
    }
  }
}
