import 'package:flutter/material.dart';

import '../services/game_settings.dart';
import '../theme/flit_colors.dart';

const _doubleTapWindow = Duration(milliseconds: 280);

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
    this.onDoubleTap,
    this.onDirectionChanged,
    this.visualSize = 96,
    this.travelDistance = 180,
  });

  final ControlMode mode;
  final ValueChanged<double> onSteeringChanged;
  final ValueChanged<double> onThrottleChanged;
  final VoidCallback onReleased;
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
  DateTime? _lastTapAt;

  /// Releases all input and clears pending gesture state.
  void neutralize() {
    _activePointer = null;
    _ignoredPointer = null;
    _initialPosition = null;
    _displacement = Offset.zero;
    _dPadDirection = _DPadDirection.center;
    _dragged = false;
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
    _dPadDirection = widget.mode == ControlMode.dPad
        ? _directionAt(localPosition)
        : _DPadDirection.center;
    _dragged = false;
    widget.onSteeringChanged(0);
    widget.onThrottleChanged(0);
    if (widget.mode == ControlMode.dPad) {
      _applyDPadDirection();
    }
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
        _dPadDirection = nextDirection;
        _applyDPadDirection();
      }
      if (delta.distance > widget.visualSize * 0.08) _dragged = true;
      _displacement = Offset(
        delta.dx.clamp(-widget.visualSize * 0.36, widget.visualSize * 0.36),
        0,
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
    _dragged = delta.dx.abs() > widget.visualSize * 0.05;
    if (horizontal != 0 &&
        (_lastMeaningfulDirection == null ||
            _lastMeaningfulDirection != horizontal.sign.toInt())) {
      _lastMeaningfulDirection = horizontal.sign.toInt();
      widget.onDirectionChanged?.call(_lastMeaningfulDirection!);
    }
    widget.onSteeringChanged(horizontal);
    widget.onThrottleChanged(0);
    _displacement = Offset(
      (delta.dx / widget.travelDistance).clamp(-1.0, 1.0) * _visualTravel,
      0,
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
    _finishPointer();

    if (!wasDragged &&
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
    if (widget.mode == ControlMode.dPad) {
      final horizontalLock = widget.visualSize * 0.11;
      if (delta.dx.abs() <= horizontalLock) return _DPadDirection.center;
      return delta.dx < 0 ? _DPadDirection.left : _DPadDirection.right;
    }
    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx < 0 ? _DPadDirection.left : _DPadDirection.right;
    }
    return _DPadDirection.center;
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

enum _DPadDirection { center, left, right }

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
    final guidePaint = Paint()
      ..color = FlitColors.textSecondary.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      centre.translate(-radius * 0.5, 0),
      centre.translate(radius * 0.5, 0),
      guidePaint,
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
    final clampedValue = value.clamp(0.0, 1.0).toDouble();
    final percentage = (clampedValue * 100).round();
    final increasedValue =
        ((clampedValue + 0.08).clamp(0.0, 1.0).toDouble() * 100).round();
    final decreasedValue =
        ((clampedValue - 0.08).clamp(0.0, 1.0).toDouble() * 100).round();

    void increaseThrottle() {
      if (onIncrement != null) {
        onIncrement!();
        return;
      }
      onChanged((clampedValue + 0.08).clamp(0.0, 1.0).toDouble());
    }

    void decreaseThrottle() {
      if (onDecrement != null) {
        onDecrement!();
        return;
      }
      onChanged((clampedValue - 0.08).clamp(0.0, 1.0).toDouble());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.toDouble()
            : (MediaQuery.sizeOf(context).width * 0.42)
                .clamp(160.0, 260.0)
                .toDouble();
        final idleButton = _ThrottlePresetButton(
          label: 'IDLE',
          active: clampedValue <= 0.05,
          onTap: () => onChanged(0),
        );
        final fullButton = _ThrottlePresetButton(
          label: 'FULL',
          active: clampedValue >= 0.95,
          onTap: () => onChanged(1),
        );

        return SizedBox(
          width: controlWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: FlitColors.cardBorder.withValues(alpha: 0.78),
                ),
                boxShadow: [
                  BoxShadow(
                    color: FlitColors.shadow.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (controlWidth < 150)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THROTTLE',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: FlitColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$percentage%',
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              color: FlitColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text(
                          'THROTTLE',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: FlitColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '$percentage%',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: FlitColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Throttle',
                    value: '$percentage percent',
                    increasedValue: '$increasedValue percent',
                    decreasedValue: '$decreasedValue percent',
                    onIncrease: increaseThrottle,
                    onDecrease: decreaseThrottle,
                    slider: true,
                    excludeSemantics: true,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 12,
                        activeTrackColor: FlitColors.accent,
                        inactiveTrackColor: FlitColors.backgroundMid,
                        thumbColor: FlitColors.goldLight,
                        overlayColor: FlitColors.gold.withValues(alpha: 0.18),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                          pressedElevation: 2,
                        ),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: clampedValue,
                        onChanged: onChanged,
                        semanticFormatterCallback: (next) =>
                            '${(next * 100).round()} percent throttle',
                      ),
                    ),
                  ),
                  if (controlWidth < 190)
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: idleButton,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: fullButton,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        idleButton,
                        const Spacer(),
                        fullButton,
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      },
    );
  }
}

class _ThrottlePresetButton extends StatelessWidget {
  const _ThrottlePresetButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: active,
        label: '$label throttle preset',
        child: ExcludeSemantics(
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: const StadiumBorder(),
              foregroundColor:
                  active ? FlitColors.goldLight : FlitColors.textMuted,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
          ),
        ),
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
