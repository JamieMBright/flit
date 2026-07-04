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
///
/// Dense configs (3+ text lines per marker) collapse each box to its
/// primary label; the full, untruncated content moves to a tap-to-open
/// [TriangulationClueDetailCard] hosted by the parent screen via
/// [onClueTap] / [selectedClueIndex].
class TriangulationCompass extends StatelessWidget {
  const TriangulationCompass({
    super.key,
    required this.clues,
    required this.wrongGuesses,
    required this.clueTypes,
    required this.labelTypes,
    this.centerLabel = 'CAPITAL',
    this.showClueDistances = false,
    this.selectedClueIndex,
    this.onClueTap,
  });

  final List<TriangulationClue> clues;
  final List<TriangulationGuess> wrongGuesses;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;
  final String centerLabel;

  /// Which clue marker is currently inspected (gold highlight), if any.
  final int? selectedClueIndex;

  /// Called with the clue index when a marker with collapsed or truncated
  /// content is tapped. Null disables tap handling entirely.
  final ValueChanged<int>? onClueTap;

  /// When true (the distance hint was bought), each starting clue's box
  /// also shows its distance from the hidden target. Wrong-guess markers
  /// always show their distance — that feedback is free.
  final bool showClueDistances;

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
                  child: _markerChild(markers[i], clueIndex: i),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The rendered widget for one marker: bare visuals when frameless, a
  /// framed info box otherwise, wrapped in a tap target when the marker
  /// has more content than its box shows.
  Widget _markerChild(_MarkerContent marker, {required int clueIndex}) {
    final selected = !marker.isGuess && clueIndex == selectedClueIndex;
    // No text to hold → no card: just the bare visual(s) at the arrow
    // tip (e.g. flags-only expert mode).
    final Widget child = marker.displayLines.isEmpty
        ? Wrap(
            spacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: marker.visuals,
          )
        : _InfoBoxFrame(
            borderColor: marker.isGuess
                ? FlitColors.error
                : selected
                    ? FlitColors.gold
                    : FlitColors.cardBorder,
            textColor:
                marker.isGuess ? FlitColors.error : FlitColors.textPrimary,
            visuals: marker.visuals,
            lines: marker.displayLines,
            showMore: marker.hasMore,
          );
    if (marker.isGuess || !marker.hasMore || onClueTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onClueTap!(clueIndex),
      child: child,
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
    var bordersTruncated = false;
    if (clueTypes.contains(ClueType.borders)) {
      final neighbors = Clue.getNeighbors(clue.countryCode);
      if (neighbors.isNotEmpty) {
        bordersTruncated = neighbors.length > 3;
        final shown = neighbors.take(3).join(', ');
        lines.add(bordersTruncated ? 'Borders: $shown…' : 'Borders: $shown');
      }
    }

    // Dense configs collapse to the primary label so the compass stays
    // readable — the rest moves to the tap-to-open detail card. The bought
    // distance line always stays visible.
    final compact = lines.length > 2;
    final displayLines = compact ? [lines.first] : List.of(lines);
    if (showClueDistances) {
      displayLines.add(formatKmAway(clue.distanceFromTargetKm));
    }

    return _MarkerContent(
      bearingDeg: clue.bearingFromTargetDeg,
      isGuess: false,
      visuals: visuals,
      hasFlag: clueTypes.contains(ClueType.flag),
      hasOutline: hasOutline,
      displayLines: displayLines,
      hasMore: compact || bordersTruncated,
    );
  }

  /// Wrong guess: red-tinted, flag + guessed name + free distance.
  _MarkerContent _guessContent(TriangulationGuess guess) => _MarkerContent(
        bearingDeg: guess.bearingFromTargetDeg,
        isGuess: true,
        visuals: [_MarkerFlag(code: guess.countryCode)],
        hasFlag: true,
        hasOutline: false,
        displayLines: [
          if (guess.viaCapital && guess.capitalName.isNotEmpty)
            guess.capitalName
          else
            guess.countryName,
          // Distance feedback is free on every guess — combined with the
          // bearing it's the core triangulation feedback loop.
          formatKmAway(guess.distanceKm),
        ],
        hasMore: false,
      );

  // ── Layout ─────────────────────────────────────────────────────────────

  /// Estimated rendered size of a marker box, mirroring [_InfoBoxFrame]'s
  /// paddings and text metrics. Kept deliberately slightly generous so the
  /// collision layout leaves breathing room.
  Size _estimateBoxSize(_MarkerContent marker, double boxWidth) {
    // Markers with no text render frameless (bare visuals), so their size
    // is just the visuals' footprint — the collision layout then packs
    // them much tighter.
    if (marker.displayLines.isEmpty) {
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
    for (final line in marker.displayLines) {
      const charWidth = 6.2; // ~10.5px semi-bold
      final rows = ((line.length * charWidth) / innerWidth).ceil().clamp(1, 2);
      height += rows * 13.0 + 2;
    }
    if (marker.hasMore) height += 12; // "more" dots row
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

        // Soft bounds: prefer staying inside the square, but allow a tiny
        // overflow (the Stack doesn't clip) rather than re-overlapping.
        // Kept tight so boxes never get clipped by the screen edge.
        final slack = side * 0.02;
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
    required this.displayLines,
    required this.hasMore,
  });

  final double bearingDeg;
  final bool isGuess;
  final List<Widget> visuals;
  final bool hasFlag;
  final bool hasOutline;

  /// Text lines actually shown in the on-compass box (collapsed for
  /// dense configs).
  final List<String> displayLines;

  /// True when tapping opens the detail card (content was collapsed or
  /// a borders list was truncated).
  final bool hasMore;
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
    this.showMore = false,
  });

  final Color borderColor;
  final Color textColor;
  final List<Widget> visuals;
  final List<String> lines;

  /// Renders a muted "more" dots row — the tap-for-details affordance.
  final bool showMore;

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
          if (showMore)
            Icon(
              Icons.more_horiz_rounded,
              size: 12,
              color: FlitColors.textMuted.withOpacity(0.8),
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

/// Full, untruncated info for one tapped clue marker, shown beneath the
/// compass. Only reveals content the round's clue/label config already
/// enables — inspecting a marker never leaks extra information (e.g. no
/// country name on label-free expert themes).
class TriangulationClueDetailCard extends StatelessWidget {
  const TriangulationClueDetailCard({
    super.key,
    required this.clue,
    required this.clueTypes,
    required this.labelTypes,
    this.showDistance = false,
    this.onClose,
  });

  final TriangulationClue clue;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;
  final bool showDistance;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    for (final label in TriLabel.values) {
      if (label == TriLabel.country) continue; // shown as the title
      if (!labelTypes.contains(label)) continue;
      final text = clue.labelText(label);
      if (text != null) rows.add((label.displayName, text));
    }
    if (clueTypes.contains(ClueType.capital) &&
        !labelTypes.contains(TriLabel.capital)) {
      rows.add((TriLabel.capital.displayName, clue.capitalName));
    }
    if (clueTypes.contains(ClueType.borders)) {
      final neighbors = Clue.getNeighbors(clue.countryCode);
      if (neighbors.isNotEmpty) rows.add(('Borders', neighbors.join(', ')));
    }
    final title =
        labelTypes.contains(TriLabel.country) ? clue.countryName : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.gold.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (clueTypes.contains(ClueType.flag)) ...[
                      _MarkerFlag(code: clue.countryCode),
                      const SizedBox(width: 8),
                    ],
                    if (clueTypes.contains(ClueType.outline)) ...[
                      SizedBox(
                        width: 40,
                        height: 30,
                        child: CustomPaint(
                          painter: CountryOutlinePainter(
                            CountryData.getCountry(clue.countryCode)
                                    ?.polygons ??
                                const [],
                            fillColor: FlitColors.landMass.withOpacity(0.5),
                            strokeColor: FlitColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (title != null)
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label  ',
                            style: const TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: value,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (showDistance)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatKmAway(clue.distanceFromTargetKm),
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: FlitColors.textMuted.withOpacity(0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// '1,234 km away' formatting shared by clue and guess markers.
String formatKmAway(double km) {
  final rounded = km.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final fromEnd = rounded.length - i;
    buf.write(rounded[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return '$buf km away';
}
