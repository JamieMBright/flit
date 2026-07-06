import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../game/tutorial/coach.dart';
import 'coach_speech_panel.dart';

/// One ordered beat of a coached intro: a headline, the coach's line, and a
/// few short bullet points the coach is walking through.
class CoachIntroBeat {
  const CoachIntroBeat({
    required this.icon,
    required this.headline,
    required this.message,
    this.points = const [],
  });

  /// Icon shown on the teaching card for this beat.
  final IconData icon;

  /// Short all-caps headline for the concept being taught.
  final String headline;

  /// The coach's spoken line (shown in the speech panel).
  final String message;

  /// Optional bullet points expanding on the concept.
  final List<String> points;
}

/// A short, reusable coach-led walkthrough shown BEFORE an Advanced Training
/// activity hands the pilot to the real screen. Applies the same guided,
/// beat-by-beat thinking as the Training Recon / Training Briefing lessons —
/// a coach explains the system the mission teaches (rated play, hints, the
/// license, fuel, the shop, or challenges) one concept at a time, then the
/// pilot presses through to the real activity.
///
/// Pops with `true` when the pilot finishes the walkthrough and wants to
/// begin, or `null`/`false` if they back out — so the launcher only starts
/// the real activity on an explicit "begin".
class CoachedIntroScreen extends StatefulWidget {
  const CoachedIntroScreen({
    super.key,
    required this.coach,
    required this.title,
    required this.beats,
    required this.launchLabel,
  });

  final Coach coach;

  /// App-bar title, e.g. 'First Sortie'.
  final String title;

  /// Ordered teaching beats.
  final List<CoachIntroBeat> beats;

  /// Label on the final button, e.g. 'FLY THE SORTIE'.
  final String launchLabel;

  @override
  State<CoachedIntroScreen> createState() => _CoachedIntroScreenState();
}

class _CoachedIntroScreenState extends State<CoachedIntroScreen> {
  int _index = 0;

  bool get _isLast => _index == widget.beats.length - 1;

  void _next() {
    if (_isLast) {
      hapticSuccess();
      Navigator.of(context).pop(true);
      return;
    }
    hapticLight();
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final beat = widget.beats[_index];
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text(
          widget.title,
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: MenuContentWrapper(
          child: Column(
            children: [
              CoachSpeechPanel(coach: widget.coach, message: beat.message),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Column(
                    children: [
                      _stepDots(),
                      const SizedBox(height: 14),
                      _TeachingCard(beat: beat),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.beats.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: i == _index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= _index ? FlitColors.accent : FlitColors.cardBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isLast ? FlitColors.gold : FlitColors.accent,
            foregroundColor:
                _isLast ? FlitColors.backgroundDark : FlitColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _isLast ? widget.launchLabel : 'CONTINUE',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeachingCard extends StatelessWidget {
  const _TeachingCard({required this.beat});

  final CoachIntroBeat beat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlitColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FlitColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(beat.icon, color: FlitColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  beat.headline,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          if (beat.points.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final point in beat.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: FlitColors.gold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
