import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/widgets/country_flag.dart';
import '../../core/widgets/country_outline_painter.dart';
import '../../core/widgets/flight_control_widgets.dart';
import '../clues/clue_types.dart';
import '../session/game_session.dart';

/// Game HUD overlay showing clues, timer, throttle controls,
/// and exit button. Styled with a vintage atlas / lo-fi pop art aesthetic.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.elapsedTime,
    this.currentClue,
    this.onExit,
    this.onSettings,
    this.controlMode = ControlMode.classic,
    this.controlPlacement = ControlPlacement.lowerCenter,
    this.clueTrigger = ClueTrigger.button,
    this.throttle = 0.0,
    this.compactControlSurface,
    this.onThrottleChanged,
    this.onThrottleIncrement,
    this.onThrottleDecrement,
    this.onHint,
    this.hintTier = 0,
    this.revealedCountry,
    this.countryName,
    this.heading,
    this.countryFlashProgress = 0.0,
    this.currentRound,
    this.totalRounds,
    this.fuelLevel,
    this.maxFuel = 1.0,
    this.onSkipClue,
  });

  final Duration elapsedTime;
  final Clue? currentClue;
  final VoidCallback? onExit;
  final VoidCallback? onSettings;
  final ControlMode controlMode;
  final ControlPlacement controlPlacement;
  final ClueTrigger clueTrigger;
  final double throttle;
  final Widget? compactControlSurface;
  final ValueChanged<double>? onThrottleChanged;
  final VoidCallback? onThrottleIncrement;
  final VoidCallback? onThrottleDecrement;
  final VoidCallback? onHint;
  final int hintTier;
  final String? revealedCountry;
  final String? countryName;
  final double? heading;
  final double countryFlashProgress;
  final int? currentRound;
  final int? totalRounds;

  /// Current fuel level (0.0–[maxFuel]). When null, fuel gauge is hidden.
  final double? fuelLevel;

  /// Maximum fuel (licence-boosted). 1.0 = no bonus, 1.1 = 10% bonus.
  final double maxFuel;

  /// Callback to skip to next clue (free flight only). When null, skip button is hidden.
  final VoidCallback? onSkipClue;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: [Exit/Settings] [Clue] [Timer/Compass/Round]
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: Exit and Settings stacked
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ExitButton(onTap: onExit),
                      const SizedBox(height: 6),
                      _GearButton(onTap: onSettings),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Center: Clue display (expanded to fill available space)
                  if (currentClue != null)
                    Expanded(
                      child:
                          _ClueCard(clue: currentClue!, onSkipClue: onSkipClue),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  // Right column: Timer, Compass, Round indicator
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _TimerDisplay(elapsed: elapsedTime),
                      if (heading != null) ...[
                        const SizedBox(height: 6),
                        _CompassDisplay(heading: heading!),
                      ],
                      if (currentRound != null &&
                          (totalRounds == null || totalRounds! > 1)) ...[
                        const SizedBox(height: 6),
                        _RoundIndicator(
                            current: currentRound!, total: totalRounds),
                      ],
                    ],
                  ),
                ],
              ),
              // Revealed country name (shown after tier 2 hint)
              if (revealedCountry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: FlitColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: FlitColors.gold.withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎯 ', style: TextStyle(fontSize: 16)),
                          Text(
                            revealedCountry!,
                            style: const TextStyle(
                              color: FlitColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Country name bar (shown when flying over a country)
              if (countryName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _CountryNameBar(
                      name: countryName!,
                      flashProgress: countryFlashProgress,
                    ),
                  ),
                ),
              const Spacer(),
              // Fuel gauge (shown only when fuel is active)
              if (fuelLevel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FuelGauge(level: fuelLevel!, maxFuel: maxFuel),
                ),
              if (controlMode == ControlMode.classic)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (hintTier < 4 && onHint != null)
                      _HintButton(tier: hintTier, onTap: onHint),
                    Flexible(
                      child: ClassicThrottleControl(
                        value: throttle,
                        onChanged: onThrottleChanged ?? (_) {},
                        onIncrement: onThrottleIncrement,
                        onDecrement: onThrottleDecrement,
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: _compactAlignment,
                    child: _CompactControlCluster(
                      placement: controlPlacement,
                      clueTrigger: clueTrigger,
                      hintTier: hintTier,
                      throttle: throttle,
                      onThrottleChanged: onThrottleChanged,
                      onThrottleIncrement: onThrottleIncrement,
                      onThrottleDecrement: onThrottleDecrement,
                      onHint: onHint,
                      surface: compactControlSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Alignment get _compactAlignment {
    switch (controlPlacement) {
      case ControlPlacement.left:
        return Alignment.centerLeft;
      case ControlPlacement.right:
        return Alignment.centerRight;
      case ControlPlacement.lowerCenter:
      case ControlPlacement.sliderLeft:
      case ControlPlacement.sliderAbove:
        return Alignment.center;
    }
  }
}

class _CompactControlCluster extends StatelessWidget {
  const _CompactControlCluster({
    required this.placement,
    required this.clueTrigger,
    required this.hintTier,
    required this.throttle,
    required this.onThrottleChanged,
    required this.onThrottleIncrement,
    required this.onThrottleDecrement,
    required this.onHint,
    this.surface,
  });

  final ControlPlacement placement;
  final ClueTrigger clueTrigger;
  final int hintTier;
  final double throttle;
  final ValueChanged<double>? onThrottleChanged;
  final VoidCallback? onThrottleIncrement;
  final VoidCallback? onThrottleDecrement;
  final VoidCallback? onHint;
  final Widget? surface;

  bool get _showHint =>
      clueTrigger == ClueTrigger.button && hintTier < 4 && onHint != null;

  @override
  Widget build(BuildContext context) {
    final throttleControl = ClassicThrottleControl(
      value: throttle,
      onChanged: onThrottleChanged ?? (_) {},
      onIncrement: onThrottleIncrement,
      onDecrement: onThrottleDecrement,
    );
    final surfaceWidget = surface ?? const SizedBox.shrink();
    final hint = _showHint
        ? _HintButton(tier: hintTier, onTap: onHint)
        : const SizedBox.shrink();

    switch (placement) {
      case ControlPlacement.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            surfaceWidget,
            const SizedBox(width: 12),
            _CompactThrottleColumn(
              throttleControl: throttleControl,
              throttle: throttle,
              hint: hint,
              showHint: _showHint,
              alignEnd: false,
            ),
          ],
        );
      case ControlPlacement.right:
      case ControlPlacement.sliderLeft:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CompactThrottleColumn(
              throttleControl: throttleControl,
              throttle: throttle,
              hint: hint,
              showHint: _showHint,
              alignEnd: true,
            ),
            const SizedBox(width: 12),
            surfaceWidget,
          ],
        );
      case ControlPlacement.lowerCenter:
      case ControlPlacement.sliderAbove:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                throttleControl,
                if (_showHint) ...[
                  const SizedBox(width: 10),
                  hint,
                ],
              ],
            ),
            const SizedBox(height: 10),
            surfaceWidget,
          ],
        );
    }
  }
}

