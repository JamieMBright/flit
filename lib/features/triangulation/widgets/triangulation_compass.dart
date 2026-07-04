import 'dart:math' as math;

import 'package:flag/flag.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/flit_colors.dart';
import '../../../core/widgets/country_outline_painter.dart';
import '../../../game/clues/clue_types.dart';
import '../../../game/map/country_data.dart';
import '../../../game/triangulation/triangulation_session.dart';
import '../../../game/triangulation/triangulation_target.dart';
import 'compass_painter.dart';

/// The Triangulation compass: mystery circle in the centre, one arrow per
/// clue location at its true bearing from the hidden capital, and a dashed
/// red arrow per wrong guess. Each arrow tip carries an info box holding
/// all enabled clue visuals and labels for that location.
///
/// Sized by its parent; always renders square via [AspectRatio]. All
/// placement is fractional (no absolute positioning) so it scales across
/// phone/tablet/web.
class TriangulationCompass extends StatelessWidget {
  const TriangulationCompass({
    super.key,
    required this.clues,
    required this.wrongGuesses,
    required this.clueTypes,
    required this.labelTypes,
    this.centerLabel = 'CAPITAL',
  });

  final List<TriangulationClue> clues;
  final List<TriangulationGuess> wrongGuesses;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;
  final String centerLabel;

  static const double _circleFraction = 0.15;
  static const double _arrowEndFraction = 0.30;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final center = Offset(side / 2, side / 2);

          final markers = <_MarkerLayout>[
            for (final clue in clues)
              _MarkerLayout(
                bearingDeg: clue.bearingFromTargetDeg,
                isGuess: false,
                clue: clue,
              ),
            for (final guess in wrongGuesses)
              _MarkerLayout(
                bearingDeg: guess.bearingFromTargetDeg,
                isGuess: true,
                guess: guess,
              ),
          ];
          _relaxAngles(markers);

