import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../data/services/user_preferences_service.dart';
import '../../game/tutorial/campaign_mission.dart';

const _continueLabels = [
  'Roger!',
  'Affirmative!',
  'Copy that!',
  'Wilco!',
  'Understood!',
];

enum TutorialPhase {
  welcome,
  classicSteering,
  classicThrottle,
  dPadSteering,
  joystickFine,
  joystickStrong,
  joystickThrottle,
  joystickRelease,
  doubleTapClue,
  chooseControl,
  choosePlacement,
  chooseClue,
  ready,
  complete,
}

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.mission,
    required this.onComplete,
    this.onDemoControlModeChanged,
  });

  final CampaignMission mission;
  final VoidCallback onComplete;
  final ValueChanged<ControlMode>? onDemoControlModeChanged;

  @override
  State<TutorialOverlay> createState() => TutorialOverlayState();
}

class TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  TutorialPhase _phase = TutorialPhase.welcome;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  Timer? _fallbackTimer;
  DateTime _phaseStartedAt = DateTime.now();
  bool _fallbackAvailable = false;
  bool _finishing = false;
  String _continueLabel =
      _continueLabels[Random().nextInt(_continueLabels.length)];

  int _classicSteeringCount = 0;
  final Set<int> _dPadDirections = {};

  ControlMode _selectedMode = ControlMode.classic;
  ControlPlacement _selectedPlacement = ControlPlacement.lowerCenter;
  ClueTrigger _selectedClueTrigger = ClueTrigger.button;

  static const _fallbackDelay = Duration(seconds: 12);

  bool get isActive => _phase != TutorialPhase.complete;

  bool get _showOverlay =>
      _phase != TutorialPhase.complete && _phase != TutorialPhase.ready;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isActionPhase || _fallbackAvailable) return;
      if (DateTime.now().difference(_phaseStartedAt) >= _fallbackDelay) {
        setState(() => _fallbackAvailable = true);
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _setPhase(TutorialPhase phase) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _phaseStartedAt = DateTime.now();
      _fallbackAvailable = false;
      _continueLabel =
          _continueLabels[Random().nextInt(_continueLabels.length)];
    });
    widget.onDemoControlModeChanged?.call(_demoModeFor(phase));
  }

  ControlMode _demoModeFor(TutorialPhase phase) {
    switch (phase) {
      case TutorialPhase.dPadSteering:
        return ControlMode.dPad;
      case TutorialPhase.joystickFine:
      case TutorialPhase.joystickStrong:
      case TutorialPhase.joystickThrottle:
      case TutorialPhase.joystickRelease:
      case TutorialPhase.doubleTapClue:
        return ControlMode.joystick;
      default:
        return ControlMode.classic;
    }
  }

  void _advanceAction() {
    switch (_phase) {
      case TutorialPhase.welcome:
        _setPhase(TutorialPhase.classicSteering);
      case TutorialPhase.classicSteering:
        _setPhase(TutorialPhase.classicThrottle);
      case TutorialPhase.classicThrottle:
        _setPhase(TutorialPhase.dPadSteering);
      case TutorialPhase.dPadSteering:
        _setPhase(TutorialPhase.joystickFine);
      case TutorialPhase.joystickFine:
        _setPhase(TutorialPhase.joystickStrong);
      case TutorialPhase.joystickStrong:
        _setPhase(TutorialPhase.joystickThrottle);
      case TutorialPhase.joystickThrottle:
        _setPhase(TutorialPhase.joystickRelease);
      case TutorialPhase.joystickRelease:
        _setPhase(TutorialPhase.doubleTapClue);
      case TutorialPhase.doubleTapClue:
        _setPhase(TutorialPhase.chooseControl);
      case TutorialPhase.chooseControl:
      case TutorialPhase.choosePlacement:
      case TutorialPhase.chooseClue:
      case TutorialPhase.ready:
      case TutorialPhase.complete:
        break;
    }
  }

  void onTurnPressed() {
    if (_phase != TutorialPhase.classicSteering) return;
    _classicSteeringCount++;
    if (_classicSteeringCount >= 3) {
      _advanceAction();
    } else {
      setState(() {});
    }
  }

  void onJoystickDragged(int direction) {
    if (_phase != TutorialPhase.dPadSteering) return;
    _dPadDirections.add(direction);
    if (_dPadDirections.length >= 2) {
      _advanceAction();
    } else {
      setState(() {});
    }
  }

  void onControlSteering(double value) {
    if (_phase == TutorialPhase.joystickFine && value.abs() > 0.01) {
      _advanceAction();
    } else if (_phase == TutorialPhase.joystickStrong && value.abs() >= 0.55) {
      _advanceAction();
    }
  }

  void onThrottleChanged(double value) {
    if (_phase == TutorialPhase.classicThrottle && value != 0) {
      _advanceAction();
    } else if (_phase == TutorialPhase.joystickThrottle && value.abs() > 0) {
      _advanceAction();
    }
  }

  void onControlReleased() {
    if (_phase != TutorialPhase.joystickRelease) return;
    _advanceAction();
  }

  void onDoubleTapClue() {
    if (_phase != TutorialPhase.doubleTapClue) return;
    _advanceAction();
  }

  void onWaypointSet() {}

  void _selectControl(ControlMode mode) {
    _selectedMode = mode;
    _setPhase(
      mode == ControlMode.classic
          ? TutorialPhase.chooseClue
          : TutorialPhase.choosePlacement,
    );
  }

  void _selectPlacement(ControlPlacement placement) {
    _selectedPlacement = placement;
    _setPhase(TutorialPhase.chooseClue);
  }

  Future<void> _selectClue(ClueTrigger trigger) async {
    _selectedClueTrigger = trigger;
    await _finishTutorial();
  }

  void _onTap() {
    if (_phase == TutorialPhase.welcome) {
      _setPhase(TutorialPhase.classicSteering);
    } else if (_phase == TutorialPhase.ready) {
      widget.onComplete();
    }
  }

  Future<void> _finishTutorial() async {
    if (_finishing) return;
    _finishing = true;
    GameSettings.instance.updateControlSettings(
      mode: _selectedMode,
      placement: _selectedPlacement,
      clueTrigger: _selectedClueTrigger,
    );
    await UserPreferencesService.instance
        .flush()
        .timeout(const Duration(seconds: 2), onTimeout: () {});
    if (!mounted) return;
    _setPhase(TutorialPhase.ready);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _phase = TutorialPhase.complete);
    widget.onComplete();
  }

  String get _message {
    final coach = widget.mission.coach;
    switch (_phase) {
      case TutorialPhase.welcome:
        return 'Welcome aboard, cadet! I am ${coach.name}. Let us learn every '
            'flight control before your first clue.';
      case TutorialPhase.classicSteering:
        return 'Use the left and right arrows to bank the plane. '
            '${3 - _classicSteeringCount} turns remain.';
      case TutorialPhase.classicThrottle:
        return 'Drag the throttle slider. Speed changes continuously across '
            'the full range.';
      case TutorialPhase.dPadSteering:
        return 'The D-pad is next. Tap left and right to steer with one thumb. '
            '${2 - _dPadDirections.length} directions remain.';
      case TutorialPhase.joystickFine:
        return 'Try a small joystick movement for a fine steering correction.';
      case TutorialPhase.joystickStrong:
        return 'Now make a large movement. Full lock needs real travel, not a '
            'twitch near the base.';
      case TutorialPhase.joystickThrottle:
        return 'Use the shared throttle slider to change speed while steering.';
      case TutorialPhase.joystickRelease:
        return 'Release and recenter. Steering stops, but the slider keeps your '
            'speed where you left it.';
      case TutorialPhase.doubleTapClue:
        return 'Double-tap the control surface for a clue. This demonstration '
            'does not spend fuel or advance your hints.';
      case TutorialPhase.chooseControl:
        return 'Choose the control surface you want to keep.';
      case TutorialPhase.choosePlacement:
        return 'Choose how your one-handed control cluster should sit.';
      case TutorialPhase.chooseClue:
        return 'Choose a dedicated clue button or a control double-tap.';
      case TutorialPhase.ready:
        return 'Controls set. Here comes your first clue.';
      case TutorialPhase.complete:
        return '';
    }
  }

  TutorialTarget? get _target {
    switch (_phase) {
      case TutorialPhase.classicSteering:
      case TutorialPhase.classicThrottle:
        return TutorialTarget.classicControls;
      case TutorialPhase.dPadSteering:
        return TutorialTarget.dPad;
      case TutorialPhase.joystickFine:
      case TutorialPhase.joystickStrong:
      case TutorialPhase.joystickThrottle:
      case TutorialPhase.joystickRelease:
      case TutorialPhase.doubleTapClue:
        return TutorialTarget.joystick;
      case TutorialPhase.welcome:
      case TutorialPhase.chooseControl:
      case TutorialPhase.choosePlacement:
      case TutorialPhase.chooseClue:
      case TutorialPhase.ready:
      case TutorialPhase.complete:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == TutorialPhase.complete) return const SizedBox.shrink();
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    final canContinue = _isTapPhase || _fallbackAvailable;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          if (_showOverlay)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _isActionPhase && !_fallbackAvailable,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canContinue
                      ? (_isTapPhase ? _onTap : _advanceAction)
                      : null,
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
          Positioned(
            top: safePadding.top + 110,
            right: 12,
            left: 12,
            child: _CoachCard(
              coachName: mediaQuery.size.width > 500
                  ? widget.mission.coach.name
                  : 'Coach ${widget.mission.coach.name}',
              message: _message,
              progress: _progressLabel,
              showContinueButton: canContinue,
              continueLabel: _continueLabel,
              onTap:
                  canContinue ? (_isTapPhase ? _onTap : _advanceAction) : null,
            ),
          ),
          if (_phase == TutorialPhase.chooseControl)
            _ChoiceRow(
              bottom: safePadding.bottom + 132,
              children: ControlMode.values
                  .map(
                    (mode) => _ControlChoiceButton(
                      label: mode.displayName.toUpperCase(),
                      icon: mode == ControlMode.joystick
                          ? Icons.gamepad_outlined
                          : mode == ControlMode.dPad
                              ? Icons.dialpad_rounded
                              : Icons.swap_horiz,
                      onPressed: () => _selectControl(mode),
                    ),
                  )
                  .toList(),
            ),
          if (_phase == TutorialPhase.choosePlacement)
            _ChoiceRow(
              bottom: safePadding.bottom + 132,
              children: ControlPlacement.values
                  .map(
                    (placement) => _ControlChoiceButton(
                      label: placement.displayName.toUpperCase(),
                      icon: switch (placement) {
                        ControlPlacement.left =>
                          Icons.align_horizontal_left,
                        ControlPlacement.right =>
                          Icons.align_horizontal_right,
                        ControlPlacement.lowerCenter =>
                          Icons.align_horizontal_center,
                        ControlPlacement.sliderLeft =>
                          Icons.view_week_outlined,
                        ControlPlacement.sliderAbove =>
                          Icons.view_agenda_outlined,
                      },
                      onPressed: () => _selectPlacement(placement),
                    ),
                  )
                  .toList(),
            ),
          if (_phase == TutorialPhase.chooseClue)
            _ChoiceRow(
              bottom: safePadding.bottom + 132,
              children: ClueTrigger.values
                  .map(
                    (trigger) => _ControlChoiceButton(
                      label: trigger == ClueTrigger.button
                          ? 'BUTTON'
                          : 'DOUBLE-TAP',
                      icon: trigger == ClueTrigger.button
                          ? Icons.lightbulb_outline
                          : Icons.touch_app,
                      onPressed: () => _selectClue(trigger),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  String get _progressLabel {
    const steps = [
      TutorialPhase.classicSteering,
      TutorialPhase.classicThrottle,
      TutorialPhase.dPadSteering,
      TutorialPhase.joystickFine,
      TutorialPhase.joystickStrong,
      TutorialPhase.joystickThrottle,
      TutorialPhase.joystickRelease,
      TutorialPhase.doubleTapClue,
    ];
    final index = steps.indexOf(_phase);
    if (index < 0) return '';
    return 'Step ${index + 1} of ${steps.length}';
  }

  bool get _isActionPhase =>
      _phase.index >= TutorialPhase.classicSteering.index &&
      _phase.index <= TutorialPhase.doubleTapClue.index;

  bool get _isTapPhase =>
      _phase == TutorialPhase.welcome || _phase == TutorialPhase.ready;
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.bottom, required this.children});

  final double bottom;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 20,
        right: 20,
        bottom: bottom,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: children,
        ),
      );
}