class _CompactThrottleColumn extends StatelessWidget {
  const _CompactThrottleColumn({
    required this.throttleControl,
    required this.throttle,
    required this.hint,
    required this.showHint,
    required this.alignEnd,
  });

  final Widget throttleControl;
  final double throttle;
  final Widget hint;
  final bool showHint;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          throttleControl,
          const SizedBox(height: 8),
          ThrottleGauge(value: throttle),
          if (showHint) ...[
            const SizedBox(height: 8),
            hint,
          ],
        ],
      );
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
          ),
          child: const Icon(Icons.close,
              color: FlitColors.textSecondary, size: 20),
        ),
      );
}

class _GearButton extends StatelessWidget {
  const _GearButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
          ),
          child: const Icon(
            Icons.settings,
            color: FlitColors.textSecondary,
            size: 20,
          ),
        ),
      );
}

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.clue, this.onSkipClue});

  final Clue clue;

  /// Callback to skip to next clue (free flight only). When null, skip button
  /// is hidden.
  final VoidCallback? onSkipClue;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clue type label + skip button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _clueTypeLabel(clue.type),
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                if (onSkipClue != null) _SkipClueButton(onTap: onSkipClue),
              ],
            ),
            const SizedBox(height: 4),
            // Clue content
            if (clue.type == ClueType.flag)
              CountryFlag(
                code: clue.targetCountryCode,
                height: 56,
                width: 84,
                borderRadius: 4,
              )
            else if (clue.type == ClueType.outline)
              _CountryOutline(
                polygons:
                    clue.displayData['polygons'] as List<List<Vector2>>? ??
                        (clue.displayData['points'] != null
                            ? [
                                (clue.displayData['points'] as List<dynamic>)
                                    .cast<Vector2>(),
                              ]
                            : <List<Vector2>>[]),
              )
            else
              Text(
                clue.displayText,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
          ],
        ),
      );

  String _clueTypeLabel(ClueType type) {
    switch (type) {
      case ClueType.flag:
        return 'FLAG';
      case ClueType.outline:
        return 'OUTLINE';
      case ClueType.borders:
        return 'BORDERS';
      case ClueType.capital:
        return 'CAPITAL';
      case ClueType.stats:
        return 'STATS';
      case ClueType.sportsTeam:
        return 'SPORTS';
      case ClueType.leader:
        return 'LEADER';
      case ClueType.nickname:
        return 'NICKNAME';
      case ClueType.landmark:
        return 'LANDMARK';
      case ClueType.flagDescription:
        return 'FLAG';
    }
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final millis = (elapsed.inMilliseconds % 1000) ~/ 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _CompassDisplay extends StatelessWidget {
  const _CompassDisplay({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    // Convert from math convention (0=east, -π/2=north) to navigation bearing (0=north)
    // Navigation bearing: heading + π/2, then convert to degrees
    final bearingRad = heading + math.pi / 2;
    var bearingDeg = bearingRad * 180 / math.pi;

    // Normalize to [0, 360)
    while (bearingDeg < 0) {
      bearingDeg += 360;
    }
    while (bearingDeg >= 360) {
      bearingDeg -= 360;
    }

    // Get cardinal direction
    final direction = _getCardinalDirection(bearingDeg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compass icon with rotation
          Transform.rotate(
            angle:
                -bearingRad, // Negative because we want North to point up when bearing is 0
            child: const Icon(
              Icons.navigation,
              color: FlitColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 6),
          // Cardinal direction text
          Text(
            direction,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _getCardinalDirection(double degrees) {
    // 8-point compass rose
    if (degrees >= 337.5 || degrees < 22.5) return 'N';
    if (degrees >= 22.5 && degrees < 67.5) return 'NE';
    if (degrees >= 67.5 && degrees < 112.5) return 'E';
    if (degrees >= 112.5 && degrees < 157.5) return 'SE';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'SW';
    if (degrees >= 247.5 && degrees < 292.5) return 'W';
    if (degrees >= 292.5 && degrees < 337.5) return 'NW';
    return 'N'; // fallback
  }
}

class _RoundIndicator extends StatelessWidget {
  const _RoundIndicator({required this.current, this.total});

  final int current;
  final int? total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FlitColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.accent.withOpacity(0.5)),
        ),
        child: Text(
          total != null ? '$current/$total' : '#$current',
          style: const TextStyle(
            color: FlitColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// Country name bar with flash animation when entering a new country.
class _CountryNameBar extends StatelessWidget {
  const _CountryNameBar({required this.name, required this.flashProgress});

  final String name;
  final double flashProgress;

  @override
  Widget build(BuildContext context) {
    // Flash animation: scale from 1.0 to 1.15 and back
    final scale = 1.0 + (flashProgress * 0.15);

    // Flash animation: border opacity from 0.3 to 1.0
    final borderOpacity = 0.3 + (flashProgress * 0.7);

    // Flash animation: background glow
    final glowOpacity = flashProgress * 0.5;

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withOpacity(
            0.75 + glowOpacity * 0.25,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FlitColors.accent.withOpacity(borderOpacity),
            width: 1 + (flashProgress * 1.5),
          ),
          boxShadow: flashProgress > 0
              ? [
                  BoxShadow(
                    color: FlitColors.accent.withOpacity(glowOpacity * 0.8),
                    blurRadius: 8 + (flashProgress * 12),
                    spreadRadius: flashProgress * 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          name,
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 12 + (flashProgress * 2),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5 + (flashProgress * 0.5),
          ),
        ),
      ),
    );
  }
}

class _HintButton extends StatefulWidget {
  const _HintButton({required this.tier, this.onTap});

  final int tier;
  final VoidCallback? onTap;

  /// Sourced from GameSession.hintTierPenalties — single source of truth.
  static List<int> get tierPenalties => GameSession.hintTierPenalties;

  @override
  State<_HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<_HintButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int? _lastPenalty;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    final tier = widget.tier.clamp(0, _HintButton.tierPenalties.length - 1);
    _lastPenalty = _HintButton.tierPenalties[tier];
    _anim.forward(from: 0);
    widget.onTap!();
  }

  /// Yellow (low penalty) → red (high penalty).
  Color _penaltyColor(int penalty) {
    final t = ((penalty - 500) / 2000).clamp(0.0, 1.0);
    return Color.lerp(FlitColors.gold, const Color(0xFFE53935), t)!;
  }

  @override
  Widget build(BuildContext context) {
    final IconData iconData;
    final String label;
    switch (widget.tier) {
      case 0:
        iconData = Icons.lightbulb_outline;
        label = 'NEW CLUE';
        break;
      case 1:
        iconData = Icons.public;
        label = 'REVEAL';
        break;
      case 2:
        iconData = Icons.explore;
        label = 'WAYLINE';
        break;
      case 3:
        iconData = Icons.near_me;
        label = 'NAVIGATE';
        break;
      default:
        iconData = Icons.check;
        label = 'DONE';
        break;
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: FlitColors.gold.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: FlitColors.gold.withOpacity(0.9),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 16, color: FlitColors.gold),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Floating penalty text
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              if (!_anim.isAnimating) {
                return const SizedBox.shrink();
              }
              final penalty = _lastPenalty ?? 500;
              final t = _anim.value;
              // Ease-out float: fast start, slow finish
              final offset = -30.0 * Curves.easeOut.transform(t);
              // Fade out in the second half
              final opacity = t < 0.5 ? 1.0 : (1.0 - (t - 0.5) * 2.0);
              return Positioned(
                top: offset - 20,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Text(
                      '-${penalty}pts',
                      style: TextStyle(
                        color: _penaltyColor(penalty),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact skip-clue pill button shown inside the clue card (free flight only).
class _SkipClueButton extends StatelessWidget {
  const _SkipClueButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: FlitColors.gold.withOpacity(0.55),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: FlitColors.gold.withOpacity(0.9), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, color: FlitColors.gold, size: 12),
              SizedBox(width: 2),
              Text(
                'SKIP',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Mini country outline silhouette rendered from multi-polygon data.
class _CountryOutline extends StatelessWidget {
  const _CountryOutline({required this.polygons});

  final List<List<Vector2>> polygons;

  @override
  Widget build(BuildContext context) {
    if (polygons.isEmpty) {
      return const Text('🗺️', style: TextStyle(fontSize: 48));
    }
    // Shared painter: its shouldRepaint compares polygon data, so the
    // silhouette updates when the clue changes (the old private copy
    // returned false unconditionally and could show a stale country).
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: CustomPaint(
        painter: CountryOutlinePainter(
          polygons,
          fillColor: FlitColors.landMass.withOpacity(0.5),
          strokeColor: FlitColors.accent,
          strokeWidth: 1.5,
          padding: 4.0,
        ),
      ),
    );
  }
}

/// Horizontal fuel gauge bar displayed above the bottom controls.
///
/// Shows fuel as a percentage of the base tank (100%). When the pilot licence
/// provides a fuel boost, the gauge displays above 100% (e.g. "110%") and the
/// bar fills past the 100% mark. Color smoothly transitions from green through
/// amber to red as fuel depletes.
class _FuelGauge extends StatelessWidget {
  const _FuelGauge({required this.level, this.maxFuel = 1.0});

  /// Current fuel level (0.0–[maxFuel]).
  final double level;

  /// Maximum fuel. >1.0 when licence-boosted.
  final double maxFuel;

  /// Smooth green → amber → red color based on fuel proportion.
  Color _fuelColor(double proportion) {
    // proportion: 0.0 (empty) to 1.0 (full of maxFuel).
    if (proportion > 0.5) {
      // Green → Amber (1.0→0.5 maps to pure green → amber).
      final t = ((proportion - 0.5) / 0.5).clamp(0.0, 1.0);
      return Color.lerp(FlitColors.warning, FlitColors.success, t)!;
    } else {
      // Amber → Red (0.5→0.0 maps to amber → red).
      final t = (proportion / 0.5).clamp(0.0, 1.0);
      return Color.lerp(FlitColors.error, FlitColors.warning, t)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final proportion = maxFuel > 0 ? (level / maxFuel).clamp(0.0, 1.0) : 0.0;
    final barColor = _fuelColor(proportion);
    final percentage = (level * 100).round();
    final hasBoost = maxFuel > 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station, color: barColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: proportion,
                backgroundColor: FlitColors.backgroundMid,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: hasBoost ? 48 : 36,
            child: Text(
              '$percentage%',
              style: TextStyle(
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Licence boost badge
          if (hasBoost) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.shield,
              color: FlitColors.gold.withOpacity(0.7),
              size: 12,
            ),
          ],
        ],
      ),
    );
  }
}
