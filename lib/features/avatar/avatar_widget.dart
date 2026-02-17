import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// Renders a DiceBear avatar from the network as an SVG.
///
/// Builds a fully-specified DiceBear API URL from the given [AvatarConfig]
/// so the avatar is deterministic. Shows a themed placeholder while loading
/// and a fallback icon on error or timeout.
///
/// The widget sizes itself to [size] x [size] logical pixels and is safe
/// to use anywhere a square widget is expected (lists, cards, profiles).
class AvatarWidget extends StatefulWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
  });

  final AvatarConfig config;
  final double size;

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  bool _timedOut = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  @override
  void didUpdateWidget(AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      setState(() {
        _timedOut = false;
        _hasError = false;
      });
      _startTimeout();
    }
  }

  void _startTimeout() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_hasError) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            shape: BoxShape.circle,
            border: Border.all(
              color: FlitColors.cardBorder,
              width: widget.size * 0.02,
            ),
          ),
          child: (_timedOut || _hasError)
              ? _AvatarFallback(size: widget.size)
              : SvgPicture.network(
                  widget.config.svgUri.toString(),
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  placeholderBuilder: (_) =>
                      _AvatarPlaceholder(size: widget.size),
                ),
        ),
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

/// Fallback shown when avatar loading fails or times out.
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
        Icons.person_rounded,
        size: size * 0.5,
        color: FlitColors.textMuted,
      ),
    );
  }
}