          final boxWidth = (side * 0.24).clamp(72.0, 116.0);
          // Anchor boxes past the arrow tips but inside the square.
          final boxRadius = math.min(
            side * (_arrowEndFraction + 0.11),
            side / 2 - boxWidth * 0.35,
          );
          // Neighbours still crowded after angular relaxation alternate
          // onto an inner ring (just clear of the rose) so their boxes
          // stack radially, not on top of each other.
          final innerBoxRadius = side * (_circleFraction + 0.135);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CompassPainter(
                    clueBearingsDeg: [
                      for (final m in markers)
                        if (!m.isGuess) m.bearingDeg,
                    ],
                    guessBearingsDeg: [
                      for (final m in markers)
                        if (m.isGuess) m.bearingDeg,
                    ],
                    circleRadiusFraction: _circleFraction,
                    arrowEndFraction: _arrowEndFraction,
                  ),
                ),
              ),
              // Mystery label in the centre circle.
              Positioned(
                left: center.dx - side * _circleFraction,
                top: center.dy - side * _circleFraction,
                width: side * _circleFraction * 2,
                height: side * _circleFraction * 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      centerLabel,
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: (side * 0.028).clamp(9.0, 13.0),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '?',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: (side * 0.075).clamp(20.0, 34.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              for (final marker in markers)
                _positionedBox(
                  marker,
                  center,
                  marker.ring == 0 ? boxRadius : innerBoxRadius,
                  boxWidth,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedBox(
    _MarkerLayout marker,
    Offset center,
    double radius,
    double boxWidth,
  ) {
    // Boxes sit at the (possibly relaxed) display angle; the arrow itself
    // always points at the true bearing.
    final dir = bearingToDirection(marker.displayAngleDeg);
    final anchor = center + dir * radius;
    return Positioned(
      left: anchor.dx - boxWidth / 2,
      top: anchor.dy,
      width: boxWidth,
      // Centre the box on its anchor regardless of its intrinsic height.
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: marker.isGuess
            ? _GuessInfoBox(guess: marker.guess!)
            : _ClueInfoBox(
                clue: marker.clue!,
                clueTypes: clueTypes,
                labelTypes: labelTypes,
              ),
      ),
    );
  }

  /// Spreads markers apart so info boxes don't overlap: iteratively pushes
  /// neighbours to a minimum angular separation. Only the box display
  /// angles move (capped at ±10° so each box stays attached to its arrow
  /// tip); the arrows themselves always point at the true bearing.
  static void _relaxAngles(List<_MarkerLayout> markers) {
    if (markers.length < 2) return;
    // Minimum separation shrinks as the compass gets crowded.
    final minGap = math.min(40.0, 320.0 / markers.length);
    const maxShift = 10.0; // never move an arrow more than this off-true
    markers.sort((a, b) => a.displayAngleDeg.compareTo(b.displayAngleDeg));
    for (var pass = 0; pass < 6; pass++) {
      var moved = false;
      for (var i = 0; i < markers.length; i++) {
        final a = markers[i];
        final b = markers[(i + 1) % markers.length];
        var gap = b.displayAngleDeg - a.displayAngleDeg;
        if (i == markers.length - 1) gap += 360;
        if (gap < minGap) {
          final push = (minGap - gap) / 2;
          a.displayAngleDeg =
              _clampShift(a.bearingDeg, a.displayAngleDeg - push, maxShift);
          b.displayAngleDeg =
              _clampShift(b.bearingDeg, b.displayAngleDeg + push, maxShift);
          moved = true;
        }
      }
      if (!moved) break;
    }
    // Any pair still closer than the minimum gap after relaxation gets
    // staggered across two rings so the boxes never fully stack.
    for (var i = 1; i < markers.length; i++) {
      final gap = markers[i].displayAngleDeg - markers[i - 1].displayAngleDeg;
      if (gap < minGap * 0.9) {
        markers[i].ring = markers[i - 1].ring == 0 ? 1 : 0;
      }
    }
  }

  static double _clampShift(double trueDeg, double proposed, double max) {
    var delta = proposed - trueDeg;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    return trueDeg + delta.clamp(-max, max);
  }
}

class _MarkerLayout {
  _MarkerLayout({
    required this.bearingDeg,
    required this.isGuess,
    this.clue,
    this.guess,
  }) : displayAngleDeg = bearingDeg;

  final double bearingDeg;
  final bool isGuess;
  final TriangulationClue? clue;
  final TriangulationGuess? guess;
  double displayAngleDeg;

  /// 0 = outer ring (default), 1 = inner ring for crowded neighbours.
  int ring = 0;
}

/// Info box for a starting clue: stacks every enabled visual and label.
class _ClueInfoBox extends StatelessWidget {
  const _ClueInfoBox({
    required this.clue,
    required this.clueTypes,
    required this.labelTypes,
  });

  final TriangulationClue clue;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;

  @override
  Widget build(BuildContext context) {
    final visuals = <Widget>[];
    if (clueTypes.contains(ClueType.flag)) {
      visuals.add(_MarkerFlag(code: clue.countryCode));
    }
    if (clueTypes.contains(ClueType.outline)) {
      final polygons =
          CountryData.getCountry(clue.countryCode)?.polygons ?? const [];
      visuals.add(
        SizedBox(
          width: 40,
          height: 30,
          child: CustomPaint(
            painter: CountryOutlinePainter(
              polygons,
              fillColor: FlitColors.landMass.withOpacity(0.5),
              strokeColor: FlitColors.textPrimary,
            ),
          ),
        ),
      );
    }

    final lines = <String>[];
    for (final label in TriLabel.values) {
      if (!labelTypes.contains(label)) continue;
      final text = clue.labelText(label);
      if (text != null) lines.add(text);
    }
    // ClueType.capital shows the capital name even when the capital label
    // isn't separately enabled.
    if (clueTypes.contains(ClueType.capital) &&
        !labelTypes.contains(TriLabel.capital)) {
      lines.add(clue.capitalName);
    }
    if (clueTypes.contains(ClueType.borders)) {
      final neighbors = Clue.getNeighbors(clue.countryCode);
      if (neighbors.isNotEmpty) {
        final shown = neighbors.take(3).join(', ');
        lines.add(
          neighbors.length > 3 ? 'Borders: $shown…' : 'Borders: $shown',
        );
      }
    }

    return _InfoBoxFrame(
      borderColor: FlitColors.cardBorder,
      textColor: FlitColors.textPrimary,
      visuals: visuals,
      lines: lines,
    );
  }
}

/// Info box for a wrong guess: red-tinted, flag + guessed name only (no
/// distance — bearing plus distance would give the answer away).
class _GuessInfoBox extends StatelessWidget {
  const _GuessInfoBox({required this.guess});

  final TriangulationGuess guess;

  @override
  Widget build(BuildContext context) {
    return _InfoBoxFrame(
      borderColor: FlitColors.error,
      textColor: FlitColors.error,
      visuals: [_MarkerFlag(code: guess.countryCode)],
      lines: [
        if (guess.viaCapital && guess.capitalName.isNotEmpty)
          guess.capitalName
        else
          guess.countryName,
      ],
    );
  }
}

class _InfoBoxFrame extends StatelessWidget {
  const _InfoBoxFrame({
    required this.borderColor,
    required this.textColor,
    required this.visuals,
    required this.lines,
  });

  final Color borderColor;
  final Color textColor;
  final List<Widget> visuals;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visuals.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: visuals,
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small flag with the shared emoji fallback for unsupported codes.
class _MarkerFlag extends StatelessWidget {
  const _MarkerFlag({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    if (code.length == 2 && !code.startsWith('X')) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Flag.fromString(
            code,
            height: 22,
            width: 33,
            fit: BoxFit.contain,
            borderRadius: 3,
          ),
        );
      } catch (_) {
        // fall through to emoji
      }
    }
    final emoji = code.length == 2
        ? String.fromCharCodes(
            code.toUpperCase().codeUnits.map((c) => c + 127397),
          )
        : code;
    return Text(emoji, style: const TextStyle(fontSize: 16));
  }
}
