import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../clues/clue_types.dart';

/// Game HUD overlay showing clues, timer, altitude indicator.
/// Styled with a vintage atlas / lo-fi pop art aesthetic.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.isHighAltitude,
    required this.elapsedTime,
    this.currentClue,
    this.onAltitudeToggle,
  });

  final bool isHighAltitude;
  final Duration elapsedTime;
  final Clue? currentClue;
  final VoidCallback? onAltitudeToggle;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: Clue and Timer
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clue display
                  if (currentClue != null)
                    Expanded(
                      child: _ClueCard(clue: currentClue!),
                    ),
                  const SizedBox(width: 12),
                  // Timer
                  _TimerDisplay(elapsed: elapsedTime),
                ],
              ),
              const Spacer(),
              // Bottom row: Altitude indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AltitudeIndicator(
                    isHigh: isHighAltitude,
                    onToggle: onAltitudeToggle,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clue type label
            Text(
              _clueTypeLabel(clue.type),
              style: TextStyle(
                color: FlitColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // Clue content
            if (clue.type == ClueType.flag)
              Text(
                clue.displayData['flagEmoji'] as String,
                style: const TextStyle(fontSize: 48),
              )
            else
              Text(
                clue.displayText,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
          ],
        ),
      );

  String _clueTypeLabel(ClueType type) {
    switch (type) {
      case ClueType.flag:
        return 'FLAG';
      case ClueType.outline:
        return 'OUTLINE';
      case ClueType.borders:
        return 'BORDERS';
      case ClueType.capital:
        return 'CAPITAL';
      case ClueType.stats:
        return 'STATS';
    }
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final millis = (elapsed.inMilliseconds % 1000) ~/ 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _AltitudeIndicator extends StatelessWidget {
  const _AltitudeIndicator({
    required this.isHigh,
    this.onToggle,
  });

  final bool isHigh;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHigh ? FlitColors.accent : FlitColors.success,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHigh ? Icons.flight_takeoff : Icons.flight_land,
                color: isHigh ? FlitColors.accent : FlitColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isHigh ? 'CRUISING' : 'DESCENDING',
                style: TextStyle(
                  color: isHigh ? FlitColors.accent : FlitColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
}
