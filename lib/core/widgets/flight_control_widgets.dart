import 'dart:async';

import 'package:flutter/material.dart';

import '../services/game_settings.dart';
import '../theme/flit_colors.dart';

const _doubleTapWindow = Duration(milliseconds: 280);
const _holdDelay = Duration(milliseconds: 160);
const _tapThrottleStep = 0.08;

/// Eased axis response for the compact joystick.
///
/// [travel] is the real pointer travel budget, not the painted base size. The
/// cubic response preserves fine control near centre and reaches full lock
/// only near the configured travel limit.
double joystickAxisResponse(
  double displacement,
  double travel, {
  double deadzone = 0.22,
}) {
  if (travel <= 0) return 0;
  final normalized = (displacement / travel).clamp(-1.0, 1.0);
  final magnitude = normalized.abs();
  if (magnitude <= deadzone) return 0;
  final eased = ((magnitude - deadzone) / (1.0 - deadzone)).clamp(0.0, 1.0);
  return normalized.sign * eased * eased * eased;
}

/// Focused real-time flight control surface.
///
/// The surface owns at most one pointer. A second pointer is ignored here and
/// remains available for independent HUD actions such as the clue button.
class FlightControlSurface extends StatefulWidget {
  const FlightControlSurface({
    super.key,
    required this.mode,
    required this.onSteeringChanged,
    required this.onThrottleChanged,
    required this.onReleased,
    this.onThrottleStep,
    this.onDoubleTap,
    this.onDirectionChanged,
    this.visualSize = 96,
    this.travelDistance = 180,
  });

  final ControlMode mode;
  final ValueChanged<double> onSteeringChanged;
  final ValueChanged<double> onThrottleChanged;
  final VoidCallback onReleased;
  final ValueChanged<double>? onThrottleStep;
  final VoidCallback? onDoubleTap;
  final ValueChanged<int>? onDirectionChanged;
  final double visualSize;

  /// Maximum pointer travel for full-lock response. The widget's painted base
  /// remains compact while this can be derived from safe-area screen width.
  final double travelDistance;

  @override
  FlightControlSurfaceState createState() => FlightControlSurfaceState();
}

class FlightControlSurfaceState extends State<FlightControlSurface> {
  int? _activePointer;
  int? _ignoredPointer;
  Offset? _initialPosition;
  Offset _displacement = Offset.zero;
  _DPadDirection _dPadDirection = _DPadDirection.center;
  bool _dragged = false;
  bool _held = false;
  DateTime? _lastTapAt;
  Timer? _holdTimer;

  /// Releases all input and clears pending gesture state.
  void neutralize() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _ignoredPointer = null;
    _initialPosition = null;
    _displacement = Offset.zero;
    _dPadDirection = _DPadDirection.center;
    _dragged = false;
    _held = false;
    _lastTapAt = null;
    widget.onSteeringChanged(0);
    widget.onThrottleChanged(0);
    widget.onReleased();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(FlightControlSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.travelDistance != widget.travelDistance) {
      neutralize();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null || _ignoredPointer != null) return;

    // A second tap within the scoped control surface requests a clue. The
    // globe is outside this Listener, so it cannot consume the clue gesture.
    if (widget.onDoubleTap != null &&
        _lastTapAt != null &&
        DateTime.now().difference(_lastTapAt!) <= _doubleTapWindow) {
      _ignoredPointer = event.pointer;
      widget.onDoubleTap!();
      _lastTapAt = null;
      return;
    }

