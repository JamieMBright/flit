import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../game/rendering/plane_renderer.dart';

/// Debug screen that renders every plane variant side-by-side at large scale.
///
/// Intended for visual QA — screenshot this screen and share it to iterate
/// on plane shapes without hunting them down in-game.
///
/// Only accessible in debug/profile builds.
class PlanePreviewScreen extends StatefulWidget {
  const PlanePreviewScreen({super.key});

  @override
  State<PlanePreviewScreen> createState() => _PlanePreviewScreenState();
}

class _PlanePreviewScreenState extends State<PlanePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _propController;

  @override
  void initState() {
    super.initState();
    _propController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _propController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const planes = CosmeticCatalog.planes;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Plane Preview',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: AnimatedBuilder(
        animation: _propController,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: planes.length,
          itemBuilder: (context, index) {
            final plane = planes[index];
            return _PlaneCard(
              plane: plane,
              propAngle: _propController.value * 2 * pi,
            );
          },
        ),
      ),
    );
  }
}

class _PlaneCard extends StatelessWidget {
  const _PlaneCard({required this.plane, required this.propAngle});

  final Cosmetic plane;
  final double propAngle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rarityColor(plane.rarity), width: 1.5),
      ),
      child: Column(
        children: [
          // Plane rendering area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                painter: _PlanePreviewPainter(
                  planeId: plane.id,
                  colorScheme: plane.colorScheme,
                  wingSpan: plane.wingSpan ?? 26.0,
                  propAngle: propAngle,
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
                  plane.name,
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
                  '${plane.id} · ws: ${plane.wingSpan ?? 26.0}',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${plane.rarity.name} · ${plane.price} coins',
                  style: TextStyle(
                    color: _rarityColor(plane.rarity),
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

  static Color _rarityColor(CosmeticRarity rarity) => switch (rarity) {
    CosmeticRarity.common => FlitColors.textSecondary,
    CosmeticRarity.rare => FlitColors.oceanHighlight,
    CosmeticRarity.epic => const Color(0xFF9B59B6),
    CosmeticRarity.legendary => FlitColors.gold,
  };
}

class _PlanePreviewPainter extends CustomPainter {
  _PlanePreviewPainter({
    required this.planeId,
    required this.colorScheme,
    required this.wingSpan,
    required this.propAngle,
  });

  final String planeId;
  final Map<String, int>? colorScheme;
  final double wingSpan;
  final double propAngle;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale up to fill the card while keeping proportions.
    // Planes are drawn centered at origin, nose pointing up.
    final scale = min(size.width, size.height) / (wingSpan * 2.5);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    PlaneRenderer.renderPlane(
      canvas: canvas,
      bankCos: 1.0, // level flight
      bankSin: 0.0,
      wingSpan: wingSpan,
      planeId: planeId,
      colorScheme: colorScheme,
      propAngle: propAngle,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanePreviewPainter old) =>
      old.propAngle != propAngle || old.planeId != planeId;
}
