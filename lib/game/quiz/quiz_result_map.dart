import 'package:flutter/material.dart';

import '../map/region.dart';
import 'quiz_map_widget.dart';
import 'quiz_region_map_widget.dart';

/// Non-interactive outcome map for quiz results.
///
/// Renders the quiz's OWN region map (the same painters used in-game via
/// [QuizMapWidget] / [QuizRegionMapWidget]) with areas tinted by outcome:
/// green/satellite for answers found, red for missed ones, neutral for
/// everything else.
///
/// This exists because quiz answer codes are region-scoped (US state codes,
/// UK county codes, …) and collide with ISO country codes — plotting them on
/// a world map lands "TN" (Tennessee) on Tunisia. Results must therefore
/// NEVER be drawn on the world reveal map; they belong on the region map the
/// quiz was played on.
class QuizResultMap extends StatelessWidget {
  const QuizResultMap({
    super.key,
    required this.region,
    required this.correctCodes,
    required this.missedCodes,
    this.height = 200,
    this.showLabels = false,
  });

  /// The region the quiz was played on — the map that gets rendered.
  final GameRegion region;

  /// Answer codes the player found (tinted green / satellite reveal).
  final Set<String> correctCodes;

  /// Answer codes the player never found (tinted red).
  final Set<String> missedCodes;

  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final areas = RegionalData.getAreas(region);
    final visuals = <String, StateVisual>{
      for (final area in areas) area.code: StateVisual(area: area),
    };
    for (final code in correctCodes) {
      visuals[code]?.status = StateVisualStatus.correct;
    }
    for (final code in missedCodes) {
      // Correct wins if a question was missed first and solved later.
      if (correctCodes.contains(code)) continue;
      visuals[code]?.status = StateVisualStatus.wrong;
    }

    // IgnorePointer disables pan/zoom/taps — this is a static reveal.
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: region == GameRegion.usStates
            ? QuizMapWidget(
                stateVisuals: visuals,
                onStateTapped: (_) {},
                showLabels: showLabels,
                correctCodes: correctCodes,
              )
            : QuizRegionMapWidget(
                region: region,
                stateVisuals: visuals,
                onStateTapped: (_) {},
                showLabels: showLabels,
                correctCodes: correctCodes,
              ),
      ),
    );
  }
}
