import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/coach.dart';

/// Circular coach portrait — shows the coach's cartoonised asset image with
/// a deterministic initial-circle fallback. Shared by the campaign mission
/// dialogs and the Basic/Advanced Training surfaces.
class CoachPortrait extends StatelessWidget {
  const CoachPortrait({super.key, required this.coach, this.size = 48});

  final Coach coach;
  final double size;

  @override
  Widget build(BuildContext context) {
    // If an asset image is provided, try loading it.
    if (coach.imageAsset != null) {
      return ClipOval(
        child: Image.asset(
          coach.imageAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialCircle(),
        ),
      );
    }
    return _initialCircle();
  }

  Widget _initialCircle() {
    // Deterministic colour from coach ID hash.
    final colors = [
      FlitColors.accent,
      FlitColors.success,
      FlitColors.warning,
      const Color(0xFF7C4DFF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6D00),
      const Color(0xFFAA00FF),
      const Color(0xFF2979FF),
      const Color(0xFFD50000),
      const Color(0xFF00C853),
    ];
    final colorIndex = coach.id.hashCode.abs() % colors.length;
    final bgColor = colors[colorIndex];

    // Extract initials (first letter of first and last name).
    final parts = coach.name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : parts.first.substring(0, 2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor.withValues(alpha: 0.2),
        border: Border.all(color: bgColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            initials.toUpperCase(),
            style: TextStyle(
              color: bgColor,
              fontSize: size * 0.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          // Flag badge at bottom-right
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              coach.flagEmoji,
              style: TextStyle(fontSize: size * 0.28),
            ),
          ),
        ],
      ),
    );
  }
}
