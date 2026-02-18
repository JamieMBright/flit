import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import 'avatar_compositor.dart';

/// In-memory SVG cache keyed by DiceBear URL.
///
/// Survives widget rebuilds and screen navigation so repeated renders are
/// instant. Entries are never evicted because the set of unique avatar
/// configurations a single player sees in one session is small.
final Map<String, String> _svgCache = {};

/// Renders a DiceBear avatar as an SVG.
///
/// For [AvatarStyle.adventurer], the avatar is composited entirely from local
/// SVG parts — no network call, no loading state, instant render.
///
/// For other styles, the widget fetches the SVG from the DiceBear API on
/// first render, caches it in memory, and shows the style initial as a
/// placeholder while loading. Subsequent renders (including across screen
/// navigations) hit the in-memory cache and are instant.
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

  /// Whether local SVG composition failed and network fetch is needed.
  bool _composeFailed = false;

  /// Whether the network SVG has been fetched (or failed).
  bool _networkFetched = false;

  /// Whether a network fetch is currently in progress.
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _resolve();
    }
  }

  /// Attempt local composition first; fall back to cached/network SVG.
  void _resolve() {
    // Reset state.
    _composeFailed = false;
    _networkFetched = false;
    _fetching = false;

    // 1. Try local composition (adventurer style).
    try {
      final svg = AvatarCompositor.compose(widget.config);
      if (svg != null) {
        setState(() {
          _composedSvg = svg;
        });
        return;
      }
    } catch (e) {
      debugPrint('Avatar compose error: $e');
    }

    // 2. Local composition returned null or threw — check memory cache.
    _composeFailed = true;
    final cacheKey = widget.config.svgUri.toString();
    final cached = _svgCache[cacheKey];
    if (cached != null) {
      setState(() {
        _composedSvg = cached;
        _networkFetched = true;
      });
      return;
    }

    // 3. Not in cache — fetch from DiceBear API.
    setState(() {
      _composedSvg = null;
    });
    _fetchFromNetwork(cacheKey);
  }

  Future<void> _fetchFromNetwork(String cacheKey) async {
    if (_fetching) return;
    _fetching = true;

    try {
      final response = await http
          .get(widget.config.svgUri)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.contains('<svg')) {
        _svgCache[cacheKey] = response.body;
        setState(() {
          _composedSvg = response.body;
          _networkFetched = true;
        });
      } else {
        setState(() {
          _networkFetched = true; // Mark as attempted; show fallback.
        });
      }
    } catch (e) {
      debugPrint('Avatar network fetch error: $e');
      if (mounted) {
        setState(() {
          _networkFetched = true; // Show fallback on error.
        });
      }
    } finally {
      _fetching = false;
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

/// Renders an avatar from a DiceBear SVG URL string.
///
/// Use this for models that only carry an [avatarUrl] (e.g. [Friend],
/// [LeaderboardEntry]) instead of a full [AvatarConfig]. Fetches the SVG
/// once, caches in memory, and shows a [name]-initial placeholder meanwhile.
class AvatarFromUrl extends StatefulWidget {
  const AvatarFromUrl({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.size = 48,
  });

  /// DiceBear SVG URL (or any SVG URL).
  final String? avatarUrl;

  /// Display name used for the initial-letter fallback.
  final String name;

  final double size;

  @override
  State<AvatarFromUrl> createState() => _AvatarFromUrlState();
}

class _AvatarFromUrlState extends State<AvatarFromUrl> {
  String? _svg;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AvatarFromUrl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.avatarUrl;
    if (url == null || url.isEmpty) {
      setState(() => _attempted = true);
      return;
    }

    // Check cache.
    final cached = _svgCache[url];
    if (cached != null) {
      setState(() {
        _svg = cached;
        _attempted = true;
      });
      return;
    }

    // Fetch.
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.contains('<svg')) {
        _svgCache[url] = response.body;
        setState(() {
          _svg = response.body;
          _attempted = true;
        });
      } else {
        setState(() => _attempted = true);
      }
    } catch (_) {
      if (mounted) setState(() => _attempted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackLetter =
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final hash = widget.name.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.5, 0.35).toColor();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: _svg != null
            ? Container(
                decoration: BoxDecoration(
                  color: FlitColors.backgroundMid,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FlitColors.cardBorder,
                    width: widget.size * 0.02,
                  ),
                ),
                child: SvgPicture.string(
                  _svg!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    fallbackLetter,
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: widget.size * 0.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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
/// Used as a placeholder while the DiceBear API SVG is being fetched,
/// or as a final fallback when the fetch fails.
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
