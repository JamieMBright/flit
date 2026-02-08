import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../clues/clue_types.dart';
import '../flit_game.dart';

/// Game HUD overlay showing clues, timer, altitude indicator, speed controls,
/// and exit button. Styled with a vintage atlas / lo-fi pop art aesthetic.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.isHighAltitude,
    required this.elapsedTime,
    this.currentClue,
    this.onAltitudeToggle,
    this.onExit,
    this.currentSpeed = FlightSpeed.medium,
    this.onSpeedChanged,
    this.onHint,
    this.hintsRemaining = 0,
    this.countryName,
    this.heading,
  });

  final bool isHighAltitude;
  final Duration elapsedTime;
  final Clue? currentClue;
  final VoidCallback? onAltitudeToggle;
  final VoidCallback? onExit;
  final FlightSpeed currentSpeed;
  final ValueChanged<FlightSpeed>? onSpeedChanged;
  final VoidCallback? onHint;
  final int hintsRemaining;
  final String? countryName;
  final double? heading;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: Exit, Clue, Timer
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exit button
                  _ExitButton(onTap: onExit),
                  const SizedBox(width: 8),
                  // Clue display
                  if (currentClue != null)
                    Expanded(
                      child: _ClueCard(clue: currentClue!),
                    ),
                  const SizedBox(width: 12),
                  // Timer
                  _TimerDisplay(elapsed: elapsedTime),
                  // Compass (when heading is available)
                  if (heading != null) ...[
                    const SizedBox(width: 8),
                    _CompassDisplay(heading: heading!),
                  ],
                ],
              ),
              // Country name bar (shown when flying over a country)
              if (countryName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: FlitColors.cardBackground.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: FlitColors.accent.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        countryName!,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              // Bottom row: Speed controls, Altitude indicator, Hint button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hint button
                  if (hintsRemaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _HintButton(
                        remaining: hintsRemaining,
                        onTap: onHint,
                      ),
                    ),
                  // Speed controls
                  _SpeedControls(
                    current: currentSpeed,
                    onChanged: onSpeedChanged,
                  ),
                  const SizedBox(width: 12),
                  // Altitude indicator
                  _AltitudeIndicator(
                    isHigh: isHighAltitude,
                    onToggle: onAltitudeToggle,
                  ),
                ],
              ),
            ],
          ),
        ),
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
          child: const Icon(
            Icons.close,
            color: FlitColors.textSecondary,
            size: 20,
          ),
        ),
      );
}

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.clue});

  final Clue clue;

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
            // Clue type label
            Text(
              _clueTypeLabel(clue.type),
              style: const TextStyle(
                color: FlitColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // Clue content
            if (clue.type == ClueType.flag)
              Text(
                clue.displayData['flagEmoji'] as String,
                style: const TextStyle(fontSize: 48),
              )
            else if (clue.type == ClueType.outline)
              _CountryOutline(
                polygons: clue.displayData['polygons'] as List<List<Vector2>>? ??
                    (clue.displayData['points'] != null
                        ? [(clue.displayData['points'] as List<dynamic>).cast<Vector2>()]
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
    while (bearingDeg < 0) { bearingDeg += 360; }
    while (bearingDeg >= 360) { bearingDeg -= 360; }

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
            angle: -bearingRad, // Negative because we want North to point up when bearing is 0
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

class _AltitudeIndicator extends StatelessWidget {
  const _AltitudeIndicator({
    required this.isHigh,
    this.onToggle,
  });

  final bool isHigh;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHigh ? FlitColors.accent : FlitColors.success,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHigh ? Icons.flight_takeoff : Icons.flight_land,
                color: isHigh ? FlitColors.accent : FlitColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isHigh ? 'TAP TO DESCEND' : 'TAP TO ASCEND',
                style: TextStyle(
                  color: isHigh ? FlitColors.accent : FlitColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
}

class _SpeedControls extends StatelessWidget {
  const _SpeedControls({
    required this.current,
    this.onChanged,
  });

  final FlightSpeed current;
  final ValueChanged<FlightSpeed>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: FlightSpeed.values.map((speed) {
            final isActive = speed == current;
            return GestureDetector(
              onTap: () => onChanged?.call(speed),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? FlitColors.accent.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _speedLabel(speed),
                  style: TextStyle(
                    color: isActive
                        ? FlitColors.accent
                        : FlitColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  String _speedLabel(FlightSpeed speed) {
    switch (speed) {
      case FlightSpeed.slow:
        return 'SLOW';
      case FlightSpeed.medium:
        return 'MED';
      case FlightSpeed.fast:
        return 'FAST';
    }
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.remaining,
    this.onTap,
  });

  final int remaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: FlitColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FlitColors.gold.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: FlitColors.gold,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$remaining',
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: CustomPaint(
        painter: _CountryOutlinePainter(polygons),
      ),
    );
  }
}

class _CountryOutlinePainter extends CustomPainter {
  _CountryOutlinePainter(this.polygons);

  final List<List<Vector2>> polygons;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty || size.isEmpty) return;

    // Find bounding box across ALL polygons
    final firstPt = polygons.first.first;
    var minX = firstPt.x;
    var maxX = firstPt.x;
    var minY = firstPt.y;
    var maxY = firstPt.y;
    for (final poly in polygons) {
      for (final p in poly) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    if (rangeX == 0 || rangeY == 0) return;

    // Scale to fit within the available size with padding
    const padding = 4.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;
    final scale = math.min(drawW / rangeX, drawH / rangeY);
    final offsetX = padding + (drawW - rangeX * scale) / 2;
    final offsetY = padding + (drawH - rangeY * scale) / 2;

    final path = Path();
    for (final poly in polygons) {
      for (var i = 0; i < poly.length; i++) {
        final x = offsetX + (poly[i].x - minX) * scale;
        // Flip Y: higher latitude = higher on screen
        final y = offsetY + (maxY - poly[i].y) * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    // Filled silhouette
    canvas.drawPath(
      path,
      Paint()..color = FlitColors.landMass.withOpacity(0.5),
    );
    // Border stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = FlitColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CountryOutlinePainter oldDelegate) => false;
}

