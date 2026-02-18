import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import 'avatar_compositor.dart';

/// Renders a DiceBear avatar as an SVG — fully offline.
///
/// All 10 styles are composited from local SVG parts stored as compile-time
/// Dart constants. No network calls, no loading state, instant render.
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
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  /// Cached composed SVG string for the current config.
  String? _composedSvg;

  /// Whether local SVG composition failed and network fetch is needed.
  bool _composeFailed = false;

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
        });
      }
    } catch (e) {
      debugPrint('Avatar network fetch error: $e');
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svg = AvatarCompositor.compose(config);

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
          child: svg != null
              ? SvgPicture.string(
                  svg,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
              : _AvatarFallback(size: size),
        ),
      ),
    );
  }
}

/// Renders an avatar from a DiceBear SVG URL string.
///
/// For models that only carry an [avatarUrl] (e.g. [Friend],
/// [LeaderboardEntry]) instead of a full [AvatarConfig].
///
/// When an [avatarConfig] is provided, composes offline and ignores the URL.
/// Otherwise shows a [name]-initial placeholder (no network fetch).
class AvatarFromUrl extends StatelessWidget {
  const AvatarFromUrl({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.avatarConfig,
    this.size = 48,
  });

  /// DiceBear SVG URL (unused when [avatarConfig] is provided).
  final String? avatarUrl;

  /// Display name used for the initial-letter fallback.
  final String name;

  /// Optional config for fully offline composition.
  final AvatarConfig? avatarConfig;

  final double size;

  @override
  Widget build(BuildContext context) {
    // If we have a config, compose offline.
    if (avatarConfig != null) {
      return AvatarWidget(config: avatarConfig!, size: size);
  @override
  State<AvatarFromUrl> createState() => _AvatarFromUrlState();
}

class _AvatarFromUrlState extends State<AvatarFromUrl> {
  String? _svg;

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
      return;
    }

    // Check cache.
    final cached = _svgCache[url];
    if (cached != null) {
      setState(() {
        _svg = cached;
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
        });
      }
    } catch (_) {
      // Silently fail and show fallback
    }

    // Fallback: show initial letter.
    final fallbackLetter =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hash = name.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final bgColor = HSLColor.fromAHSL(1.0, hue, 0.5, 0.35).toColor();

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              fallbackLetter,
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback shown when avatar composition fails.
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
