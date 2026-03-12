import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';

/// Aviation-themed dismiss button labels. A random one is picked each time.
const _dismissLabels = [
  'Roger!',
  'Affirmative!',
  'Copy that!',
  'Wilco!',
  'Understood!',
  '10-4!',
];

/// Semi-transparent overlay that shows coach tips during campaign missions.
///
/// The coach's avatar sits in the top-right corner of the screen. When a tip
/// is active, a speech bubble appears below the avatar with an aviation-themed
/// dismiss button. Tips auto-dismiss after a delay or when the button is tapped.
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
  String _dismissLabel = _dismissLabels[0];
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

  static final _rng = Random();

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
      _dismissLabel = _dismissLabels[_rng.nextInt(_dismissLabels.length)];
      _visible = true;
    });
    _animController.forward(from: 0);

    // Auto-dismiss after 8 seconds (slightly longer to give time to read).
    Future.delayed(const Duration(seconds: 8), () {
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
    final coach = widget.mission.coach;
    final safePadding = MediaQuery.of(context).padding;

    // Always show the coach avatar in the top-right. Speech bubble appears
    // below it only when a tip is active.
    return Positioned(
      top: safePadding.top + 40,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coach avatar — always visible during campaign
          _CoachAvatar(
            flagEmoji: coach.flagEmoji,
            name: coach.shortName,
          ),

          // Speech bubble — slides in when a tip is active
          if (_visible && _currentMessage != null)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(_slideAnim),
              child: FadeTransition(
                opacity: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _SpeechBubble(
                    coachName: coach.name,
                    message: _currentMessage!,
                    dismissLabel: _dismissLabel,
                    onDismiss: _dismiss,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small circular coach avatar shown in the top-right corner.
class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.flagEmoji, required this.name});

  final String flagEmoji;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
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
      ),
      child: Center(
        child: Text(
          flagEmoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

/// Speech bubble widget with a small tail pointing up-right toward the avatar.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.coachName,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final String coachName;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // Constrain width so it doesn't stretch the full screen on tablets.
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth * 0.7).clamp(200.0, 320.0);

    return SizedBox(
      width: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tail triangle pointing up toward the avatar
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
              color: FlitColors.cardBackground.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlitColors.accent.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coach name
                Text(
                  coachName,
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Message text
                Text(
                  message,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Aviation-themed dismiss button
                Center(
                  child: GestureDetector(
                    onTap: onDismiss,
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
                        dismissLabel,
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the small triangular tail that connects the speech bubble to the
/// coach avatar above.
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FlitColors.cardBackground.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);

    // Border on the tail edges (not the bottom, which merges with the bubble).
    final borderPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: 0.3)
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
