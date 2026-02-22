import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/audio_manager.dart';
import '../../core/services/error_service.dart';
import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../core/utils/web_error_bridge.dart';
import '../../core/widgets/settings_sheet.dart';
import '../../data/models/avatar_config.dart';
import '../../data/models/daily_result.dart';
import '../../data/providers/account_provider.dart';
import '../../data/models/challenge.dart';
import '../../data/services/challenge_service.dart';
import '../challenge/challenge_result_screen.dart';
import '../../game/clues/clue_types.dart';
import '../../game/flit_game.dart';
import '../../game/map/descent_map_view.dart';
import '../../game/map/region.dart';
import '../../game/session/game_session.dart';
import '../../game/ui/game_hud.dart';

final _log = GameLog.instance;

/// Main play screen with game canvas and HUD overlay.
///
/// Supports multi-round play: when [totalRounds] > 1, the player
/// automatically advances through rounds without landing until the
/// final round.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({
    super.key,
    this.region = GameRegion.world,
    this.challengeFriendName,
    this.challengeId,
    this.totalRounds = 1,
    this.coinReward = 0,
    this.onComplete,
    this.planeColorScheme,
    this.planeWingSpan,
    this.equippedPlaneId = 'plane_default',
    this.companionType = AvatarCompanion.none,
    this.fuelBoostMultiplier = 1.0,
    this.planeHandling = 1.0,
    this.planeSpeed = 1.0,
    this.planeFuelEfficiency = 1.0,
    this.clueBoost = 0,
    this.clueChance = 0,
    this.preferredClueType,
    this.enabledClueTypes,
    this.enableFuel = false,
    this.contrailPrimaryColor,
    this.contrailSecondaryColor,
    this.isDailyChallenge = false,
    this.onDailyComplete,
    this.dailyTheme = '',
    this.dailySeed,
  });

  /// The region to play in.
  final GameRegion region;

  /// When non-null, the game is played as a challenge round against this friend.
  final String? challengeFriendName;

  /// The Supabase challenge ID (set when playing a real H2H challenge).
  final String? challengeId;

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

  /// Plane handling multiplier from equipped plane (affects turn rate).
  final double planeHandling;

  /// Plane speed multiplier from equipped plane (affects movement speed).
  final double planeSpeed;

  /// Plane fuel efficiency from equipped plane (higher = less burn).
  final double planeFuelEfficiency;

  /// Bonus % chance of receiving the preferred clue type (from pilot license).
  final int clueBoost;

  /// Bonus % chance of receiving extra clues (from pilot license).
  final int clueChance;

  /// Preferred clue type name (from pilot license, e.g. 'flag', 'capital').
  final String? preferredClueType;

  /// Allowed clue types (from daily challenge theme). When non-null, only
  /// these types will be generated, overriding the preferred type.
  final Set<String>? enabledClueTypes;

  /// Whether fuel mechanics are active. True for training, daily, dogfight.
  /// False for free flight.
  final bool enableFuel;

  /// Primary contrail color from equipped cosmetic.
  final Color? contrailPrimaryColor;

  /// Secondary contrail color from equipped cosmetic.
  final Color? contrailSecondaryColor;

  /// Whether this is a daily challenge game (enables share text generation).
  final bool isDailyChallenge;

  /// Called with the daily result when a daily challenge completes.
  final void Function(DailyResult result)? onDailyComplete;

  /// Daily challenge theme title for the share text.
  final String dailyTheme;

  /// Daily challenge seed for deterministic country selection.
  /// When non-null, `GameSession.seeded()` is used so all players get the
  /// same countries on the same day.
  final int? dailySeed;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  late final FlitGame _game;
  GameSession? _session;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  Duration _cumulativeTime = Duration.zero;
  bool _isHighAltitude = true;
  bool _gameReady = false;
  String? _error;

  /// Safety timeout — if the game engine hasn't signalled ready after 20s,
  /// show an error instead of spinning forever.
  Timer? _gameReadyTimeout;

  /// Compute altitude transition for DescentMapView zoom in flat map mode.
  /// Maps region bounds to a zoom level where the whole region fits on screen.
  double get _flatMapZoom {
    final bounds = widget.region.bounds;
    final lngSpan = (bounds[2] - bounds[0]).abs();
    // Larger regions need higher altitudeTransition (lower zoom).
    // US CONUS (~59° lng) → 0.7, Ireland (~6° lng) → 0.2, Canada (~89°) → 0.85
    return (lngSpan / 100.0).clamp(0.15, 0.9);
  }

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

  /// Whether the launch intro overlay is visible (black screen during globe snap).
  bool _launchIntroVisible = false;

  /// Per-round results for the summary screen.
  final List<_RoundResult> _roundResults = [];

  @override
  void initState() {
    super.initState();
    try {
      _log.info(
        'screen',
        'PlayScreen.initState',
        data: {
          'region': widget.region.name,
          'challenge': widget.challengeFriendName,
          'totalRounds': widget.totalRounds,
        },
      );
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
        region: widget.region,
        planeHandling: widget.planeHandling,
        planeSpeed: widget.planeSpeed,
        planeFuelEfficiency: widget.planeFuelEfficiency,
        contrailPrimaryColor: widget.contrailPrimaryColor,
        contrailSecondaryColor: widget.contrailSecondaryColor,
      );
      // Safety timeout — if onLoad takes too long, show an error rather than
      // spinning forever. The timer is cancelled in _onGameReady or dispose.
      _gameReadyTimeout = Timer(const Duration(seconds: 20), () {
        if (mounted && !_gameReady && _error == null) {
          _log.error('screen', 'Game ready timeout (20s)');
          setState(() {
            _error =
                'Game engine failed to start.\n\nPlease go back and try '
                'again. If the problem persists, restart the app.';
          });
        }
      });
    } catch (e, st) {
      _log.error(
        'screen',
        'PlayScreen.initState FAILED',
        error: e,
        stackTrace: st,
      );
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {
          'screen': 'PlayScreen',
          'action': 'initState',
          'region': widget.region.name,
        },
      );
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
    _gameReadyTimeout?.cancel();
    AudioManager.instance.stopEngine();
    // Detach the Flame game to stop its loop and release resources.
    // Without this, the game loop can outlive the widget and crash when
    // the user navigates to a different game mode.
    try {
      _game.pauseEngine();
      _game.onRemove();
    } catch (e, st) {
      _log.error(
        'screen',
        'PlayScreen.dispose game cleanup failed',
        error: e,
        stackTrace: st,
      );
    }
    super.dispose();
  }

  void _onGameReady() {
    _log.info('screen', 'Game engine ready');
    _gameReadyTimeout?.cancel();
    _gameReadyTimeout = null;
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
  /// Each hint costs a small amount of fuel.
  void _useHint() {
    if (_session == null || _hintTier >= 4) return;

    // Deduct fuel for using a hint. If tank is empty, abort.
    if (!_game.useHintFuel()) return;

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
          _log.info(
            'hint',
            'Tier 1: Clue cycled',
            data: {
              'target': _session!.targetName,
              'newClueType': _currentClue!.type.name,
            },
          );
        } else {
          // Only one clue type available — skip directly to tier 2 (reveal).
          _hintTier = 2;
          _revealedCountry = _session!.targetName;
          _log.info(
            'hint',
            'Tier 1 skipped to Tier 2: only one clue type',
            data: {'target': _session!.targetName},
          );
        }
      } else if (_hintTier == 2) {
        // Tier 2: Reveal the country name
        _revealedCountry = _session!.targetName;
        _log.info(
          'hint',
          'Tier 2: Country revealed',
          data: {'country': _revealedCountry},
        );
      } else if (_hintTier == 3) {
        // Tier 3: Show wayline to destination
        _game.showHintWayline(_session!.targetPosition);
        _log.info(
          'hint',
          'Tier 3: Wayline shown',
          data: {'target': _session!.targetName},
        );
      } else if (_hintTier == 4) {
        // Tier 4: Set navigation waypoint to target country (nuclear option)
        _game.setWaymarker(_session!.targetPosition);
        _log.info(
          'hint',
          'Tier 4: Nav waypoint set to target',
          data: {'target': _session!.targetName},
        );
      }
    });
  }

  /// Start auto-hint timer — gives a free tier 1 hint after 2 minutes of no progress.
  void _startAutoHintTimer() {
    _autoHintTimer?.cancel();
    _autoHintTimer = Timer(const Duration(minutes: 2), () {
      if (mounted &&
          _session != null &&
          !_session!.isCompleted &&
          _hintTier == 0) {
        _log.info('hint', 'Auto-hint triggered after 2 minutes');
        _useHint(); // Trigger tier 1 (clue change)
      }
    });
  }

  bool get _isMultiRound => widget.totalRounds > 1;
  bool get _isFinalRound => _currentRound >= widget.totalRounds;

  /// Called when fuel runs out — ends the current session.
  void _onFuelEmpty() {
    if (_session == null || _session!.isCompleted) return;
    _log.info('fuel', 'Fuel depleted — ending session');
    _completeLanding(fuelDepleted: true);
  }

  /// Create a GameSession for the current round, using the daily seed when
  /// available so all players get the same countries.
  GameSession _createSession() {
    if (widget.dailySeed != null) {
      // Derive a per-round seed from the daily seed so each round is different
      // but deterministic across all players.
      final roundSeed = widget.dailySeed! + (_currentRound - 1) * 7919;
      return GameSession.seeded(
        roundSeed,
        allowedClueTypes: widget.enabledClueTypes,
        preferredClueType: widget.preferredClueType,
        clueBoost: widget.clueBoost,
      );
    }
    return GameSession.random(
      region: widget.region,
      preferredClueType: widget.preferredClueType,
      clueBoost: widget.clueBoost,
      allowedClueTypes: widget.enabledClueTypes,
    );
  }

  void _startNewGame() {
    _log.info('session', 'Starting round $_currentRound/${widget.totalRounds}');
    try {
      _session = _createSession();
      _elapsed = Duration.zero;
      _cumulativeTime = Duration.zero;
      _roundResults.clear();

      // Reset hint state for new round
      _hintTier = 0;
      _revealedCountry = null;
      _currentClue = _session!.clue;

      _log.info(
        'session',
        'Session created',
        data: {
          'target': _session!.targetName,
          'clue': _session!.clue.type.name,
          'round': _currentRound,
        },
      );

      // Show launch intro overlay (black screen while globe positions).
      _launchIntroVisible = true;
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _launchIntroVisible = false;
          });
        }
      });

      // Start the game with the session data
      _game.startGame(
        startPosition: _session!.startPosition,
        targetPosition: _session!.targetPosition,
        clue: _session!.clue.displayText,
      );

      // Configure fuel system.
      _game.fuelEnabled = widget.enableFuel;
      _game.onFuelEmpty = _onFuelEmpty;

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
          _error =
              'Failed to start game session.\n\n'
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
    final inTargetCountry =
        _game.currentCountryName != null &&
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
    final fuelFrac = _game.maxFuel > 0 ? _game.fuel / _game.maxFuel : 1.0;
    _session?.complete(hintsUsed: _hintTier, fuelFraction: fuelFrac);
    _totalScore += _session?.score ?? 0;
    _cumulativeTime += _elapsed;

    // Record per-round result for summary (capture hint tier before reset).
    if (_session != null) {
      _roundResults.add(
        _RoundResult(
          countryName: _session!.targetName,
          clueType: _session!.clue.type,
          elapsed: _elapsed,
          score: _session!.score,
          hintsUsed: _hintTier,
          completed: true,
        ),
      );
    }

    // Submit round result to Supabase for H2H challenges.
    if (widget.challengeId != null) {
      ChallengeService.instance
          .submitRoundResult(
            challengeId: widget.challengeId!,
            roundIndex: _currentRound - 1,
            timeMs: _elapsed.inMilliseconds,
          )
          .catchError((Object e) {
            _log.warning('challenge', 'Failed to submit round result: $e');
          });
    }

    _log.info(
      'session',
      'Round $_currentRound complete, advancing',
      data: {
        'target': _session?.targetName,
        'roundScore': _session?.score,
        'totalScore': _totalScore,
      },
    );

    setState(() {
      _currentRound++;
    });

    // Brief delay so the player registers success, then continue seamlessly
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        // Create new session for the next round
        _session = _createSession();
        _elapsed = Duration.zero;
        _hintTier = 0;
        _revealedCountry = null;
        _currentClue = _session!.clue;

        _log.info(
          'session',
          'Seamless round advance',
          data: {
            'target': _session!.targetName,
            'clue': _session!.clue.type.name,
            'round': _currentRound,
          },
        );

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
        _log.error(
          'session',
          'Failed to advance round',
          error: e,
          stackTrace: st,
        );
        // Fall back to full restart if seamless advance fails.
        _startNewGame();
      }
    });
  }

  void _completeLanding({bool fuelDepleted = false}) {
    _timer?.cancel();
    final fuelFrac = fuelDepleted
        ? 0.0
        : (_game.maxFuel > 0 ? _game.fuel / _game.maxFuel : 1.0);
    _session?.complete(hintsUsed: _hintTier, fuelFraction: fuelFrac);
    _totalScore += _session?.score ?? 0;
    _cumulativeTime += _elapsed;
    AudioManager.instance.playSfx(SfxType.landingSuccess);

    // Record final round result for summary.
    if (_session != null) {
      _roundResults.add(
        _RoundResult(
          countryName: _session!.targetName,
          clueType: _session!.clue.type,
          elapsed: _elapsed,
          score: _session!.score,
          hintsUsed: _hintTier,
          completed: !fuelDepleted,
        ),
      );
    }

    // Submit final round result and try to complete the challenge.
    // If the challenge is completed (both players done), navigate to the
    // full ChallengeResultScreen instead of the generic result dialog.
    if (widget.challengeId != null) {
      ChallengeService.instance
          .submitRoundResult(
            challengeId: widget.challengeId!,
            roundIndex: _currentRound - 1,
            timeMs: _elapsed.inMilliseconds,
          )
          .then(
            (_) => ChallengeService.instance.tryCompleteChallenge(
              widget.challengeId!,
            ),
          )
          .then((completedChallenge) {
            if (completedChallenge != null && mounted) {
              // Challenge is fully complete — fetch the final state and show
              // the ChallengeResultScreen.
              ChallengeService.instance
                  .fetchChallenge(widget.challengeId!)
                  .then((finalChallenge) {
                    if (finalChallenge != null && mounted) {
                      _navigateToChallengeResult(finalChallenge);
                    }
                  })
                  .catchError((Object e) {
                    _log.warning(
                      'challenge',
                      'Failed to fetch completed challenge: $e',
                    );
                  });
            }
          })
          .catchError((Object e) {
            _log.warning(
              'challenge',
              'Challenge round submit / complete chain failed: $e',
            );
          });
    }

    _log.info(
      'session',
      'Landing complete',
      data: {
        'target': _session?.targetName,
        'elapsed': _session?.elapsed.inMilliseconds,
        'score': _session?.score,
        'totalScore': _totalScore,
        'round': _currentRound,
      },
    );

    // Record stats via Riverpod account provider.
    // Note: recordGameCompletion includes an explicit flush() call, but we
    // must fire the daily callbacks BEFORE that flush so their state changes
    // (streak, daily result) are included in the same flush cycle.

    // Notify daily callbacks first so their state is dirty before the flush.
    widget.onComplete?.call(_totalScore);

    // Build and report daily result if this is a daily challenge.
    if (widget.isDailyChallenge) {
      final now = DateTime.now().toUtc();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final dailyResult = DailyResult(
        date: dateStr,
        rounds: _roundResults
            .map(
              (r) => DailyRoundResult(
                hintsUsed: r.hintsUsed,
                completed: r.completed,
                timeMs: r.elapsed.inMilliseconds,
                score: r.score,
              ),
            )
            .toList(),
        totalScore: _totalScore,
        totalTimeMs: _cumulativeTime.inMilliseconds,
        totalRounds: widget.totalRounds,
        theme: widget.dailyTheme,
      );
      widget.onDailyComplete?.call(dailyResult);
    }

    // Record game completion last — this calls flush() which persists all
    // pending dirty state including the daily callbacks above.
    ref
        .read(accountProvider.notifier)
        .recordGameCompletion(
          elapsed: _cumulativeTime,
          score: _totalScore,
          roundsCompleted: _currentRound,
          coinReward: widget.coinReward,
          region: widget.isDailyChallenge ? 'daily' : widget.region.name,
        );

    final friendName = widget.challengeFriendName;

    // Capture daily result for the dialog (built above in the isDailyChallenge block).
    final dailyResultForDialog = widget.isDailyChallenge
        ? DailyResult(
            date: () {
              final now = DateTime.now().toUtc();
              return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
                  '${now.day.toString().padLeft(2, '0')}';
            }(),
            rounds: _roundResults
                .map(
                  (r) => DailyRoundResult(
                    hintsUsed: r.hintsUsed,
                    completed: r.completed,
                    timeMs: r.elapsed.inMilliseconds,
                    score: r.score,
                  ),
                )
                .toList(),
            totalScore: _totalScore,
            totalTimeMs: _cumulativeTime.inMilliseconds,
            totalRounds: widget.totalRounds,
            theme: widget.dailyTheme,
          )
        : null;

    // Show result dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ResultDialog(
        session: _session!,
        challengeFriendName: friendName,
        totalScore: _totalScore,
        totalRounds: widget.totalRounds,
        cumulativeTime: _cumulativeTime,
        coinReward: widget.coinReward,
        roundResults: _roundResults,
        fuelDepleted: fuelDepleted,
        dailyResult: dailyResultForDialog,
        onShare: dailyResultForDialog != null
            ? () {
                Clipboard.setData(
                  ClipboardData(text: dailyResultForDialog.toShareText()),
                );
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Result copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            : null,
        onPlayAgain: friendName == null && !widget.isDailyChallenge
            ? () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _currentRound = 1;
                  _totalScore = 0;
                  _cumulativeTime = Duration.zero;
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
    final isChallenge = widget.challengeFriendName != null;
    final isDailyChallenge = widget.isDailyChallenge;

    // Build the warning message — aborting records the game with all
    // unseen rounds counted as failures, preventing daily challenge
    // exploitation (abort-to-learn-clues).
    String warningText;
    if (isChallenge) {
      warningText =
          'This will end your attempt and send your current '
          'score to ${widget.challengeFriendName}. You only '
          'get one shot at each challenge.';
    } else if (isDailyChallenge) {
      warningText =
          'Aborting will register this attempt with your current '
          'score. All remaining rounds will count as missed. '
          'You cannot replay today\'s daily challenge.';
    } else {
      warningText =
          'Aborting will register this game with your current '
          'score. All remaining rounds will count as missed.';
    }

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
              Icon(
                Icons.warning_amber_rounded,
                color: isDailyChallenge || isChallenge
                    ? FlitColors.warning
                    : FlitColors.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                isChallenge ? 'Abort Challenge?' : 'Abort Flight?',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                warningText,
                style: const TextStyle(
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
                      _log.info('screen', 'User confirmed abort');
                      Navigator.of(dialogContext).pop();
                      _recordAbort();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDailyChallenge || isChallenge
                          ? FlitColors.error
                          : FlitColors.textMuted,
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

  /// Record an aborted game as a completion where all unseen rounds
  /// count as failures (score 0, completed: false). This prevents
  /// daily challenge exploitation (abort-to-learn-clues-ahead).
  void _recordAbort() {
    _timer?.cancel();
    _autoHintTimer?.cancel();
    _session?.complete(hintsUsed: 4, fuelFraction: 0.0);
    _cumulativeTime += _elapsed;

    // Record the current in-progress round as a failed round.
    if (_session != null) {
      _roundResults.add(
        _RoundResult(
          countryName: _session!.targetName,
          clueType: _session!.clue.type,
          elapsed: _elapsed,
          score: 0,
          hintsUsed: _hintTier,
          completed: false,
        ),
      );
    }

    // Fill remaining unseen rounds as failures with zero score.
    for (var i = _currentRound + 1; i <= widget.totalRounds; i++) {
      _roundResults.add(
        _RoundResult(
          countryName: 'Unseen',
          clueType: ClueType.values.first,
          elapsed: Duration.zero,
          score: 0,
          hintsUsed: 0,
          completed: false,
        ),
      );
    }

    _log.info(
      'session',
      'Game aborted — recording as completion with failed unseen rounds',
      data: {
        'totalScore': _totalScore,
        'roundsCompleted': _currentRound,
        'totalRounds': widget.totalRounds,
      },
    );

    // Record stats as a completed game (abort counts as a game played).
    ref
        .read(accountProvider.notifier)
        .recordGameCompletion(
          elapsed: _cumulativeTime,
          score: _totalScore,
          roundsCompleted: _currentRound,
          coinReward: 0, // No coin reward for aborted games.
          region: widget.isDailyChallenge ? 'daily' : widget.region.name,
        );

    // Fire daily callbacks so the daily challenge is marked as used.
    if (widget.isDailyChallenge) {
      widget.onComplete?.call(_totalScore);

      final now = DateTime.now().toUtc();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final dailyResult = DailyResult(
        date: dateStr,
        rounds: _roundResults
            .map(
              (r) => DailyRoundResult(
                hintsUsed: r.hintsUsed,
                completed: r.completed,
                timeMs: r.elapsed.inMilliseconds,
                score: r.score,
              ),
            )
            .toList(),
        totalScore: _totalScore,
        totalTimeMs: _cumulativeTime.inMilliseconds,
        totalRounds: widget.totalRounds,
        theme: widget.dailyTheme,
      );
      widget.onDailyComplete?.call(dailyResult);
    }

    // Submit challenge abort if this is a H2H challenge.
    if (widget.challengeId != null) {
      ChallengeService.instance.submitRoundResult(
        challengeId: widget.challengeId!,
        roundIndex: _currentRound - 1,
        timeMs: _elapsed.inMilliseconds,
      );
    }

    try {
      _game.pauseEngine();
    } catch (_) {}
    Navigator.of(context).pop();
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
              const Icon(Icons.send, color: FlitColors.success, size: 44),
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

  /// Navigate to the full ChallengeResultScreen after a H2H challenge
  /// is completed by both players.
  void _navigateToChallengeResult(Challenge completedChallenge) {
    try {
      _game.pauseEngine();
    } catch (_) {}

    final account = ref.read(accountProvider);
    final userId = account.currentPlayer.id;
    final isChallengerRole = completedChallenge.challengerId == userId;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeResultScreen(
          challenge: completedChallenge,
          isChallenger: isChallengerRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildInner(context);
    } catch (e, st) {
      _log.error(
        'screen',
        'PlayScreen.build() CRASHED',
        error: e,
        stackTrace: st,
      );
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {'screen': 'PlayScreen', 'action': 'build'},
      );
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
                  Icon(Icons.error_outline, color: FlitColors.error, size: 28),
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Flat map regional mode — static satellite tile map behind
            // the game canvas. Centered on the region, zoom fits the region.
            if (_gameReady && _session != null && _game.isFlatMapMode)
              Positioned.fill(
                child: DescentMapView(
                  centerLng: widget.region.center.x,
                  centerLat: widget.region.center.y,
                  heading: 0, // No rotation for flat map
                  altitudeTransition: _flatMapZoom,
                  tileUrl: GameSettings.instance.mapTileUrl,
                ),
              )
            // Globe mode — OSM tile map shown during descent transition.
            // Appears when altitude drops below 0.6 and crossfades with the
            // globe shader which fades out between 0.6→0.3.
            else if (_gameReady &&
                _session != null &&
                _game.plane.continuousAltitude < 0.6)
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - _game.plane.continuousAltitude / 0.6).clamp(
                    0.0,
                    1.0,
                  ),
                  child: DescentMapView(
                    centerLng: _game.worldPosition.x,
                    centerLat: _game.worldPosition.y,
                    heading: _game.cameraHeadingBearing,
                    altitudeTransition: _game.plane.continuousAltitude,
                    tileUrl: GameSettings.instance.mapTileUrl,
                    trackPlane: true,
                  ),
                ),
              ),

            // Game canvas – use builders to avoid white flash during init.
            // In descent mode the background is transparent so the OSM map
            // shows through, with the plane sprite rendered on top.
            GameWidget(
              game: _game,
              loadingBuilder: (_) =>
                  Container(color: FlitColors.backgroundDark),
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

            // Launch intro overlay (black screen while globe positions)
            if (_gameReady && _launchIntroVisible)
              AnimatedOpacity(
                opacity: _launchIntroVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: const IgnorePointer(
                  child: ColoredBox(
                    color: FlitColors.backgroundDark,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flight_takeoff,
                            color: FlitColors.accent,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Preparing Flight...',
                            style: TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // HUD overlay
            if (_gameReady && _session != null)
              GameHud(
                isHighAltitude: _isHighAltitude,
                elapsedTime: _elapsed,
                currentClue: _currentClue,
                onAltitudeToggle: _game.isFlatMapMode
                    ? null
                    : () {
                        _game.plane.toggleAltitude();
                        AudioManager.instance.playSfx(SfxType.altitudeChange);
                      },
                onExit: _requestExit,
                onSettings: () => showSettingsSheet(context),
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
                currentRound: _isMultiRound ? _currentRound : null,
                totalRounds: _isMultiRound ? widget.totalRounds : null,
                fuelLevel: _game.fuelEnabled ? _game.fuel : null,
                maxFuel: _game.maxFuel,
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

            // Loading overlay
            if (!_gameReady)
              Container(
                color: FlitColors.backgroundDark,
                child: const Center(
                  child: CircularProgressIndicator(color: FlitColors.accent),
                ),
              ),
          ],
        ),
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

/// Per-round result data for the summary screen.
class _RoundResult {
  const _RoundResult({
    required this.countryName,
    required this.clueType,
    required this.elapsed,
    required this.score,
    this.hintsUsed = 0,
    this.completed = true,
  });

  final String countryName;
  final ClueType clueType;
  final Duration elapsed;
  final int score;

  /// Number of hint tiers used this round (0-4).
  final int hintsUsed;

  /// Whether the player found the target (false = fuel depleted).
  final bool completed;
}

class _ResultDialog extends ConsumerWidget {
  const _ResultDialog({
    required this.session,
    this.onPlayAgain,
    required this.onExit,
    this.challengeFriendName,
    this.onSendChallenge,
    this.totalScore = 0,
    this.totalRounds = 1,
    this.cumulativeTime = Duration.zero,
    this.coinReward = 0,
    this.roundResults = const [],
    this.fuelDepleted = false,
    this.dailyResult,
    this.onShare,
  });

  final GameSession session;
  final VoidCallback? onPlayAgain;
  final VoidCallback onExit;
  final String? challengeFriendName;
  final VoidCallback? onSendChallenge;
  final int totalScore;
  final int totalRounds;
  final Duration cumulativeTime;
  final int coinReward;
  final List<_RoundResult> roundResults;
  final bool fuelDepleted;

  /// Non-null when this is a daily challenge result.
  final DailyResult? dailyResult;

  /// Called to share the daily result.
  final VoidCallback? onShare;

  static String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  static String _clueLabel(ClueType type) {
    switch (type) {
      case ClueType.flag:
      case ClueType.flagDescription:
        return 'Flag';
      case ClueType.outline:
        return 'Outline';
      case ClueType.borders:
        return 'Borders';
      case ClueType.capital:
        return 'Capital';
      case ClueType.stats:
        return 'Stats';
      case ClueType.sportsTeam:
        return 'Sports';
      case ClueType.leader:
        return 'Leader';
      case ClueType.nickname:
        return 'Nickname';
      case ClueType.landmark:
        return 'Landmark';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChallenge = challengeFriendName != null;
    final isMultiRound = totalRounds > 1;
    final displayTime = isMultiRound ? cumulativeTime : session.elapsed;
    final totalSeconds = displayTime.inMilliseconds / 1000;

    // Calculate gold breakdown for display.
    final licenseBoostPct = ref.read(accountProvider).license.coinBoost;
    final playerLevel = ref.read(currentLevelProvider);
    final levelBoostPct = ((playerLevel - 1) * 0.5).toStringAsFixed(1);
    final totalEarned = coinReward > 0
        ? (coinReward * ref.read(accountProvider.notifier).totalGoldMultiplier)
              .round()
        : 0;
    final licenseBonus = totalEarned - coinReward;

    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fuelDepleted ? Icons.local_gas_station : Icons.flight_land,
                color: fuelDepleted ? FlitColors.warning : FlitColors.success,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                fuelDepleted ? 'EMERGENCY LANDING' : 'LANDED',
                style: TextStyle(
                  color: fuelDepleted
                      ? FlitColors.warning
                      : FlitColors.textPrimary,
                  fontSize: fuelDepleted ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              if (!isMultiRound) ...[
                const SizedBox(height: 8),
                Text(
                  session.targetName,
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (isChallenge) ...[
                const SizedBox(height: 12),
                Text(
                  'vs $challengeFriendName — Total: ${totalSeconds.toStringAsFixed(2)}s',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (!isChallenge) ...[
                const SizedBox(height: 16),
                Text(
                  _formatTime(displayTime),
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
              // Per-round summary table for multi-round modes.
              if (isMultiRound && roundResults.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: FlitColors.cardBorder, height: 1),
                const SizedBox(height: 12),
                const Text(
                  'ROUND SUMMARY',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: roundResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final r = roundResults[i];
                      return Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                color: FlitColors.textMuted,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.countryName,
                              style: const TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _clueLabel(r.clueType),
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(r.elapsed),
                            style: const TextStyle(
                              color: FlitColors.accent,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: FlitColors.cardBorder, height: 1),
              ],
              if (coinReward > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Total earned
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: FlitColors.gold,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+$totalEarned coins',
                            style: const TextStyle(
                              color: FlitColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Breakdown
                      if (licenseBonus > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$coinReward base + $licenseBonus bonus '
                          '(License +$licenseBoostPct%, Level +$levelBoostPct%)',
                          style: TextStyle(
                            color: FlitColors.gold.withOpacity(0.7),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Daily challenge result circles (painted, not emoji — reliable
              // across all platforms).
              if (dailyResult != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dailyResult!.rounds.map((r) {
                    final color = !r.completed
                        ? FlitColors.error
                        : r.hintsUsed == 0
                        ? FlitColors.success
                        : r.hintsUsed <= 2
                        ? FlitColors.warning
                        : const Color(0xFFFFD700);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No hints = green, 1-2 = yellow, 3+ = orange, missed = red',
                  style: TextStyle(color: FlitColors.textMuted, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
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
                  if (onShare != null)
                    OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(
                        Icons.share,
                        color: FlitColors.accent,
                        size: 18,
                      ),
                      label: const Text(
                        'SHARE',
                        style: TextStyle(
                          color: FlitColors.accent,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FlitColors.accent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
      ),
    );
  }
}
