import 'package:flutter/material.dart';

import '../../game/tutorial/coach.dart';
import 'coach_portrait.dart';

/// Portrait + cream speech bubble used by the guided training lessons
/// (Training Recon, Training Briefing) and the Advanced Training coached
/// intros. Matches the campaign coach aesthetic without pulling in the
/// play-screen's mission-bound CoachOverlay, so any lesson surface can host
/// a coach talking the pilot through a mechanic step by step.
class CoachSpeechPanel extends StatelessWidget {
  const CoachSpeechPanel({
    super.key,
    required this.coach,
    required this.message,
  });

  final Coach coach;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4C9B8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachPortrait(coach: coach, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coach.name,
                  style: const TextStyle(
                    color: Color(0xFFC45E2C),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 13,
                    height: 1.32,
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
