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
/// red arrow per wrong guess. Each arrow carries an info box holding all
/// enabled clue visuals and labels for that location.
///
/// Arrows always point at the true bearing. Info boxes are laid out by an
/// iterative rectangle-collision pass that keeps every box outside the
/// arrow zone and clear of its neighbours; a thin leader line ties each
/// box back to its arrow tip. Sized by its parent; always renders square
/// via [AspectRatio]. All placement is fractional (no absolute positioning)
/// so it scales across phone/tablet/web.
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
  static const double _arrowEndFraction = 0.28;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final center = Offset(side / 2, side / 2);
          final arrowEnd = side * _arrowEndFraction;

          final markers = <_MarkerContent>[
            for (final clue in clues) _clueContent(clue),
            for (final guess in wrongGuesses) _guessContent(guess),
          ];

          // Shrink boxes when the compass gets crowded so a full game
          // (6 clue markers + 5 guesses) still fits.
          var boxWidth = (side * 0.24).clamp(72.0, 116.0);
          if (markers.length > 8) boxWidth *= 0.88;

          final sizes = [
            for (final m in markers) _estimateBoxSize(m, boxWidth),
          ];
          final positions = _layoutBoxes(
            markers: markers,
            sizes: sizes,
            side: side,
            center: center,
            // Boxes stay wholly outside the arrow zone, so no box can
            // cover another marker's arrow shaft.
            minRadius: arrowEnd + 6,
          );

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
              // Leader lines from each arrow tip to its (possibly pushed
              // away) box, drawn beneath the boxes so they visually stop
              // at the box edge.
              Positioned.fill(
                child: CustomPaint(
                  painter: _LeaderLinePainter(
                    segments: [
                      for (var i = 0; i < markers.length; i++)
                        (
                          from: center +
                              bearingToDirection(markers[i].bearingDeg) *
                                  arrowEnd,
                          to: positions[i],
                          isGuess: markers[i].isGuess,
                        ),
                    ],
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
              for (var i = 0; i < markers.length; i++)
                Positioned(
                  left: positions[i].dx - sizes[i].width / 2,
                  top: positions[i].dy - sizes[i].height / 2,
                  width: sizes[i].width,
                  // No text to hold → no card: just the bare visual(s) at
                  // the arrow tip (e.g. flags-only expert mode).
                  child: markers[i].lines.isEmpty
                      ? Wrap(
                          spacing: 4,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: markers[i].visuals,
                        )
                      : _InfoBoxFrame(
                          borderColor: markers[i].isGuess
                              ? FlitColors.error
                              : FlitColors.cardBorder,
                          textColor: markers[i].isGuess
                              ? FlitColors.error
                              : FlitColors.textPrimary,
                          visuals: markers[i].visuals,
                          lines: markers[i].lines,
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Marker content ─────────────────────────────────────────────────────

  _MarkerContent _clueContent(TriangulationClue clue) {
    final visuals = <Widget>[];
    var hasOutline = false;
    if (clueTypes.contains(ClueType.flag)) {
      visuals.add(_MarkerFlag(code: clue.countryCode));
    }
    if (clueTypes.contains(ClueType.outline)) {
      hasOutline = true;
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

    return _MarkerContent(
      bearingDeg: clue.bearingFromTargetDeg,
      isGuess: false,
      visuals: visuals,
      hasFlag: clueTypes.contains(ClueType.flag),
      hasOutline: hasOutline,
      lines: lines,
    );
  }

  /// Wrong guess: red-tinted, flag + guessed name only (no distance —
  /// bearing plus distance would give the answer away).
  _MarkerContent _guessContent(TriangulationGuess guess) => _MarkerContent(
        bearingDeg: guess.bearingFromTargetDeg,
        isGuess: true,
        visuals: [_MarkerFlag(code: guess.countryCode)],
        hasFlag: true,
        hasOutline: false,
        lines: [
          if (guess.viaCapital && guess.capitalName.isNotEmpty)
            guess.capitalName
          else
            guess.countryName,
        ],
      );

  // ── Layout ─────────────────────────────────────────────────────────────

  /// Estimated rendered size of a marker box, mirroring [_InfoBoxFrame]'s
  /// paddings and text metrics. Kept deliberately slightly generous so the
  /// collision layout leaves breathing room.
  Size _estimateBoxSize(_MarkerContent marker, double boxWidth) {
    // Markers with no text render frameless (bare visuals), so their size
    // is just the visuals' footprint — the collision layout then packs
    // them much tighter.
    if (marker.lines.isEmpty) {
      var width = 0.0;
      if (marker.hasFlag) width += 33;
      if (marker.hasOutline) width += 40 + (marker.hasFlag ? 4 : 0);
      return Size(math.max(width, 24), marker.hasOutline ? 30 : 22);
    }
    final innerWidth = boxWidth - 12; // horizontal padding
    var height = 10.0; // vertical padding
    if (marker.visuals.isNotEmpty) {
      height += marker.hasOutline ? 30 : 22;
      // Flag + outline may wrap to two visual rows on narrow boxes.
      if (marker.hasFlag && marker.hasOutline && innerWidth < 78) {
        height += 24;
      }
    }
    for (final line in marker.lines) {
      const charWidth = 6.2; // ~10.5px semi-bold
      final rows = ((line.length * charWidth) / innerWidth).ceil().clamp(1, 2);
      height += rows * 13.0 + 2;
    }
    return Size(boxWidth, height);
  }

  /// Iterative rectangle-collision layout. Each box starts at its true
  /// bearing just past the arrow tip, then boxes push each other apart,
  /// stay outside [minRadius] from the centre (the arrow zone), and are
  /// softly kept inside the square. Deterministic — no randomness.
  static List<Offset> _layoutBoxes({
    required List<_MarkerContent> markers,
    required List<Size> sizes,
    required double side,
    required Offset center,
    required double minRadius,
  }) {
    const margin = 5.0;
    final positions = <Offset>[
      for (var i = 0; i < markers.length; i++)
        center +
            bearingToDirection(markers[i].bearingDeg) *
                (minRadius + sizes[i].height / 2 + 4),
    ];

    for (var iter = 0; iter < 80; iter++) {
      var moved = false;

      // Pairwise separation along the axis of least penetration.
      for (var i = 0; i < positions.length; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          final dx = positions[j].dx - positions[i].dx;
          final dy = positions[j].dy - positions[i].dy;
          final overlapX =
              (sizes[i].width + sizes[j].width) / 2 + margin - dx.abs();
          final overlapY =
              (sizes[i].height + sizes[j].height) / 2 + margin - dy.abs();
          if (overlapX <= 0 || overlapY <= 0) continue;
          moved = true;
          if (overlapX < overlapY) {
            final push = overlapX / 2 * (dx >= 0 ? 1 : -1);
            positions[i] -= Offset(push, 0);
            positions[j] += Offset(push, 0);
          } else {
            // On exact ties (identical centres) push apart vertically by
            // index order so the pass stays deterministic.
            final sign = dy != 0 ? (dy > 0 ? 1 : -1) : 1;
            final push = overlapY / 2 * sign;
            positions[i] -= Offset(0, push);
            positions[j] += Offset(0, push);
          }
        }
      }

      for (var i = 0; i < positions.length; i++) {
        // Keep the whole box outside the arrow zone: the rectangle's
        // nearest point to the centre must be at least minRadius away.
        final halfW = sizes[i].width / 2;
        final halfH = sizes[i].height / 2;
        final nearest = Offset(
          center.dx.clamp(positions[i].dx - halfW, positions[i].dx + halfW),
          center.dy.clamp(positions[i].dy - halfH, positions[i].dy + halfH),
        );
        final delta = nearest - center;
        final dist = delta.distance;
        if (dist < minRadius) {
          moved = true;
          final dir = positions[i] - center;
          final outward = dir.distance > 0.01
              ? dir / dir.distance
              : bearingToDirection(markers[i].bearingDeg);
          positions[i] += outward * (minRadius - dist + 1);
        }

        // Soft bounds: prefer staying inside the square, but allow a small
        // overflow (the Stack doesn't clip) rather than re-overlapping.
        final slack = side * 0.05;
        final minX = halfW - slack;
        final maxX = side - halfW + slack;
        final minY = halfH - slack;
        final maxY = side - halfH + slack;
        final clamped = Offset(
          positions[i].dx.clamp(minX, maxX),
          positions[i].dy.clamp(minY, maxY),
        );
        if (clamped != positions[i]) {
          moved = true;
          positions[i] = clamped;
        }
      }

      if (!moved) break;
    }
    return positions;
  }
}

/// Resolved content + true bearing for one compass marker.
class _MarkerContent {
  const _MarkerContent({
    required this.bearingDeg,
    required this.isGuess,
    required this.visuals,
    required this.hasFlag,
    required this.hasOutline,
    required this.lines,
  });

  final double bearingDeg;
  final bool isGuess;
  final List<Widget> visuals;
  final bool hasFlag;
  final bool hasOutline;
  final List<String> lines;
}

/// Thin lines tying each arrow tip to its info box (drawn beneath the
/// boxes, so they appear to stop at the box edge).
class _LeaderLinePainter extends CustomPainter {
  _LeaderLinePainter({required this.segments});

  final List<({Offset from, Offset to, bool isGuess})> segments;

  @override
  void paint(Canvas canvas, Size size) {
    for (final seg in segments) {
      if ((seg.to - seg.from).distance < 10) continue;
      canvas.drawLine(
        seg.from,
        seg.to,
        Paint()
          ..color = (seg.isGuess ? FlitColors.error : FlitColors.textSecondary)
              .withOpacity(0.45)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_LeaderLinePainter old) =>
      segments.length != old.segments.length ||
      !_segmentsEqual(segments, old.segments);

  static bool _segmentsEqual(
    List<({Offset from, Offset to, bool isGuess})> a,
    List<({Offset from, Offset to, bool isGuess})> b,
  ) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
