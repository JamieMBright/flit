import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/services/audio_manager.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../game/flit_game.dart';
import '../../game/map/region.dart';
import '../../game/session/game_session.dart';
import '../../game/ui/game_hud.dart';

final _log = GameLog.instance;

/// Main play screen with game canvas and HUD overlay.
///
/// Supports multi-round play: when [totalRounds] > 1, the player
/// automatically advances through rounds without landing until the
/// final round.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    this.region = GameRegion.world,
    this.challengeFriendName,
    this.totalRounds = 1,
    this.coinReward = 0,
    this.onComplete,
    this.planeColorScheme,
    this.equippedPlaneId = 'plane_default',
  });

  /// The region to play in.
  final GameRegion region;

  /// When non-null, the game is played as a challenge round against this friend.
  final String? challengeFriendName;

  /// Number of rounds to play back-to-back. 1 = single round.
  /// For Training Sortie this is 10.
  final int totalRounds;

  /// Coins awarded on completion.
  final int coinReward;

  /// Called when the full session completes with the total score.
  final void Function(int totalScore)? onComplete;

  /// Color scheme for the equipped plane cosmetic.
  final Map<String, int>? planeColorScheme;

  /// Equipped plane ID for engine sound selection.
  final String equippedPlaneId;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final FlitGame _game;
  GameSession? _session;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isHighAltitude = true;
  bool _gameReady = false;
  String? _error;

  /// Current round (1-indexed).
  int _currentRound = 1;

  /// Accumulated score across all rounds.
  int _totalScore = 0;

  @override
  void initState() {
    super.initState();
    _log.info('screen', 'PlayScreen.initState', data: {
      'region': widget.region.name,
      'challenge': widget.challengeFriendName,
      'totalRounds': widget.totalRounds,
    });
    _game = FlitGame(
      onGameReady: _onGameReady,
      onAltitudeChanged: _onAltitudeChanged,
      isChallenge: widget.challengeFriendName != null,
      planeColorScheme: widget.planeColorScheme,
      equippedPlaneId: widget.equippedPlaneId,
    );
  }

  @override
  void dispose() {
    _log.info('screen', 'PlayScreen.dispose');
    _timer?.cancel();
    AudioManager.instance.stopEngine();
    super.dispose();
  }

  void _onGameReady() {
    _log.info('screen', 'Game engine ready');
    if (!mounted) return;
    setState(() {
      _gameReady = true;
    });
    // Start the game session on the next frame so it is decoupled from the
    // Flame onLoad() future – any exception here won't break the engine.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startNewGame();
    });
  }

  void _onAltitudeChanged(bool isHigh) {
    _log.debug('screen', 'Altitude callback', data: {'isHigh': isHigh});
    if (mounted) {
      setState(() {
        _isHighAltitude = isHigh;
      });
    }
  }

  bool get _isMultiRound => widget.totalRounds > 1;
  bool get _isFinalRound => _currentRound >= widget.totalRounds;

  void _startNewGame() {
    _log.info('session', 'Starting round $_currentRound/${widget.totalRounds}');
    try {
      _session = GameSession.random(region: widget.region);
      _elapsed = Duration.zero;

      _log.info('session', 'Session created', data: {
        'target': _session!.targetName,
        'clue': _session!.clue.type.name,
        'round': _currentRound,
      });

      // Start the game with the session data
      _game.startGame(
        startPosition: _session!.startPosition,
        targetPosition: _session!.targetPosition,
        clue: _session!.clue.displayText,
      );

      // Play clue popup sound.
      AudioManager.instance.playSfx(SfxType.cluePop);

      // Start timer
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (mounted && _session != null && !_session!.isCompleted) {
          setState(() {
            _elapsed = _session!.elapsed;
          });

          // Record flight path periodically
          if (_elapsed.inMilliseconds % 100 < 20) {
            _session!.recordPosition(_game.worldPosition);
          }

          // Check for proximity to target
          _checkProximity();
        }
      });

      setState(() {
        _error = null;
      });
    } catch (e, st) {
      _log.error('session', 'Failed to start game', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _error = 'Failed to start game: $e';
        });
      }
    }
  }

  void _checkProximity() {
    if (_session == null || _session!.isCompleted) return;

    // Proximity detection: near target
    if (_game.isNearTarget(threshold: 80)) {
      if (_isMultiRound && !_isFinalRound) {
        // Not the final round: auto-advance when near target (any altitude)
        _advanceRound();
      } else if (!_isHighAltitude) {
        // Final round or single round: require low altitude to land
        _completeLanding();
      }
    }
  }

  /// Advance to the next round without showing a dialog.
  void _advanceRound() {
    _timer?.cancel();
    _session?.complete();
    _totalScore += _session?.score ?? 0;

    _log.info('session', 'Round $_currentRound complete, advancing', data: {
      'target': _session?.targetName,
      'roundScore': _session?.score,
      'totalScore': _totalScore,
    });

    setState(() {
      _currentRound++;
    });

    // Brief delay so the player sees they arrived, then start next round
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startNewGame();
    });
  }

  void _completeLanding() {
    _timer?.cancel();
    _session?.complete();
    _totalScore += _session?.score ?? 0;
    AudioManager.instance.playSfx(SfxType.landingSuccess);

    _log.info('session', 'Landing complete', data: {
      'target': _session?.targetName,
      'elapsed': _session?.elapsed.inMilliseconds,
      'score': _session?.score,
      'totalScore': _totalScore,
      'round': _currentRound,
    });

    // Notify completion callback
    widget.onComplete?.call(_totalScore);

    final friendName = widget.challengeFriendName;

    // Show result dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ResultDialog(
        session: _session!,
        challengeFriendName: friendName,
        totalScore: _totalScore,
        totalRounds: widget.totalRounds,
        coinReward: widget.coinReward,
        onPlayAgain: friendName == null
            ? () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _currentRound = 1;
                  _totalScore = 0;
                });
                _startNewGame();
              }
            : null,
        onExit: () {
          Navigator.of(dialogContext).pop(); // dismiss result dialog
          Navigator.of(context).pop(); // dismiss PlayScreen
        },
        onSendChallenge: friendName != null
            ? () {
                Navigator.of(dialogContext).pop();
                _showChallengeSentDialog(friendName);
              }
            : null,
      ),
    );
  }

  void _requestExit() {
    _log.info('screen', 'Exit requested by user');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flight,
                color: FlitColors.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 16),
              const Text(
                'Abort Flight?',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your current progress will be lost.',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'KEEP FLYING',
                      style: TextStyle(color: FlitColors.accent),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _log.info('screen', 'User confirmed exit');
                      _timer?.cancel();
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.textMuted,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('ABORT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChallengeSentDialog(String friendName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.send,
                color: FlitColors.success,
                size: 44,
              ),
              const SizedBox(height: 16),
              const Text(
                'Challenge Sent!',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for $friendName to play...',
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // dismiss this dialog
                  Navigator.of(context).pop(); // dismiss PlayScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Game canvas – use builders to avoid white flash during init
            GameWidget(
              game: _game,
              loadingBuilder: (_) => Container(
                color: FlitColors.backgroundDark,
              ),
              errorBuilder: (ctx, err) {
                _log.error('screen', 'GameWidget error', error: err);
                return Container(
                  color: FlitColors.backgroundDark,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: FlitColors.warning, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Game failed to load',
                        style: TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlitColors.accent,
                          foregroundColor: FlitColors.textPrimary,
                        ),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // HUD overlay
            if (_gameReady && _session != null)
              GameHud(
                isHighAltitude: _isHighAltitude,
                elapsedTime: _elapsed,
                currentClue: _session?.clue,
                onAltitudeToggle: () => _game.plane.toggleAltitude(),
                onExit: _requestExit,
              ),

            // Round indicator for multi-round play
            if (_gameReady && _isMultiRound)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FlitColors.cardBackground.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: FlitColors.accent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      'Round $_currentRound / ${widget.totalRounds}',
                      style: const TextStyle(
                        color: FlitColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

            // Error overlay
            if (_error != null)
              Container(
                color: FlitColors.backgroundDark,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: FlitColors.warning, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.accent,
                        foregroundColor: FlitColors.textPrimary,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),

            // Loading overlay
            if (!_gameReady && _error == null)
              Container(
                color: FlitColors.backgroundDark,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: FlitColors.accent,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.session,
    this.onPlayAgain,
    required this.onExit,
    this.challengeFriendName,
    this.onSendChallenge,
    this.totalScore = 0,
    this.totalRounds = 1,
    this.coinReward = 0,
  });

  final GameSession session;
  final VoidCallback? onPlayAgain;
  final VoidCallback onExit;
  final String? challengeFriendName;
  final VoidCallback? onSendChallenge;
  final int totalScore;
  final int totalRounds;
  final int coinReward;

  @override
  Widget build(BuildContext context) {
    final isChallenge = challengeFriendName != null;
    final totalSeconds = session.elapsed.inMilliseconds / 1000;
    final minutes = session.elapsed.inMinutes;
    final seconds = session.elapsed.inSeconds % 60;
    final millis = (session.elapsed.inMilliseconds % 1000) ~/ 10;
    final isMultiRound = totalRounds > 1;

    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flight_land,
              color: FlitColors.success,
              size: 44,
            ),
            const SizedBox(height: 16),
            const Text(
              'LANDED',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.targetName,
              style: const TextStyle(
                color: FlitColors.accent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isChallenge) ...[
              const SizedBox(height: 12),
              Text(
                'Round 1 vs $challengeFriendName: Your time ${totalSeconds.toStringAsFixed(2)}s',
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (!isChallenge) ...[
              const SizedBox(height: 20),
              // Time
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              isMultiRound
                  ? 'Total Score: $totalScore'
                  : 'Score: ${session.score}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (isMultiRound) ...[
              const SizedBox(height: 4),
              Text(
                '$totalRounds rounds completed',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            if (coinReward > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FlitColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlitColors.gold.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: FlitColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+$coinReward coins',
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onExit,
                  child: const Text(
                    'EXIT',
                    style: TextStyle(color: FlitColors.textMuted),
                  ),
                ),
                if (isChallenge && onSendChallenge != null)
                  ElevatedButton(
                    onPressed: onSendChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'SEND CHALLENGE',
                      style: TextStyle(
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!isChallenge && onPlayAgain != null)
                  ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
