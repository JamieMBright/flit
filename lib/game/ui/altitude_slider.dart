import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// Vertical altitude slider control positioned on screen edge.
/// Controls altitude continuously from low (bottom) to high (top).
/// Maps to zoom levels with smooth transitions - lower is slower.
class AltitudeSlider extends StatefulWidget {
  const AltitudeSlider({
    super.key,
    required this.altitude,
    required this.onAltitudeChanged,
    this.isRightSide = true,
  });

  /// Current altitude value (0.0 = low, 1.0 = high).
  final double altitude;

  /// Callback when altitude changes.
  final ValueChanged<double> onAltitudeChanged;

  /// Whether to position on right side (true) or left side (false).
  final bool isRightSide;

  @override
  State<AltitudeSlider> createState() => _AltitudeSliderState();
}

class _AltitudeSliderState extends State<AltitudeSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sliderHeight = screenHeight * 0.5; // 50% of screen height
    final currentAltitude = _dragValue ?? widget.altitude;

    return Positioned(
      right: widget.isRightSide ? 16 : null,
      left: widget.isRightSide ? null : 16,
      top: (screenHeight - sliderHeight) / 2,
      child: GestureDetector(
        onVerticalDragStart: (details) {
          setState(() {
            _dragValue = currentAltitude;
          });
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            // Convert vertical drag to altitude (inverted: up = higher altitude)
            final newValue = (_dragValue! - details.delta.dy / sliderHeight)
                .clamp(0.0, 1.0);
            _dragValue = newValue;
            widget.onAltitudeChanged(newValue);
          });
        },
        onVerticalDragEnd: (details) {
          setState(() {
            _dragValue = null;
          });
        },
        onTapDown: (details) {
          // Allow tapping anywhere on the track to jump to that altitude
          final localY = details.localPosition.dy;
          final trackHeight = sliderHeight - 40; // Subtract padding
          final newValue = 1.0 - (localY - 20) / trackHeight; // Inverted
          widget.onAltitudeChanged(newValue.clamp(0.0, 1.0));
        },
        child: Container(
          width: 40,
          height: sliderHeight,
          decoration: BoxDecoration(
            color: FlitColors.cardBackground.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FlitColors.cardBorder.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Track gradient (low to high)
              Positioned(
                left: 10,
                right: 10,
                top: 20,
                bottom: 20,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        FlitColors.success.withOpacity(0.3),
                        FlitColors.accent.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              // Low altitude indicator (bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Icon(
                  Icons.flight_land,
                  color: FlitColors.success.withOpacity(0.6),
                  size: 16,
                ),
              ),
              // High altitude indicator (top)
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Icon(
                  Icons.flight_takeoff,
                  color: FlitColors.accent.withOpacity(0.6),
                  size: 16,
                ),
              ),
              // Thumb indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                left: 4,
                right: 4,
                bottom: 20 + (sliderHeight - 40) * (1.0 - currentAltitude) - 16,
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getAltitudeColor(currentAltitude),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FlitColors.cardBorder,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getAltitudeColor(currentAltitude)
                            .withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getAltitudeIcon(currentAltitude),
                      color: FlitColors.textPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAltitudeColor(double altitude) {
    // Interpolate between success (low) and accent (high)
    return Color.lerp(FlitColors.success, FlitColors.accent, altitude)!;
  }

  IconData _getAltitudeIcon(double altitude) {
    if (altitude < 0.33) {
      return Icons.flight_land;
    } else if (altitude < 0.67) {
      return Icons.flight;
    } else {
      return Icons.flight_takeoff;
    }
  }
}
