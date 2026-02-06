import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/flit_game.dart';
import '../../game/session/game_session.dart';
import '../../game/ui/game_hud.dart';

/// Main play screen with game canvas and HUD overlay.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

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
    _session = GameSession.random();
    _elapsed = Duration.zero;

    // Start timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted && _session != null && !_session!.isCompleted) {
        setState(() {
          _elapsed = _session!.elapsed;
        });

        // Record flight path periodically
        if (_elapsed.inMilliseconds % 100 < 20) {
          _session!.recordPosition(_game.plane.position);
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
    if (!_isHighAltitude) {
      final targetPos = _session!.targetPosition;
      final planePos = _game.plane.position;

      // Convert positions to comparable units
      // This is simplified - in real game would use proper map projection
      final distance = (planePos - targetPos).length;

      if (distance < 50) {
        _completeLanding();
      }
    }
  }

  void _completeLanding() {
    _timer?.cancel();
    _session?.complete();

    // Show result dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResultDialog(
        session: _session!,
        onPlayAgain: () {
          Navigator.of(context).pop();
          _startNewGame();
        },
        onExit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
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
    required this.onPlayAgain,
    required this.onExit,
  });

  final GameSession session;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final minutes = session.elapsed.inMinutes;
    final seconds = session.elapsed.inSeconds % 60;
    final millis = (session.elapsed.inMilliseconds % 1000) ~/ 10;

    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flight_land,
              color: FlitColors.success,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'LANDED!',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.targetCountry.name,
              style: const TextStyle(
                color: FlitColors.accent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // Time
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${session.score}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 16,
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
                ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('PLAY AGAIN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
