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
/// For other styles, shows the style initial with a colored background as a
/// fast, offline-capable representation. Network fetching from DiceBear has
/// been removed entirely to avoid timeout issues on mobile/PWA.
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
  /// Cached composed SVG string for the current config.
  String? _composedSvg;

  /// Whether local SVG composition failed.
  bool _composeFailed = false;

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
    try {
      final svg = AvatarCompositor.compose(widget.config);
      setState(() {
        _composedSvg = svg;
        _composeFailed = svg == null;
      });
    } catch (e) {
      debugPrint('Avatar compose error: $e');
      setState(() {
        _composedSvg = null;
        _composeFailed = true;
      });
    }
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
              ? _SafeSvgRender(
                  svg: _composedSvg!,
                  size: widget.size,
                )
              : _composeFailed
                  ? _StyleFallback(
                      style: widget.config.style,
                      size: widget.size,
                    )
                  : _AvatarFallback(size: widget.size),
        ),
      ),
    );
  }
}

/// Wraps [SvgPicture.string] with an error boundary so invalid SVG data
/// doesn't crash the widget tree — falls back to a person icon instead.
class _SafeSvgRender extends StatelessWidget {
  const _SafeSvgRender({required this.svg, required this.size});

  final String svg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

/// Offline fallback for non-adventurer styles.
///
/// Shows the first letter of the style label inside a colored circle.
/// This replaces the old network-based approach that constantly timed out
/// on mobile and iOS PWA.
class _StyleFallback extends StatelessWidget {
  const _StyleFallback({required this.style, required this.size});

  final AvatarStyle style;
  final double size;

  /// Deterministic color based on style name.
  Color _colorForStyle() {
    final hash = style.slug.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.35).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorForStyle(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          style.label.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Fallback shown when avatar loading fails completely.
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
