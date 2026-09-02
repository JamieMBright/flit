import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';

/// Converts a horizontal joystick displacement into a signed turn strength.
///
/// A small deadzone prevents accidental drift. The quadratic curve keeps
/// corrections gentle near the centre and reaches full lock at the edge.
double joystickTurnStrength(double displacement, double radius) {
  if (radius <= 0) return 0;
  final normalized = (displacement / radius).clamp(-1.0, 1.0);
  final magnitude = normalized.abs();
  const deadzone = 0.08;
  if (magnitude <= deadzone) return 0;
  final curvedMagnitude = ((magnitude - deadzone) / (1 - deadzone));
  return normalized.sign * curvedMagnitude * curvedMagnitude;
}

/// Central thumb control for continuous left/right steering.
class JoystickWidget extends StatefulWidget {
  const JoystickWidget({
    super.key,
    required this.onChanged,
    required this.onReleased,
    this.onEngaged,
    this.size = 112,
  });

  final ValueChanged<double> onChanged;
  final VoidCallback onReleased;
  final VoidCallback? onEngaged;
  final double size;

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  int? _pointer;
  double _displacement = 0;
  bool _engagementReported = false;

  double get _radius => widget.size / 2;
  double get _knobRadius => widget.size * 0.19;
  double get _travelRadius => _radius - _knobRadius;

  void _begin(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _engagementReported = false;
    _updateFromLocalPosition(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _updateFromLocalPosition(event.localPosition);
  }

  void _updateFromLocalPosition(Offset position) {
    final displacement =
        (position.dx - _radius).clamp(-_travelRadius, _travelRadius);
    final strength = joystickTurnStrength(displacement, _travelRadius);
    if (!_engagementReported && strength.abs() > 0) {
      _engagementReported = true;
      widget.onEngaged?.call();
    }
    setState(() => _displacement = displacement);
    widget.onChanged(strength);
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _engagementReported = false;
    setState(() => _displacement = 0);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _begin,
        onPointerMove: _move,
        onPointerUp: (event) => _end(event.pointer),
        onPointerCancel: (event) => _end(event.pointer),
        child: CustomPaint(
          painter: _JoystickPainter(
            displacement: _displacement,
            radius: _radius,
            knobRadius: _knobRadius,
            active: _pointer != null,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({
    required this.displacement,
    required this.radius,
    required this.knobRadius,
    required this.active,
  });

  final double displacement;
  final double radius;
  final double knobRadius;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..color =
          FlitColors.cardBackground.withValues(alpha: active ? 0.72 : 0.48)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centre, radius - 2, basePaint);

    final borderPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: active ? 0.8 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(centre, radius - 2, borderPaint);

    final knobCentre = centre.translate(displacement, 0);
    final knobPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: active ? 0.98 : 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCentre, knobRadius, knobPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      knobCentre.translate(-knobRadius * 0.25, -knobRadius * 0.25),
      knobRadius * 0.32,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) =>
      oldDelegate.displacement != displacement || oldDelegate.active != active;
}
