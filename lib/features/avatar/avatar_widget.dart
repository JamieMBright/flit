import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// Renders a DiceBear Adventurer avatar from the network as an SVG.
///
/// Builds a fully-specified DiceBear API URL from the given [AvatarConfig]
/// so the avatar is deterministic. Shows a themed placeholder while loading
/// and a fallback icon on error.
///
/// The widget sizes itself to [size] x [size] logical pixels and is safe
/// to use anywhere a square widget is expected (lists, cards, profiles).
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
  });

  final AvatarConfig config;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            shape: BoxShape.circle,
            border: Border.all(
              color: FlitColors.cardBorder,
              width: size * 0.02,
            ),
          ),
          child: SvgPicture.network(
            config.svgUri.toString(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => _AvatarPlaceholder(size: size),
            errorBuilder: (_, __, ___) => _AvatarFallback(size: size),
          ),
        ),
      ),
    );
  }
}

/// Fallback shown when the SVG avatar fails to load or parse.
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: FlitColors.backgroundMid,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.5,
        color: FlitColors.accent,
      ),
    );
  }
}

/// Placeholder shown while the SVG avatar is loading from the network.
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: FlitColors.backgroundMid,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: FlitColors.accent,
          ),
        ),
      ),
    );
  }
}
