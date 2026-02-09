import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/services/audio_manager.dart';
import '../../core/services/error_service.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../core/utils/web_error_bridge.dart';
import '../../data/models/avatar_config.dart';
import '../../game/clues/clue_types.dart';
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
    this.planeWingSpan,
    this.equippedPlaneId = 'plane_default',
    this.companionType = AvatarCompanion.none,
    this.fuelBoostMultiplier = 1.0,
    this.clueBoost = 0,
    this.clueChance = 0,
    this.preferredClueType,
    this.enabledClueTypes,
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

  /// Wing span for the equipped plane cosmetic.
  final double? planeWingSpan;

  /// Equipped plane ID for engine sound selection.
  final String equippedPlaneId;

  /// Companion creature type from avatar config.
  final AvatarCompanion companionType;

  /// Fuel boost multiplier from pilot license (1.0 = no boost).
  final double fuelBoostMultiplier;

  /// Bonus % chance of receiving the preferred clue type (from pilot license).
  final int clueBoost;

  /// Bonus % chance of receiving extra clues (from pilot license).
  final int clueChance;

  /// Preferred clue type name (from pilot license, e.g. 'flag', 'capital').
  final String? preferredClueType;

  /// Allowed clue types (from daily challenge theme). When non-null, only
  /// these types will be generated, overriding the preferred type.
  final Set<String>? enabledClueTypes;

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

  /// Current hint tier (0 = no hints, 1 = clue cycled, 2 = country revealed, 3 = wayline shown).
  int _hintTier = 0;

  /// Timer for auto-hint after 2 minutes of no progress.
  Timer? _autoHintTimer;

  /// Current clue being shown (may differ from session.clue after tier 1 hint).
  Clue? _currentClue;

  /// Revealed country name (shown after tier 2 hint).
  String? _revealedCountry;


  @override
  void initState() {
    super.initState();
    try {
      _log.info('screen', 'PlayScreen.initState', data: {
        'region': widget.region.name,
        'challenge': widget.challengeFriendName,
        'totalRounds': widget.totalRounds,
      });
      _game = FlitGame(
        onGameReady: _onGameReady,
        onAltitudeChanged: _onAltitudeChanged,
        onError: _onGameError,
        isChallenge: widget.challengeFriendName != null,
        fuelBoostMultiplier: widget.fuelBoostMultiplier,
        planeColorScheme: widget.planeColorScheme,
        planeWingSpan: widget.planeWingSpan,
        equippedPlaneId: widget.equippedPlaneId,
        companionType: widget.companionType,
      );
    } catch (e, st) {
      _log.error('screen', 'PlayScreen.initState FAILED',
          error: e, stackTrace: st);
      ErrorService.instance.reportCritical(e, st, context: {
        'screen': 'PlayScreen',
        'action': 'initState',
        'region': widget.region.name,
      });
      WebErrorBridge.show('PlayScreen.initState crash:\n$e\n\n$st');
      // Set error synchronously — first build() will see it and skip _game.
      _error = 'initState crashed.\n\nError: $e\n\nStack:\n$st';
    }
  }

  @override
  void dispose() {
    _log.info('screen', 'PlayScreen.dispose');
    _timer?.cancel();
    _autoHintTimer?.cancel();
    AudioManager.instance.stopEngine();
    // Detach the Flame game to stop its loop and release resources.
    // Without this, the game loop can outlive the widget and crash when
    // the user navigates to a different game mode.
    try {
      _game.pauseEngine();
      _game.onRemove();
    } catch (e, st) {
      _log.error('screen', 'PlayScreen.dispose game cleanup failed',
          error: e, stackTrace: st);
    }
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

  /// Called by FlitGame when the game loop crashes.
  void _onGameError(Object error, StackTrace? stack) {
    final msg = 'Game loop crashed.\n\nError: $error\n\nStack:\n$stack';
    WebErrorBridge.show(msg);
    if (mounted && _error == null) {
      setState(() {
        _error = msg;
      });
    }
  }

  void _onAltitudeChanged(bool isHigh) {
    _log.debug('screen', 'Altitude callback', data: {'isHigh': isHigh});
    if (mounted) {
      setState(() {
        _isHighAltitude = isHigh;
      });
    }
  }

  /// Use a hint — tiered system with 4 levels.
  void _useHint() {
    if (_session == null || _hintTier >= 4) return;

    setState(() {
      _hintTier++;

      if (_hintTier == 1) {
        // Tier 1: Cycle to a different clue type.
        // Try up to 5 times to get a different type than the current one.
        final previousType = _currentClue?.type;
        Clue? newClue;
        for (var i = 0; i < 5; i++) {
          final candidate = Clue.random(
            _session!.targetCountry.code,
            preferredClueType: widget.preferredClueType,
            clueBoost: widget.clueBoost,
            allowedTypes: widget.enabledClueTypes,
          );
          if (candidate.type != previousType || i == 4) {
            newClue = candidate;
            break;
          }
        }
        if (newClue != null && newClue.type != previousType) {
          _currentClue = newClue;
          _log.info('hint', 'Tier 1: Clue cycled', data: {
            'target': _session!.targetName,
            'newClueType': _currentClue!.type.name,
          });
        } else {
          // Only one clue type available — skip directly to tier 2 (reveal).
          _hintTier = 2;
          _revealedCountry = _session!.targetName;
          _log.info('hint', 'Tier 1 skipped to Tier 2: only one clue type', data: {
            'target': _session!.targetName,
          });
        }
      } else if (_hintTier == 2) {
        // Tier 2: Reveal the country name
        _revealedCountry = _session!.targetName;
        _log.info('hint', 'Tier 2: Country revealed', data: {
          'country': _revealedCountry,
        });
      } else if (_hintTier == 3) {
        // Tier 3: Show wayline to destination
        _game.showHintWayline(_session!.targetPosition);
        _log.info('hint', 'Tier 3: Wayline shown', data: {
          'target': _session!.targetName,
        });
      } else if (_hintTier == 4) {
        // Tier 4: Set navigation waypoint to target country (nuclear option)
        _game.setWaymarker(_session!.targetPosition);
        _log.info('hint', 'Tier 4: Nav waypoint set to target', data: {
          'target': _session!.targetName,
        });
      }
    });
  }

  /// Start auto-hint timer — gives a free tier 1 hint after 2 minutes of no progress.
  void _startAutoHintTimer() {
    _autoHintTimer?.cancel();
    _autoHintTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && _session != null && !_session!.isCompleted && _hintTier == 0) {
        _log.info('hint', 'Auto-hint triggered after 2 minutes');
        _useHint(); // Trigger tier 1 (clue change)
      }
    });
  }

  bool get _isMultiRound => widget.totalRounds > 1;
  bool get _isFinalRound => _currentRound >= widget.totalRounds;

  void _startNewGame() {
    _log.info('session', 'Starting round $_currentRound/${widget.totalRounds}');
    try {
      _session = GameSession.random(
        region: widget.region,
        preferredClueType: widget.preferredClueType,
        clueBoost: widget.clueBoost,
        allowedClueTypes: widget.enabledClueTypes,
      );
      _elapsed = Duration.zero;

      // Reset hint state for new round
      _hintTier = 0;
      _revealedCountry = null;
      _currentClue = _session!.clue;

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

      // Start auto-hint timer (gives free hint after 2 minutes of no progress).
      _startAutoHintTimer();

      setState(() {
        _error = null;
      });
    } catch (e, st) {
      _log.error('session', 'Failed to start game', error: e, stackTrace: st);
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {
          'screen': 'PlayScreen',
          'action': '_startNewGame',
          'region': widget.region.name,
          'round': '$_currentRound',
        },
      );
      WebErrorBridge.show('_startNewGame crash:\n$e\n\n$st');
      if (mounted) {
        setState(() {
          _error = 'Failed to start game session.\n\n'
              'Error: $e\n\n'
              'Stack trace:\n${st.toString().split('\n').take(8).join('\n')}';
        });
      }
    }
  }

  void _checkProximity() {
    if (_session == null || _session!.isCompleted) return;

    // Two ways to complete: proximity to target point OR entering the
    // target country's borders. The border check allows high-altitude
    // fly-over to register — the player shouldn't need to descend.
    final nearTarget = _game.isNearTarget(threshold: 25);
    final inTargetCountry = _game.currentCountryName != null &&
        _game.currentCountryName == _session!.targetName;

    if (nearTarget || inTargetCountry) {
      if (_isMultiRound && !_isFinalRound) {
        _advanceRound();
      } else {
        _completeLanding();
      }
    }
  }

  /// Advance to the next round seamlessly — plane keeps flying.
  ///
  /// Instead of teleporting the plane to a new start position, we only
  /// swap the target and clue. The plane continues from its current
  /// position and heading, giving a smooth "correct! next clue" feel.
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

    // Brief delay so the player registers success, then continue seamlessly
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        // Create new session for the next round
        _session = GameSession.random(
          region: widget.region,
          preferredClueType: widget.preferredClueType,
          clueBoost: widget.clueBoost,
          allowedClueTypes: widget.enabledClueTypes,
        );
        _elapsed = Duration.zero;
        _hintTier = 0;
        _revealedCountry = null;
        _currentClue = _session!.clue;

        _log.info('session', 'Seamless round advance', data: {
          'target': _session!.targetName,
          'clue': _session!.clue.type.name,
          'round': _currentRound,
        });

        // Continue flying — only change target and clue, no teleport.
        _game.continueWithNewTarget(
          targetPosition: _session!.targetPosition,
          clue: _session!.clue.displayText,
        );

        AudioManager.instance.playSfx(SfxType.cluePop);

        // Restart timer
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          if (mounted && _session != null && !_session!.isCompleted) {
            setState(() {
              _elapsed = _session!.elapsed;
            });
            if (_elapsed.inMilliseconds % 100 < 20) {
              _session!.recordPosition(_game.worldPosition);
            }
            _checkProximity();
          }
        });

        _startAutoHintTimer();
        setState(() {});
      } catch (e, st) {
        _log.error('session', 'Failed to advance round',
            error: e, stackTrace: st);
        // Fall back to full restart if seamless advance fails.
        _startNewGame();
      }
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
          try {
            _game.pauseEngine();
          } catch (_) {}
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
                      try {
                        _game.pauseEngine();
                      } catch (_) {}
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
                  try {
                    _game.pauseEngine();
                  } catch (_) {}
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
  Widget build(BuildContext context) {
    try {
      return _buildInner(context);
    } catch (e, st) {
      _log.error('screen', 'PlayScreen.build() CRASHED',
          error: e, stackTrace: st);
      ErrorService.instance.reportCritical(e, st, context: {
        'screen': 'PlayScreen',
        'action': 'build',
      });
      return _buildErrorScreen('build() crashed.\n\nError: $e\n\nStack:\n$st');
    }
  }

  /// Extracted error screen builder used by both _error state and catch blocks.
  Widget _buildErrorScreen(String message) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: Container(
        color: FlitColors.backgroundDark,
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline,
                      color: FlitColors.error, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Game Error',
                    style: TextStyle(
                      color: FlitColors.error,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInner(BuildContext context) {
    // If an error occurred, show ONLY the error screen — no game engine,
    // no loading spinner. This prevents cascade errors from the game
    // widget and ensures the error is always visible.
    if (_error != null) {
      return _buildErrorScreen(_error!);
    }

    return Scaffold(
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
              ErrorService.instance.reportCritical(
                err,
                null,
                context: {
                  'screen': 'PlayScreen',
                  'action': 'GameWidget.errorBuilder',
                  'region': widget.region.name,
                },
              );
              // Schedule state update so the error-only build path takes
              // over on the next frame, completely removing the GameWidget.
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted && _error == null) {
                  setState(() {
                    _error = 'Game engine failed to load.\n\nError: $err';
                  });
                }
              });
              // Return a dark container while waiting for rebuild.
              return Container(color: FlitColors.backgroundDark);
            },
          ),

          // HUD overlay
          if (_gameReady && _session != null)
            GameHud(
              isHighAltitude: _isHighAltitude,
              elapsedTime: _elapsed,
              currentClue: _currentClue,
              onAltitudeToggle: () {
                _game.plane.toggleAltitude();
                AudioManager.instance.playSfx(SfxType.altitudeChange);
              },
              onExit: _requestExit,
              currentSpeed: _game.flightSpeed,
              onSpeedChanged: (speed) {
                setState(() {
                  _game.setFlightSpeed(speed);
                });
              },
              onHint: _hintTier < 4 ? _useHint : null,
              hintTier: _hintTier,
              revealedCountry: _revealedCountry,
              countryName: _game.currentCountryName,
              heading: _game.heading,
              countryFlashProgress: _game.countryFlashProgress,
            ),

          // Mobile turn buttons (L/R) — positioned at bottom corners.
          // Use GestureDetector for press/release to get progressive turning.
          if (_gameReady && _session != null) ...[
            Positioned(
              left: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80,
              child: _TurnButton(
                icon: Icons.turn_left,
                onPressStart: () => _game.setButtonTurn(-1),
                onPressEnd: () => _game.releaseButtonTurn(),
              ),
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80,
              child: _TurnButton(
                icon: Icons.turn_right,
                onPressStart: () => _game.setButtonTurn(1),
                onPressEnd: () => _game.releaseButtonTurn(),
              ),
            ),
          ],

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
}

/// Translucent on-screen turn button for mobile/touch users.
///
/// Triggers on press-and-hold: [onPressStart] fires when the finger goes
/// down, [onPressEnd] fires when it lifts. The progressive turning ramp-up
/// is handled by FlitGame._updateTurnInput.
class _TurnButton extends StatefulWidget {
  const _TurnButton({
    required this.icon,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final IconData icon;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  State<_TurnButton> createState() => _TurnButtonState();
}

class _TurnButtonState extends State<_TurnButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          widget.onPressStart();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressEnd();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          widget.onPressEnd();
        },
        child: AnimatedOpacity(
          opacity: _pressed ? 0.9 : 0.45,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FlitColors.cardBackground.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(
                color: _pressed
                    ? FlitColors.accent.withOpacity(0.8)
                    : FlitColors.cardBorder.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              widget.icon,
              color: _pressed ? FlitColors.accent : FlitColors.textSecondary,
              size: 28,
            ),
          ),
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
