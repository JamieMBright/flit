import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../../game/tutorial/coach.dart';

/// Aviation-themed tap-to-continue labels for the tutorial.
const _continueLabels = [
  'Roger!',
  'Affirmative!',
  'Copy that!',
  'Wilco!',
  'Understood!',
  '10-4!',
];

/// Tutorial phases for Mission 1's interactive control introduction.
///
/// The game starts without showing a clue. The coach walks the player through
/// each control, waiting for them to actually try it before advancing. Only
/// after all controls have been explored does the clue appear and the real
/// game begin.
enum TutorialPhase {
  /// Coach welcomes player. Tap to continue.
  welcome,

  /// Spotlight on turn buttons. Player must turn several times.
  tryTurning,

  /// Spotlight on globe. Player must set multiple waypoints.
  tryWaypoint,

  /// Spotlight on speed controls. Player must change speed several times.
  trySpeed,

  /// Spotlight on altitude toggle. Player descends.
  tryAltitude,

  /// After descending, encourage the player to ascend back up.
  tryAscend,

  /// All controls explored. Clue is about to appear.
  ready,

  /// Tutorial complete — overlay dismissed, clue is showing, game is live.
  complete,
}

/// Interactive pre-flight tutorial overlay for campaign Mission 1.
///
/// Greys out the screen except for a spotlight on the current control being
/// introduced. The coach narrates each step. The player must actually try
/// each control before advancing. The clue is withheld until the tutorial
/// completes, preventing accidental mission end.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.mission,
    required this.onComplete,
  });

  final CampaignMission mission;

  /// Called when the tutorial finishes — PlayScreen should show the clue
  /// and start normal gameplay.
  final VoidCallback onComplete;

  @override
  State<TutorialOverlay> createState() => TutorialOverlayState();
}

class TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  TutorialPhase _phase = TutorialPhase.welcome;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  static final _rng = Random();
  String _continueLabel =
      _continueLabels[Random().nextInt(_continueLabels.length)];

  /// Count-based progression trackers.
  int _turnCount = 0;
  int _waypointCount = 0;
  int _speedChangeCount = 0;

  /// Thresholds for progressing past each phase.
  static const _turnThreshold = 3;
  static const _waypointThreshold = 10;
  static const _speedThreshold = 3;

  /// Whether the tutorial is still active (clue should be hidden).
  bool get isActive => _phase != TutorialPhase.complete;

  /// Whether the spotlight overlay should be shown.
  bool get _showOverlay =>
      _phase != TutorialPhase.complete && _phase != TutorialPhase.ready;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Minimum breathing room between the player performing an action and the
  /// next tutorial tip appearing, so they can enjoy flying for a moment.
  static const _tipDelay = Duration(seconds: 5);

  /// Whether a delayed phase transition is pending — prevents double-firing
  /// if the player triggers the same action multiple times.
  bool _advancing = false;

  /// Advance to [next] after [_tipDelay], fading the current tip out first
  /// and then fading the new one in.
  void _advanceAfterDelay(TutorialPhase next) {
    if (_advancing) return;
    _advancing = true;

    // Immediately fade out the current coach card so the player can fly
    // unobstructed during the delay.
    _fadeController.reverse();

    Future.delayed(_tipDelay, () {
      if (!mounted) return;
      _advancing = false;
      setState(() => _phase = next);
      _fadeController.forward();
    });
  }

  // ─── Callbacks from PlayScreen when the player performs actions ──────

  /// Called when the player presses a turn button.
  void onTurnPressed() {
    if (_phase == TutorialPhase.tryTurning) {
      _turnCount++;
      if (_turnCount >= _turnThreshold) {
        _advanceAfterDelay(TutorialPhase.tryWaypoint);
      } else {
        setState(() {}); // Refresh message with updated count
      }
    }
  }

  /// Called when the player taps the globe (sets a waypoint).
  void onWaypointSet() {
    if (_phase == TutorialPhase.tryWaypoint) {
      _waypointCount++;
      if (_waypointCount >= _waypointThreshold) {
        _advanceAfterDelay(TutorialPhase.trySpeed);
      } else {
        setState(() {}); // Refresh message with encouragement
      }
    }
  }

  /// Called when the player changes speed.
  void onSpeedChanged() {
    if (_phase == TutorialPhase.trySpeed) {
      _speedChangeCount++;
      if (_speedChangeCount >= _speedThreshold) {
        _advanceAfterDelay(TutorialPhase.tryAltitude);
      } else {
        setState(() {}); // Refresh message with updated count
      }
    }
  }

  /// Called when the player toggles altitude (descend).
  void onAltitudeToggled() {
    if (_phase == TutorialPhase.tryAltitude) {
      // Player descended — now encourage them to ascend.
      _advanceAfterDelay(TutorialPhase.tryAscend);
    } else if (_phase == TutorialPhase.tryAscend) {
      // Player ascended back up — tutorial complete.
      _finishTutorial();
    }
  }

  void _onTap() {
    switch (_phase) {
      case TutorialPhase.welcome:
        setState(() {
          _phase = TutorialPhase.tryTurning;
          _continueLabel =
              _continueLabels[_rng.nextInt(_continueLabels.length)];
        });
      case TutorialPhase.ready:
        _finishTutorial();
      // For action phases, tapping does nothing — player must use the control.
      case TutorialPhase.tryTurning:
      case TutorialPhase.tryWaypoint:
      case TutorialPhase.trySpeed:
      case TutorialPhase.tryAltitude:
      case TutorialPhase.tryAscend:
      case TutorialPhase.complete:
        break;
    }
  }

  void _finishTutorial() {
    setState(() => _phase = TutorialPhase.ready);
    // Brief pause to show "Ready!" message, then fade out and complete.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() => _phase = TutorialPhase.complete);
          widget.onComplete();
        }
      });
    });
  }

  // ─── Message text for each phase ────────────────────────────────────

  String get _message {
    final coach = widget.mission.coach;
    switch (_phase) {
      case TutorialPhase.welcome:
        return 'Welcome aboard, cadet! I\'m ${coach.name}. In 1929 I became '
            'the first Indian to earn a pilot\'s licence — and now I\'ll '
            'teach you to fly. Let me show you the controls.';
      case TutorialPhase.tryTurning:
        final remaining = _turnThreshold - _turnCount;
        if (_turnCount == 0) {
          return 'When I flew the first airmail from Karachi to Bombay, '
              'I had to bank and turn through mountain passes. See the '
              'arrows at the bottom corners? Hold one to turn. Try it!';
        }
        if (remaining > 1) {
          return 'Good banking! That\'s how I navigated the Western Ghats. '
              '$remaining more turns — get comfortable!';
        }
        return 'One more turn and you\'ll fly like a natural!';
      case TutorialPhase.tryWaypoint:
        final remaining = _waypointThreshold - _waypointCount;
        if (_waypointCount == 0) {
          return 'On my first flight, I plotted my route from Karachi to '
              'Bombay — every waypoint mattered. Tap anywhere on the '
              'globe to set a waypoint. Your plane will steer towards it. '
              'Set $_waypointThreshold to get the feel!';
        }
        if (_waypointCount < 3) {
          return 'Excellent! In my little Puss Moth, I had to plan every '
              'stop carefully. Keep setting waypoints — $remaining to go!';
        }
        if (_waypointCount < 6) {
          return 'You\'re getting the hang of it! I once plotted a route '
              'across half of India this way. $remaining more — try '
              'different directions!';
        }
        if (_waypointCount < 9) {
          return 'Almost there, cadet! Just $remaining more. When I '
              'founded Tata Airlines, every pilot had to master this. '
              'Try setting one far away!';
        }
        return 'One more waypoint! You\'d have made a fine Tata Airlines '
            'pilot.';
      case TutorialPhase.trySpeed:
        final remaining = _speedThreshold - _speedChangeCount;
        if (_speedChangeCount == 0) {
          return 'My Puss Moth could only do 128 km/h — you\'ve got more '
              'options! Tap SLOW, MED, or FAST to change your speed. '
              'Try each one!';
        }
        if (remaining > 1) {
          return 'Feel the difference? I learned to read the wind and '
              'adjust my speed over the Arabian Sea. '
              '$remaining more changes to go!';
        }
        return 'One more speed change — then I\'ll show you altitude!';
      case TutorialPhase.tryAltitude:
        return 'When I flew over Bombay, I\'d descend low to see the '
            'coastline. Tap the altitude button to drop down and see '
            'the map up close!';
      case TutorialPhase.tryAscend:
        return 'Beautiful, isn\'t it? I remember the first time I saw '
            'India from above. Now climb back up — tap altitude again. '
            'You\'ll want to be high when searching for countries. '
            'The higher you fly, the more of the world you can see!';
      case TutorialPhase.ready:
        return 'You fly with the confidence of an airline founder! '
            'Here comes your first clue...';
      case TutorialPhase.complete:
        return '';
    }
  }

  TutorialTarget? get _target {
    switch (_phase) {
      case TutorialPhase.welcome:
      case TutorialPhase.ready:
      case TutorialPhase.complete:
        return null;
      case TutorialPhase.tryTurning:
        return TutorialTarget.turnButtons;
      case TutorialPhase.tryWaypoint:
        return TutorialTarget.globe;
      case TutorialPhase.trySpeed:
        return TutorialTarget.speedControls;
      case TutorialPhase.tryAltitude:
      case TutorialPhase.tryAscend:
        return TutorialTarget.altitudeToggle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == TutorialPhase.complete) return const SizedBox.shrink();

    final coach = widget.mission.coach;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Dark overlay with spotlight cutout (only during active phases).
          // During action phases the overlay ignores pointer events so the
          // underlying controls (turn buttons, globe, etc.) receive touches.
          // During tap phases (welcome, waypointSet, ready) the overlay
          // captures taps to advance the tutorial.
          if (_showOverlay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _isActionPhase,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isTapPhase ? _onTap : null,
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      target: _target,
                      screenSize: screenSize,
                      safePadding: safePadding,
                    ),
                  ),
                ),
              ),
            ),

          // Coach avatar below compass + speech bubble centred on screen.
          Positioned(
            top: safePadding.top + 110,
            right: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coach avatar
                _CoachAvatar(coach: coach),
                const SizedBox(height: 4),
                // Speech bubble — centred
                Align(
                  alignment: Alignment.center,
                  child: _CoachCard(
                    coachName: coach.name,
                    message: _message,
                    showPulse: _isActionPhase,
                    showContinueButton: _isTapPhase,
                    continueLabel: _continueLabel,
                    onTap: _isTapPhase ? _onTap : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isActionPhase =>
      _phase == TutorialPhase.tryTurning ||
      _phase == TutorialPhase.tryWaypoint ||
      _phase == TutorialPhase.trySpeed ||
      _phase == TutorialPhase.tryAltitude ||
      _phase == TutorialPhase.tryAscend;

  /// Whether the current phase advances on a simple tap (not a control action).
  bool get _isTapPhase =>
      _phase == TutorialPhase.welcome || _phase == TutorialPhase.ready;
}

/// HUD element regions for spotlight positioning.
enum TutorialTarget {
  turnButtons,
  globe,
  speedControls,
  altitudeToggle,
}

/// Small circular coach avatar for the tutorial overlay.
///
/// Shows the coach's portrait image when available, falling back to styled
/// initials with a flag badge.
class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: FlitColors.cardBackground,
      border: Border.all(
        color: FlitColors.accent.withValues(alpha: 0.6),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (coach.imageAsset != null) {
      return Container(
        width: size,
        height: size,
        decoration: decoration,
        child: ClipOval(
          child: Image.asset(
            coach.imageAsset!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsFallback(size),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: _initialsFallback(size),
    );
  }

  Widget _initialsFallback(double size) {
    final parts = coach.name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : parts.first.substring(0, 2);
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: FlitColors.accent,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Speech bubble coach message card used by the tutorial overlay.
class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.coachName,
    required this.message,
    required this.continueLabel,
    this.showPulse = false,
    this.showContinueButton = false,
    this.onTap,
  });

  final String coachName;
  final String message;
  final String continueLabel;
  final bool showPulse;
  final bool showContinueButton;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth * 0.7).clamp(200.0, 320.0);

    return SizedBox(
      width: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tail pointing up toward the avatar
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CustomPaint(
              size: const Size(14, 8),
              painter: _BubbleTailPainter(),
            ),
          ),
          // Bubble body
          Container(
            width: maxWidth,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4C9B8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coach name
                Text(
                  coachName,
                  style: const TextStyle(
                    color: Color(0xFFC45E2C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Message text
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (showPulse) ...[
                  const SizedBox(height: 6),
                  Center(child: _PulsingHint()),
                ],
                if (showContinueButton && onTap != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FlitColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: FlitColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          continueLabel,
                          style: const TextStyle(
                            color: FlitColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the small triangular tail connecting the speech bubble to the avatar.
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F0E8)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFFD4C9B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pulsing "Try it!" indicator for action phases.
class _PulsingHint extends StatefulWidget {
  @override
  State<_PulsingHint> createState() => _PulsingHintState();
}

class _PulsingHintState extends State<_PulsingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app,
            size: 14,
            color: FlitColors.accent.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'Try it!',
            style: TextStyle(
              color: FlitColors.accent.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a semi-transparent dark overlay with a rounded-rect spotlight
/// cut out around the target HUD element.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.screenSize,
    required this.safePadding,
  });

  final TutorialTarget? target;
  final Size screenSize;
  final EdgeInsets safePadding;

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withValues(alpha: 0.68);

    if (target == null) {
      canvas.drawRect(Offset.zero & size, darkPaint);
      return;
    }

    final spotlight = _spotlightRect(target!, size);

    // Draw dark overlay with a hole punched out via saveLayer + clear.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, darkPaint);

    final cutoutPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(spotlight, const Radius.circular(14));
    canvas.drawRRect(rrect, cutoutPaint);
    canvas.restore();

    // Subtle glow border around the cutout.
    final glowPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, glowPaint);
  }

  Rect _spotlightRect(TutorialTarget target, Size size) {
    final top = safePadding.top + 16;
    final right = size.width - safePadding.right - 16;
    final bottom = size.height - safePadding.bottom - 16;
    final left = safePadding.left + 16;
    const pad = 10.0;

    switch (target) {
      case TutorialTarget.turnButtons:
        // Both turn button areas at bottom corners.
        // Show a wide band across the lower portion covering both buttons.
        final btnBottom = size.height - safePadding.bottom - 80;
        return Rect.fromLTRB(
          0,
          btnBottom - 64 - pad,
          size.width,
          btnBottom + 8 + pad,
        );

      case TutorialTarget.globe:
        // Central globe area (exclude HUD edges).
        return Rect.fromLTRB(
          left + 20,
          top + 90,
          right - 20,
          bottom - 90,
        );

      case TutorialTarget.speedControls:
        // Bottom row center: speed pills — centred between hint and altitude.
        // The HUD Row uses spaceEvenly with 3 items, so the speed control
        // sits roughly in the center third of the screen.
        return Rect.fromLTRB(
          size.width * 0.30 - pad,
          bottom - 48 - pad,
          size.width * 0.70 + pad,
          bottom + pad,
        );

      case TutorialTarget.altitudeToggle:
        // Bottom row right: altitude indicator.
        return Rect.fromLTRB(
          size.width * 0.62 - pad,
          bottom - 48 - pad,
          right + pad,
          bottom + pad,
        );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      target != oldDelegate.target;
}
