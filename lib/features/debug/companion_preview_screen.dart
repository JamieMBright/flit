import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import '../../game/rendering/companion_art.dart';

/// Debug screen that renders every companion creature side-by-side at large
/// scale with animated wing flapping.
///
/// Intended for visual QA — screenshot this screen and share it to iterate
/// on companion shapes without hunting them down in-game.
///
/// Only accessible via the admin Design Preview section.
class CompanionPreviewScreen extends StatefulWidget {
  const CompanionPreviewScreen({super.key});

  @override
  State<CompanionPreviewScreen> createState() => _CompanionPreviewScreenState();
}

class _CompanionPreviewScreenState extends State<CompanionPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  /// Companions to display (skip `none`).
  static final _companions =
      AvatarCompanion.values.where((c) => c != AvatarCompanion.none).toList();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.cardBackground,
          title: const Text(
            'Companion Preview',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        ),
        body: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _companions.length,
            itemBuilder: (context, index) {
              final companion = _companions[index];
              return _CompanionCard(
                companion: companion,
                flapPhase: _animController.value * 2 * pi * 2,
                breathPhase: _animController.value * 2 * pi * 1.4,
              );
            },
          ),
        ),
      );
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.companion,
    required this.flapPhase,
    required this.breathPhase,
  });

  final AvatarCompanion companion;
  final double flapPhase;
  final double breathPhase;

  @override
  Widget build(BuildContext context) {
    final price = AvatarConfig.companionPrice(companion);

    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tierColor(price), width: 1.5),
      ),
      child: Column(
        children: [
          // Companion rendering area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                painter: _CompanionPreviewPainter(
                  companion: companion,
                  flapPhase: flapPhase,
                  breathPhase: breathPhase,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // Label area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companionLabel(companion),
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${companion.name} · companion_${companion.name}',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${_tierLabel(price)} · $price coins',
                  style: TextStyle(
                    color: _tierColor(price),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _companionLabel(AvatarCompanion c) => switch (c) {
        AvatarCompanion.none => 'None',
        AvatarCompanion.pidgey => 'Pidgey',
        AvatarCompanion.sparrow => 'Sparrow',
        AvatarCompanion.eagle => 'Eagle',
        AvatarCompanion.parrot => 'Parrot',
        AvatarCompanion.phoenix => 'Phoenix',
        AvatarCompanion.dragon => 'Dragon',
        AvatarCompanion.charizard => 'Charizard',
      };

  static String _tierLabel(int price) {
    if (price >= 30000) return 'Legendary';
    if (price >= 8000) return 'Epic';
    if (price >= 2000) return 'Rare';
    if (price > 0) return 'Common';
    return 'Free';
  }

  static Color _tierColor(int price) {
    if (price >= 30000) return FlitColors.gold;
    if (price >= 8000) return const Color(0xFF9B59B6);
    if (price >= 2000) return FlitColors.oceanHighlight;
    return FlitColors.textSecondary;
  }
}

// =============================================================================
// Companion Preview Painter — animated procedural sprite rendering.
// =============================================================================

/// Thin wrapper around the shared [CompanionArt] painter — the exact same
/// code path the in-game [CompanionRenderer] uses, so this preview is
/// always faithful to gameplay (single source of truth per CLAUDE.md).
class _CompanionPreviewPainter extends CustomPainter {
  _CompanionPreviewPainter({
    required this.companion,
    required this.flapPhase,
    required this.breathPhase,
  });

  final AvatarCompanion companion;
  final double flapPhase;
  final double breathPhase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.shortestSide / CompanionArt.footprintOf(companion);
    canvas.scale(scale);
    CompanionArt.paint(
      canvas,
      companion,
      flapPhase: flapPhase,
      breathPhase: breathPhase,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompanionPreviewPainter oldDelegate) =>
      oldDelegate.companion != companion ||
      oldDelegate.flapPhase != flapPhase ||
      oldDelegate.breathPhase != breathPhase;
}
