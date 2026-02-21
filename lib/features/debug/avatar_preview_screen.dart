import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import '../../features/avatar/avatar_widget.dart';

/// Debug screen that renders every avatar style side-by-side.
///
/// Shows each of the 10 DiceBear styles with default config, plus a few
/// feature variations, so you can visually compare all styles at once.
///
/// Only accessible in debug/profile builds.
class AvatarPreviewScreen extends StatelessWidget {
  const AvatarPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Avatar Preview',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── All 10 styles with default config ──
          const _SectionLabel(text: 'All Styles (default features)'),
          const SizedBox(height: 8),
          _StyleGrid(
            configs: AvatarStyle.values.map((style) {
              return AvatarConfig(style: style);
            }).toList(),
            labelBuilder: (config) => config.style.label,
          ),

          // ── Feature variations for every style ──
          ...AvatarStyle.values.expand(
            (style) => [
              const SizedBox(height: 24),
              _SectionLabel(text: '${style.label} — Variations'),
              const SizedBox(height: 8),
              _StyleGrid(
                configs: [
                  AvatarConfig(style: style),
                  AvatarConfig(
                    style: style,
                    eyes: AvatarEyes.variant05,
                    mouth: AvatarMouth.variant08,
                    hair: AvatarHair.long03,
                    hairColor: AvatarHairColor.auburn,
                  ),
                  AvatarConfig(
                    style: style,
                    eyes: AvatarEyes.variant10,
                    mouth: AvatarMouth.variant15,
                    hair: AvatarHair.short10,
                    hairColor: AvatarHairColor.black,
                    skinColor: AvatarSkinColor.dark,
                    glasses: AvatarGlasses.variant02,
                  ),
                  AvatarConfig(
                    style: style,
                    eyes: AvatarEyes.variant03,
                    mouth: AvatarMouth.variant04,
                    hair: AvatarHair.long12,
                    hairColor: AvatarHairColor.blonde,
                    skinColor: AvatarSkinColor.light,
                    feature: AvatarFeature.freckles,
                  ),
                  AvatarConfig(
                    style: style,
                    eyes: AvatarEyes.variant08,
                    mouth: AvatarMouth.variant10,
                    hair: AvatarHair.none,
                    skinColor: AvatarSkinColor.mediumLight,
                    feature: AvatarFeature.mustache,
                  ),
                ],
                labelBuilder: (config) {
                  if (config.hair == AvatarHair.none) return 'Bald + Stache';
                  if (config.feature == AvatarFeature.freckles) {
                    return 'Freckles';
                  }
                  if (config.glasses != AvatarGlasses.none) return 'Glasses';
                  if (config.hairColor == AvatarHairColor.auburn) {
                    return 'Auburn';
                  }
                  if (config.eyes == AvatarEyes.values.first) return 'Default';
                  return 'Variation';
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Skin tones across every style ──
          ...AvatarStyle.values.expand(
            (style) => [
              const SizedBox(height: 24),
              _SectionLabel(text: '${style.label} — Skin Tones'),
              const SizedBox(height: 8),
              _StyleGrid(
                configs: AvatarSkinColor.values.map((skin) {
                  return AvatarConfig(style: style, skinColor: skin);
                }).toList(),
                labelBuilder: (config) => config.skinColor.label,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Hair colors across every style ──
          ...AvatarStyle.values.expand(
            (style) => [
              const SizedBox(height: 24),
              _SectionLabel(text: '${style.label} — Hair Colors'),
              const SizedBox(height: 8),
              _StyleGrid(
                configs: AvatarHairColor.values.map((color) {
                  return AvatarConfig(
                    style: style,
                    hair: AvatarHair.short05,
                    hairColor: color,
                  );
                }).toList(),
                labelBuilder: (config) => config.hairColor.label,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: FlitColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({required this.configs, required this.labelBuilder});

  final List<AvatarConfig> configs;
  final String Function(AvatarConfig) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: configs.map((config) {
        return _AvatarCard(config: config, label: labelBuilder(config));
      }).toList(),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.config, required this.label});

  final AvatarConfig config;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          AvatarWidget(config: config, size: 80),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
