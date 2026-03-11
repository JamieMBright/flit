import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../../game/tutorial/coach.dart';

/// Semi-transparent overlay that shows coach tips during campaign missions.
///
/// Place this in a Stack on top of the game view. Call [showTip] when a
/// trigger event fires. Tips auto-dismiss after a delay or on user tap.
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
    _animController.dispose();
    super.dispose();
  }

  /// Show a tip for the given trigger, if one exists for this mission and
  /// hasn't been shown yet.
  void showTip(String trigger) {
    if (_shownTriggers.contains(trigger)) return;
    final tip = widget.mission.tips.cast<CoachTip?>().firstWhere(
          (t) => t!.trigger == trigger,
          orElse: () => null,
        );
    if (tip == null) return;

    _shownTriggers.add(trigger);
    setState(() {
      _currentMessage = tip.message;
      _visible = true;
    });
    _animController.forward(from: 0);

    // Auto-dismiss after 6 seconds.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _visible && _currentMessage == tip.message) {
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
              color: FlitColors.cardBackground.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: FlitColors.accent.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
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
                    color: FlitColors.accent.withOpacity(0.2),
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
                // Dismiss button
                GestureDetector(
                  onTap: _dismiss,
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
