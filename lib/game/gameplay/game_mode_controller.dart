import 'dart:math';

import '../map/region.dart';
import '../session/game_session.dart';
import '../rendering/region_camera_presets.dart';

/// Game mode types.
enum GameMode {
  /// Single player, no time pressure.
  solo,

  /// Head-to-head or timed challenge.
  challenge,

  /// Same puzzle for all players each day.
  daily,
}

/// Manages game mode lifecycle with the globe renderer.
///
/// Coordinates game session creation, camera positioning via
/// [RegionCameraPresets], landing processing, and scoring.
class GameModeController {
  GameModeController({
    required this.region,
    this.mode = GameMode.solo,
  });

  /// The active game region.
  final GameRegion region;

  /// The active game mode.
  final GameMode mode;

  /// The current game session, or null if no game is active.
  GameSession? _currentSession;

  /// Whether the current session has been completed.
  bool _isComplete = false;

  /// Most recent score (0 if no game completed yet).
  int _lastScore = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The current game session, if any.
  GameSession? get currentSession => _currentSession;

  /// Whether the current game round is complete (landed successfully).
  bool get isComplete => _isComplete;

  /// The most recently calculated score.
  int get lastScore => _lastScore;

  /// The camera preset for the current region.
  CameraPreset get cameraPreset => RegionCameraPresets.getPreset(region);

  /// Starts a new game by creating a random session for the current
  /// region and game mode.
  ///
  /// For [GameMode.daily], the seed is derived from the current date so
  /// that all players get the same puzzle.
  void startNewGame() {
    _isComplete = false;
    _lastScore = 0;

    switch (mode) {
      case GameMode.solo:
        _currentSession = GameSession.random(region: region);
      case GameMode.challenge:
        _currentSession = GameSession.random(region: region);
      case GameMode.daily:
        // Deterministic seed from today's date for globally-shared puzzle.
        final now = DateTime.now();
        final seed = now.year * 10000 + now.month * 100 + now.day;
        _currentSession = GameSession.seeded(seed);
    }
  }

  /// Processes a landing attempt.
  ///
  /// [areaCode] is the code of the area the player landed on (e.g. 'US',
  /// 'CA', 'GLA'). Returns `true` if the landing was on the correct target.
  bool onLanding(String areaCode) {
    final session = _currentSession;
    if (session == null || _isComplete) return false;

    // Check if the landed area matches the target.
    final isCorrect = areaCode == session.targetCountry.code;

    if (isCorrect) {
      session.complete();
      _isComplete = true;
      _lastScore = calculateScore(session.elapsed);
    }

    return isCorrect;
  }

  /// Calculates the score for a completed flight.
  ///
  /// Scoring formula: 10000 base, minus 10 points per second of flight time.
  /// Minimum score is 0 (no negative scores).
  int calculateScore(Duration flightTime) {
    final seconds = flightTime.inSeconds;
    return max(0, 10000 - (seconds * 10));
  }

  /// Resets the controller, clearing the current session.
  void reset() {
    _currentSession = null;
    _isComplete = false;
    _lastScore = 0;
  }

  /// Returns the start position for the current session as [lat, lng].
  ///
  /// Returns the region center if no session is active.
  List<double> get startPosition {
    final session = _currentSession;
    if (session != null) {
      return [session.startPosition.y, session.startPosition.x];
    }
    final preset = cameraPreset;
    return [preset.centerLat, preset.centerLng];
  }

  /// Returns the target display name for the HUD.
  String get targetName => _currentSession?.targetName ?? '';

  /// Returns the clue display text for the HUD.
  String get clueText => _currentSession?.clue.displayText ?? '';
}