    _activePointer = event.pointer;
    final localPosition = _toLocal(event.position);
    _initialPosition = localPosition;
    _displacement = Offset.zero;
    _dPadDirection = _directionAt(localPosition);
    _dragged = false;
    _held = false;
    widget.onSteeringChanged(0);
    widget.onThrottleChanged(0);
    _applyDPadDirection();
    _startHoldTimer();
    if (mounted) setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _initialPosition == null) return;
    final delta = _toLocal(event.position) - _initialPosition!;
    if (widget.mode == ControlMode.joystick) {
      _updateJoystick(delta);
    } else {
      final nextDirection = _directionAt(event.localPosition);
      if (nextDirection != _dPadDirection) {
        _holdTimer?.cancel();
        _held = false;
        _dPadDirection = nextDirection;
        _applyDPadDirection();
        _startHoldTimer();
      }
      if (delta.distance > widget.visualSize * 0.08) _dragged = true;
      _displacement = Offset(
        delta.dx.clamp(-widget.visualSize * 0.36, widget.visualSize * 0.36),
        delta.dy.clamp(-widget.visualSize * 0.36, widget.visualSize * 0.36),
      );
    }
    if (mounted) setState(() {});
  }

  void _updateJoystick(Offset delta) {
    final horizontal = joystickAxisResponse(
      delta.dx,
      widget.travelDistance,
      deadzone: 0.22,
    );
    final vertical = joystickAxisResponse(
      -delta.dy,
      widget.travelDistance,
      deadzone: 0.22,
    );
    _dragged = delta.dx.abs() > widget.visualSize * 0.05 ||
        delta.dy.abs() > widget.visualSize * 0.05;
    if (horizontal != 0 &&
        (_lastMeaningfulDirection == null ||
            _lastMeaningfulDirection != horizontal.sign.toInt())) {
      _lastMeaningfulDirection = horizontal.sign.toInt();
      widget.onDirectionChanged?.call(_lastMeaningfulDirection!);
    }
    widget.onSteeringChanged(horizontal);
    widget.onThrottleChanged(vertical);
    _displacement = Offset(
      (delta.dx / widget.travelDistance).clamp(-1.0, 1.0) * _visualTravel,
      (delta.dy / widget.travelDistance).clamp(-1.0, 1.0) * _visualTravel,
    );
  }

  int? _lastMeaningfulDirection;

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _ignoredPointer) {
      _ignoredPointer = null;
      return;
    }
    if (event.pointer != _activePointer) return;

    final direction = _dPadDirection;
    final wasDragged = _dragged;
    final wasHeld = _held;
    _finishPointer();

    if (widget.mode == ControlMode.dPad &&
        !wasDragged &&
        !wasHeld &&
        (direction == _DPadDirection.up || direction == _DPadDirection.down)) {
      widget.onThrottleStep?.call(
        direction == _DPadDirection.up ? _tapThrottleStep : -_tapThrottleStep,
      );
    } else if (!wasDragged &&
        (direction == _DPadDirection.center ||
            widget.mode == ControlMode.joystick)) {
      _lastTapAt = DateTime.now();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _ignoredPointer) {
      _ignoredPointer = null;
      return;
    }
    if (event.pointer != _activePointer) return;
    _finishPointer();
  }

  void _finishPointer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _initialPosition = null;
    _displacement = Offset.zero;
    _dPadDirection = _DPadDirection.center;
    _lastMeaningfulDirection = null;
    widget.onSteeringChanged(0);
    widget.onThrottleChanged(0);
    widget.onReleased();
    if (mounted) setState(() {});
  }

  void _startHoldTimer() {
    if (widget.mode != ControlMode.dPad ||
        (_dPadDirection != _DPadDirection.up &&
            _dPadDirection != _DPadDirection.down)) {
      return;
    }
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDelay, () {
      if (_activePointer == null) return;
      _held = true;
      _applyDPadDirection();
      if (mounted) setState(() {});
    });
  }

  void _applyDPadDirection() {
    switch (_dPadDirection) {
      case _DPadDirection.left:
        widget.onDirectionChanged?.call(-1);
        widget.onSteeringChanged(-1);
        widget.onThrottleChanged(0);
      case _DPadDirection.right:
        widget.onDirectionChanged?.call(1);
        widget.onSteeringChanged(1);
        widget.onThrottleChanged(0);
      case _DPadDirection.up:
        widget.onSteeringChanged(0);
        widget.onThrottleChanged(_held ? 1 : 0);
      case _DPadDirection.down:
        widget.onSteeringChanged(0);
        widget.onThrottleChanged(_held ? -1 : 0);
      case _DPadDirection.center:
        widget.onSteeringChanged(0);
        widget.onThrottleChanged(0);
    }
  }

  _DPadDirection _directionAt(Offset position) {
    final centre = Offset(widget.visualSize / 2, widget.visualSize / 2);
    final delta = position - centre;
    final distance = delta.distance;
    final centerRadius = widget.visualSize * 0.19;
    if (distance <= centerRadius) return _DPadDirection.center;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx < 0 ? _DPadDirection.left : _DPadDirection.right;
    }
    return delta.dy < 0 ? _DPadDirection.up : _DPadDirection.down;
  }

  double get _visualTravel => widget.visualSize * 0.27;

  Offset _toLocal(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.mode == ControlMode.dPad
          ? 'D-pad flight controls'
          : 'Joystick flight controls',
      child: SizedBox.square(
        dimension: widget.visualSize,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: CustomPaint(
            painter: _FlightControlPainter(
              mode: widget.mode,
              horizontal: _displacement.dx / _visualTravel,
              vertical: -_displacement.dy / _visualTravel,
              active: _activePointer != null,
            ),
          ),
        ),
      ),
    );
  }
}

enum _DPadDirection { center, left, right, up, down }

class _FlightControlPainter extends CustomPainter {
  const _FlightControlPainter({
    required this.mode,
    required this.horizontal,
    required this.vertical,
    required this.active,
  });

