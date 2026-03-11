import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';

/// Semi-transparent overlay that shows coach tips during campaign missions.
///
/// Place this in a Stack on top of the game view. Call [showTip] when a
/// trigger event fires. Tips auto-dismiss after a delay or on user tap.
///
/// Also supports time-based "lost" detection: if no correct answer is given
/// within a configurable interval, the coach proactively offers help.
class CoachOverlay extends StatefulWidget {
  const CoachOverlay({super.key, required this.mission});

  final CampaignMission mission;

  @override
  State<CoachOverlay> createState() => CoachOverlayState();
}

class CoachOverlayState extends State<CoachOverlay>
    with SingleTickerProviderStateMixin {
  String? _currentMessage;
  bool _visible = false;
  final Set<String> _shownTriggers = {};

  late final AnimationController _animController;
  late final Animation<double> _slideAnim;

  /// Timer for detecting when the player seems lost.
  Timer? _lostTimer;

  /// How long without progress before showing a "lost" hint.
  static const _lostThreshold = Duration(seconds: 20);

  /// Number of "lost" hints shown this session (caps at 3 to avoid nagging).
  int _lostHintCount = 0;
  static const _maxLostHints = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _lostTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Start the "lost" detection timer. Call this when a new round/clue begins.
  /// Resets any existing timer.
  void startLostTimer() {
    _lostTimer?.cancel();
    if (_lostHintCount >= _maxLostHints) return;
    _lostTimer = Timer(_lostThreshold, _onPlayerLost);
  }

  /// Reset the lost timer (call on any player activity: movement, hint use).
  void resetLostTimer() {
    if (_lostTimer == null || !_lostTimer!.isActive) return;
    startLostTimer();
  }

  /// Cancel the lost timer (call on correct answer or round end).
  void cancelLostTimer() {
    _lostTimer?.cancel();
    _lostTimer = null;
  }

  void _onPlayerLost() {
    if (!mounted || _lostHintCount >= _maxLostHints) return;
    _lostHintCount++;

    // Try to show the 'lost' trigger first, then fall back to encouragement.
    if (!showTip('lost')) {
      _showMessage(_lostEncouragement());
    }
    // Restart for another potential nudge.
    startLostTimer();
  }

  String _lostEncouragement() {
    final coach = widget.mission.coach.shortName;
    switch (_lostHintCount) {
      case 1:
        return 'Take your time — study the clues carefully. '
            'You\'ve got this!';
      case 2:
        return 'Stuck? Try using a hint to narrow things down. '
            '$coach believes in you.';
      default:
        return 'Don\'t give up. Look at the clue again and think about '
            'which region of the world it points to.';
    }
  }

  /// Show a tip for the given trigger, if one exists for this mission and
  /// hasn't been shown yet. Returns true if a tip was shown.
  bool showTip(String trigger) {
    if (_shownTriggers.contains(trigger)) return false;
    final tip = widget.mission.tips.cast<CoachTip?>().firstWhere(
          (t) => t!.trigger == trigger,
          orElse: () => null,
        );
    if (tip == null) return false;

    _shownTriggers.add(trigger);
    _showMessage(tip.message);
    return true;
  }

  /// Show a custom message from the coach (not tied to a trigger).
  void showCustomMessage(String message) => _showMessage(message);

  void _showMessage(String message) {
    setState(() {
      _currentMessage = message;
      _visible = true;
    });
    _animController.forward(from: 0);

    // Auto-dismiss after 6 seconds.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _visible && _currentMessage == message) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _visible = false;
          _currentMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _currentMessage == null) {
      return const SizedBox.shrink();
    }

    final coach = widget.mission.coach;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 100,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_slideAnim),
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: FlitColors.accent.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coach avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FlitColors.accent.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      coach.flagEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coach.name,
                        style: const TextStyle(
                          color: FlitColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentMessage!,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dismiss button — tick in circle
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FlitColors.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: FlitColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