class _ControlChoiceButton extends StatelessWidget {
  const _ControlChoiceButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: FlitColors.accent,
          foregroundColor: FlitColors.backgroundDark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

enum TutorialTarget { classicControls, dPad, joystick }

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.coachName,
    required this.message,
    required this.progress,
    required this.showContinueButton,
    required this.continueLabel,
    required this.onTap,
  });

  final String coachName;
  final String message;
  final String progress;
  final bool showContinueButton;
  final String continueLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlitColors.accent.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff,
                    color: FlitColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coachName,
                    style: const TextStyle(
                      color: FlitColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (progress.isNotEmpty)
                  Text(
                    progress,
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (showContinueButton) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onTap,
                child: Text(
                  continueLabel,
                  style: const TextStyle(color: FlitColors.accent),
                ),
              ),
            ],
          ],
        ),
      );
}

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
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, darkPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(16)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(16)),
      Paint()
        ..color = FlitColors.accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Rect _spotlightRect(TutorialTarget target, Size size) {
    final bottom = size.height - safePadding.bottom;
    switch (target) {
      case TutorialTarget.classicControls:
        return Rect.fromLTRB(0, bottom - 150, size.width, bottom + 6);
      case TutorialTarget.dPad:
      case TutorialTarget.joystick:
        return Rect.fromCenter(
          center: Offset(size.width / 2, bottom - 86),
          width: min(size.width - 24, 236.0),
          height: 198,
        );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
