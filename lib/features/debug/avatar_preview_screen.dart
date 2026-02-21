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
      backgroundColor: FlitColors.backgroundDeep,
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

          const SizedBox(height: 24),

          // ── Adventurer with different features ──
          const _SectionLabel(text: 'Adventurer — Feature Variations'),
          const SizedBox(height: 8),
          _StyleGrid(
            configs: [
              const AvatarConfig(),
              const AvatarConfig(
                eyes: AvatarEyes.variant05,
                mouth: AvatarMouth.variant08,
                hair: AvatarHair.long03,
                hairColor: AvatarHairColor.auburn,
              ),
              const AvatarConfig(
                eyes: AvatarEyes.variant10,
                eyebrows: AvatarEyebrows.variant06,
                mouth: AvatarMouth.variant15,
                hair: AvatarHair.short10,
                hairColor: AvatarHairColor.black,
                skinColor: AvatarSkinColor.dark,
                glasses: AvatarGlasses.variant02,
              ),
              const AvatarConfig(
                eyes: AvatarEyes.variant03,
                mouth: AvatarMouth.variant04,
                hair: AvatarHair.long12,
                hairColor: AvatarHairColor.blonde,
                skinColor: AvatarSkinColor.light,
                feature: AvatarFeature.freckles,
                earrings: AvatarEarrings.variant01,
              ),
              const AvatarConfig(
                eyes: AvatarEyes.variant20,
                eyebrows: AvatarEyebrows.variant12,
                mouth: AvatarMouth.variant22,
                hair: AvatarHair.short15,
                hairColor: AvatarHairColor.teal,
                skinColor: AvatarSkinColor.medium,
                glasses: AvatarGlasses.variant04,
              ),
              const AvatarConfig(
                eyes: AvatarEyes.variant08,
                mouth: AvatarMouth.variant10,
                hair: AvatarHair.none,
                skinColor: AvatarSkinColor.mediumLight,
                feature: AvatarFeature.mustache,
              ),
            ],
            labelBuilder: (config) {
              if (config.hair == AvatarHair.none) return 'Bald + Stache';
              if (config.feature == AvatarFeature.freckles) return 'Freckles';
              if (config.glasses != AvatarGlasses.none) return 'Glasses';
              if (config.hairColor == AvatarHairColor.auburn) return 'Auburn';
              if (config == const AvatarConfig()) return 'Default';
              return 'Variation';
            },
          ),

          const SizedBox(height: 24),

          // ── Skin tones across adventurer ──
          const _SectionLabel(text: 'Adventurer — Skin Tones'),
          const SizedBox(height: 8),
          _StyleGrid(
            configs: AvatarSkinColor.values.map((skin) {
              return AvatarConfig(skinColor: skin);
            }).toList(),
            labelBuilder: (config) => config.skinColor.label,
          ),

          const SizedBox(height: 24),

          // ── Hair colors ──
          const _SectionLabel(text: 'Adventurer — Hair Colors'),
          const SizedBox(height: 8),
          _StyleGrid(
            configs: AvatarHairColor.values.map((color) {
              return AvatarConfig(hair: AvatarHair.short05, hairColor: color);
            }).toList(),
            labelBuilder: (config) => config.hairColor.label,
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