  final ControlMode mode;
  final double horizontal;
  final double vertical;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == ControlMode.dPad) {
      _paintDPad(canvas, size);
    } else {
      _paintJoystick(canvas, size);
    }
  }

  void _paintJoystick(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final basePaint = Paint()
      ..color =
          FlitColors.cardBackground.withValues(alpha: active ? 0.76 : 0.52)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centre, radius, basePaint);
    final borderPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: active ? 0.9 : 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(centre, radius, borderPaint);

    final knob = Offset(
      centre.dx + horizontal.clamp(-1.0, 1.0) * radius * 0.62,
      centre.dy - vertical.clamp(-1.0, 1.0) * radius * 0.62,
    );
    final knobPaint = Paint()
      ..color = FlitColors.accent.withValues(alpha: active ? 0.98 : 0.88);
    canvas.drawCircle(knob, radius * 0.22, knobPaint);
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawCircle(
      knob.translate(-radius * 0.055, -radius * 0.055),
      radius * 0.07,
      highlightPaint,
    );
  }

  void _paintDPad(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final panel = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(18),
    );
    final fill = Paint()
      ..color =
          FlitColors.cardBackground.withValues(alpha: active ? 0.8 : 0.58);
    canvas.drawRRect(panel, fill);
    final border = Paint()
      ..color = FlitColors.accent.withValues(alpha: active ? 0.9 : 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(panel, border);

    final centre = Offset(size.width / 2, size.height / 2);
    final linePaint = Paint()
      ..color = FlitColors.textSecondary.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawChevron(
        canvas, centre.translate(-size.width * 0.29, 0), -1, linePaint);
    _drawChevron(canvas, centre.translate(size.width * 0.29, 0), 1, linePaint);
    _drawVerticalChevron(
      canvas,
      centre.translate(0, -size.height * 0.29),
      -1,
      linePaint,
    );
    _drawVerticalChevron(
      canvas,
      centre.translate(0, size.height * 0.29),
      1,
      linePaint,
    );
    canvas.drawCircle(
      centre,
      size.shortestSide * 0.11,
      Paint()..color = FlitColors.gold.withValues(alpha: active ? 0.9 : 0.62),
    );
  }

  void _drawChevron(Canvas canvas, Offset centre, int direction, Paint paint) {
    final path = Path();
    final x = centre.dx + direction * 5;
    path.moveTo(x, centre.dy - 7);
    path.lineTo(centre.dx - direction * 4, centre.dy);
    path.lineTo(x, centre.dy + 7);
    canvas.drawPath(path, paint);
  }

  void _drawVerticalChevron(
    Canvas canvas,
    Offset centre,
    int direction,
    Paint paint,
  ) {
    final path = Path();
    final y = centre.dy + direction * 5;
    path.moveTo(centre.dx - 7, y);
    path.lineTo(centre.dx, centre.dy - direction * 4);
    path.lineTo(centre.dx + 7, y);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FlightControlPainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.vertical != vertical ||
      oldDelegate.active != active;
}

/// Compact continuous throttle control for Classic mode.
class ClassicThrottleControl extends StatelessWidget {
  const ClassicThrottleControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.onIncrement,
    this.onDecrement,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Throttle ${((value.clamp(0.0, 1.0)) * 100).round()} percent',
      child: Container(
        width: 132,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: FlitColors.cardBorder.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            _ThrottleButton(
              icon: Icons.remove,
              onTap: onDecrement,
              tooltip: 'Decrease throttle',
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: FlitColors.accent,
                  inactiveTrackColor: FlitColors.backgroundMid,
                  thumbColor: FlitColors.accent,
                  overlayColor: FlitColors.accent.withValues(alpha: 0.14),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: onChanged,
                  semanticFormatterCallback: (v) =>
                      '${(v * 100).round()} percent throttle',
                ),
              ),
            ),
            _ThrottleButton(
              icon: Icons.add,
              onTap: onIncrement,
              tooltip: 'Increase throttle',
            ),
          ],
        ),
      ),
    );
  }
}

class _ThrottleButton extends StatelessWidget {
  const _ThrottleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18),
        color: FlitColors.textSecondary,
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
        padding: EdgeInsets.zero,
      );
}

/// Read-only throttle gauge for compact control modes.
class ThrottleGauge extends StatelessWidget {
  const ThrottleGauge({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final percentage = (value.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      label: 'Throttle $percentage percent',
      value: '$percentage percent',
      child: Container(
        width: 72,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: FlitColors.cardBorder.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.speed, size: 13, color: FlitColors.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: FlitColors.backgroundMid,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(FlitColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared curve retained for older widget-level tests and callers.
double joystickTurnStrength(double displacement, double radius) =>
    joystickAxisResponse(displacement, radius, deadzone: 0.16);
