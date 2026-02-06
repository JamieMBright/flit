import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/flit_game.dart';
import '../../game/map/region.dart';
import '../../game/session/game_session.dart';
import '../../game/ui/game_hud.dart';

/// Main play screen with game canvas and HUD overlay.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    this.region = GameRegion.world,
    this.challengeFriendName,
  });

  /// The region to play in.
  final GameRegion region;

  /// When non-null, the game is played as a challenge round against this friend.
  final String? challengeFriendName;

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

  @override
  void initState() {
    super.initState();
    _game = FlitGame(
      onGameReady: _onGameReady,
      onAltitudeChanged: _onAltitudeChanged,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onGameReady() {
    if (mounted) {
      setState(() {
        _gameReady = true;
      });
      // Auto-start a game session
      _startNewGame();
    }
  }

  void _onAltitudeChanged(bool isHigh) {
    if (mounted) {
      setState(() {
        _isHighAltitude = isHigh;
      });
    }
  }

  void _startNewGame() {
    _session = GameSession.random(region: widget.region);
    _elapsed = Duration.zero;

    // Start the game with the session data
    _game.startGame(
      startPosition: _session!.startPosition,
      targetPosition: _session!.targetPosition,
      clue: _session!.clue.displayText,
    );

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

        // Check for landing
        _checkLanding();
      }
    });

    setState(() {});
  }

  void _checkLanding() {
    if (_session == null || _session!.isCompleted) return;

    // Landing detection: low altitude + near target
    if (!_isHighAltitude && _game.isNearTarget(threshold: 80)) {
      _completeLanding();
    }
  }

  void _completeLanding() {
    _timer?.cancel();
    _session?.complete();

    final friendName = widget.challengeFriendName;

    // Show result dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ResultDialog(
        session: _session!,
        challengeFriendName: friendName,
        onPlayAgain: friendName == null
            ? () {
                Navigator.of(dialogContext).pop();
                _startNewGame();
              }
            : null,
        onExit: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(dialogContext).pop();
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
                  Navigator.of(dialogContext).pop(); // Pop this dialog
                  Navigator.of(dialogContext).pop(); // Pop PlayScreen
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Game canvas
            GameWidget(game: _game),

            // HUD overlay
            if (_gameReady && _session != null)
              GameHud(
                isHighAltitude: _isHighAltitude,
                elapsedTime: _elapsed,
                currentClue: _session?.clue,
                onAltitudeToggle: () => _game.plane.toggleAltitude(),
              ),

            // Loading overlay
            if (!_gameReady)
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
  });

  final GameSession session;
  final VoidCallback? onPlayAgain;
  final VoidCallback onExit;
  final String? challengeFriendName;
  final VoidCallback? onSendChallenge;

  @override
  Widget build(BuildContext context) {
    final isChallenge = challengeFriendName != null;
    final totalSeconds = session.elapsed.inMilliseconds / 1000;
    final minutes = session.elapsed.inMinutes;
    final seconds = session.elapsed.inSeconds % 60;
    final millis = (session.elapsed.inMilliseconds % 1000) ~/ 10;

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
              'Score: ${session.score}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
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
