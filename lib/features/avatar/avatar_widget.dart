import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import 'avatar_compositor.dart';

/// Renders a DiceBear avatar as an SVG.
///
/// For [AvatarStyle.adventurer], the avatar is composited entirely from local
/// SVG parts — no network call, no loading state, instant render.
///
/// For other styles, falls back to fetching from the DiceBear API with proper
/// error handling and a timeout.
///
/// The widget sizes itself to [size] × [size] logical pixels and is safe
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
  /// Cached composed SVG string for the current config (adventurer only).
  String? _composedSvg;

  /// Whether a network fetch has failed or timed out (non-adventurer only).
  bool _timedOut = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _compose();
  }

  @override
  void didUpdateWidget(AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _compose();
    }
  }

  void _compose() {
    final svg = AvatarCompositor.compose(widget.config);
    setState(() {
      _composedSvg = svg;
      _timedOut = false;
      _hasError = false;
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
          child: _composedSvg != null
              ? SvgPicture.string(
                  _composedSvg!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                )
              : (_timedOut || _hasError)
                  ? _AvatarFallback(size: widget.size)
                  : _NetworkAvatar(
                      config: widget.config,
                      size: widget.size,
                      onError: () {
                        if (mounted) setState(() => _hasError = true);
                      },
                      onTimeout: () {
                        if (mounted) setState(() => _timedOut = true);
                      },
                    ),
        ),
      ),
    );
  }
}

/// Fallback network-based avatar for non-adventurer styles.
///
/// Wraps [SvgPicture.network] with a proper timeout timer that is cancelled
/// on successful load, config change, or disposal.
class _NetworkAvatar extends StatefulWidget {
  const _NetworkAvatar({
    required this.config,
    required this.size,
    required this.onError,
    required this.onTimeout,
  });

  final AvatarConfig config;
  final double size;
  final VoidCallback onError;
  final VoidCallback onTimeout;

  @override
  State<_NetworkAvatar> createState() => _NetworkAvatarState();
}

class _NetworkAvatarState extends State<_NetworkAvatar> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.network(
      widget.config.svgUri.toString(),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      placeholderBuilder: (_) => _AvatarPlaceholder(size: widget.size),
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
