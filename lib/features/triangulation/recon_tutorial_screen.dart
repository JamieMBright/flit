import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/math_utils.dart';
import '../../core/widgets/country_flag.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/country_data.dart';
import '../../game/triangulation/triangulation_scoring.dart';
import '../../game/triangulation/triangulation_session.dart';
import '../../game/triangulation/triangulation_target.dart';
import '../../game/tutorial/coach.dart';
import '../../game/tutorial/training_missions.dart';
import '../campaign/coach_speech_panel.dart';
import 'widgets/recon_tutorial_map.dart';
import 'widgets/triangulation_compass.dart';

/// Fully guided, beginner-friendly Training Recon lesson.
///
/// Antoine de Saint-Exupéry walks the pilot through reconnaissance /
/// triangulation from first principles, using a fixed, forgiving example:
/// the hidden target is **France**, located by five neighbours — Spain, the
/// UK, Algeria, Germany and Belgium. The lesson reuses the live game's
/// [TriangulationCompass] and clue model, and a France-centred
/// [ReconTutorialMap], rather than dropping the player into the real timed
/// game. It ends by recording completion through [onComplete] exactly as the
/// real Recon round did, so Daily Recon still unlocks and Basic Training still
/// progresses toward the pilot's wings.
class ReconTutorialScreen extends StatefulWidget {
  const ReconTutorialScreen({super.key, required this.onComplete});

  /// Called once, when the lesson is finished, with the (generous) score to
  /// record for the mission. Mirrors the real game's `onSessionComplete`.
  final void Function(int score) onComplete;

  @override
  State<ReconTutorialScreen> createState() => _ReconTutorialScreenState();
}

/// The ordered beats of the lesson.
enum _Beat {
  intro,
  clueSpain,
  clueUK,
  clueAlgeria,
  clueGermany,
  clueBelgium,
  compassIntro,
  tapPractice,
  wrongDemo,
  guessPrompt,
  solved,
}

/// One neighbour clue, with the coach's plain-language direction phrase.
class _ReconClue {
  const _ReconClue(this.clue, this.mapLabel, this.directionPhrase);

  final TriangulationClue clue;
  final String mapLabel;
  final String directionPhrase;
}

class _ReconTutorialScreenState extends State<ReconTutorialScreen> {
  static const Coach _coach = trainingCoachSaintExuperyRecon;

  static const _targetCode = 'FR';

  late final Vector2 _targetLngLat;
  late final List<_ReconClue> _clues;
  late final TriangulationGuess _andorraGuess;

  _Beat _beat = _Beat.intro;

  /// Neighbour chip indices the player has inspected during tap practice.
  final Set<int> _tapped = {};

  /// The clue whose detail is currently pinned open in tap practice.
  int? _selectedClue;

  /// A gentle nudge shown if the player picks a wrong answer.
  String? _wrongAnswerNudge;

  @override
  void initState() {
    super.initState();
    _targetLngLat = CountryData.getCapital(_targetCode)!.location;
    _clues = [
      _clue('ES', 'Spain', 'to the south-west, beyond the Pyrenees'),
      _clue('GB', 'UK', 'to the north, across the Channel'),
      _clue('DZ', 'Algeria', 'to the south, over the Mediterranean'),
      _clue('DE', 'Germany', 'to the east'),
      _clue('BE', 'Belgium', 'to the north-east, just over the border'),
    ];
    _andorraGuess = _buildGuess('AD');
  }

  _ReconClue _clue(String code, String label, String direction) {
    final cap = CountryData.getCapital(code)!;
    final country = CountryData.getCountry(code)!;
    return _ReconClue(
      TriangulationClue(
        countryCode: code,
        countryName: country.name,
        capitalName: cap.name,
        capitalLngLat: cap.location,
        bearingFromTargetDeg: flatMapBearingDeg(_targetLngLat, cap.location),
        distanceFromTargetKm: greatCircleKm(_targetLngLat, cap.location),
      ),
      label,
      direction,
    );
  }

  TriangulationGuess _buildGuess(String code) {
    final cap = CountryData.getCapital(code)!;
    final country = CountryData.getCountry(code)!;
    final distanceKm = greatCircleKm(_targetLngLat, cap.location);
    return TriangulationGuess(
      countryCode: code,
      countryName: country.name,
      capitalName: cap.name,
      capitalLngLat: cap.location,
      viaCapital: false,
      isCorrect: false,
      distanceKm: distanceKm,
      bearingFromTargetDeg: flatMapBearingDeg(_targetLngLat, cap.location),
      penalty: triProximityPenalty(distanceKm, isNeighbor: true),
    );
  }

  // ── Beat flow ──────────────────────────────────────────────────────────

  void _advance() {
    hapticLight();
    setState(() {
      const order = _Beat.values;
      final next = order[math.min(_beat.index + 1, order.length - 1)];
      _beat = next;
    });
  }

  void _onChipTapped(int index) {
    hapticLight();
    setState(() {
      _selectedClue = index;
      _tapped.add(index);
    });
  }

  void _onAnswer(String code) {
    if (code == _targetCode) {
      hapticSuccess();
      setState(() {
        _wrongAnswerNudge = null;
        _beat = _Beat.solved;
      });
    } else {
      hapticLight();
      final name = CountryData.getCountry(code)?.name ?? code;
      setState(() {
        _wrongAnswerNudge =
            '$name is where one arrow points — but recon is about where '
            'they ALL cross. Look at the centre and try once more.';
      });
    }
  }

  int get _lessonScore => computeTriangulationScore(
        solved: true,
        solvedAsCountry: false,
        // A generous, fixed "well-flown lesson" time — no real clock runs.
        timeMs: 20000,
        wrongGuessPenalties: const [],
        targetCountryCode: _targetCode,
      );

  void _finish() {
    hapticSuccess();
    widget.onComplete(_lessonScore);
    Navigator.of(context).pop();
  }

  // ── Coach copy ─────────────────────────────────────────────────────────

  String get _coachMessage {
    switch (_beat) {
      case _Beat.intro:
        return _coach.introduction;
      case _Beat.clueSpain:
        return 'Clue one. Our target borders Spain ${_clues[0].directionPhrase}'
            '. So from the target, Spain lies to the south-west — remember '
            'that direction.';
      case _Beat.clueUK:
        return 'Clue two. The United Kingdom sits ${_clues[1].directionPhrase}'
            '. A second direction fixed — the picture is forming.';
      case _Beat.clueAlgeria:
        return 'Clue three. Algeria lies ${_clues[2].directionPhrase} — I flew '
            'that coast myself. South of the target now.';
      case _Beat.clueGermany:
        return 'Clue four. Germany is ${_clues[3].directionPhrase}. Notice how '
            'the arrows are beginning to surround one place.';
      case _Beat.clueBelgium:
        return 'Clue five. Belgium lies ${_clues[4].directionPhrase}. Five '
            'neighbours, five directions — and only one country they can all '
            'point away from.';
      case _Beat.compassIntro:
        return 'In the cockpit you do not have that map — only this compass. '
            'Each neighbour becomes an arrow pointing FROM the hidden target '
            'toward it. Spain\'s arrow points south-west, exactly as on the '
            'map. Where the arrows agree is your target.';
      case _Beat.tapPractice:
        final n = _tapped.length;
        if (n == 0) {
          return 'Your turn to read the instrument. Tap each neighbour below '
              'to see its exact bearing and distance from the target. Tap all '
              'five.';
        }
        if (n < _clues.length) {
          return 'Good — ${_clues[_selectedClue!].clue.countryName} read and '
              'logged. $n of ${_clues.length} so far. Keep going.';
        }
        return 'Every bearing read. Feel how the five of them box in a single '
            'spot? That spot is the target. Press on.';
      case _Beat.wrongDemo:
        return 'Before you commit, watch a WRONG guess. Andorra is tiny, '
            'tucked in the Pyrenees between France and Spain — a tempting '
            'mistake. See the red arrow and "${formatKmAway(_andorraGuess.distanceKm)}"? '
            'That is your feedback: close, but off. A wrong guess costs points '
            'and shows you which way to correct.';
      case _Beat.guessPrompt:
        return _wrongAnswerNudge ??
            'Now — name the target. Every arrow points away from one country '
                'in western Europe. You know this one. Choose it below.';
      case _Beat.solved:
        return _coach.farewell;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Recon Lesson',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: MenuContentWrapper(
          child: Column(
            children: [
              CoachSpeechPanel(coach: _coach, message: _coachMessage),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: _content(),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_beat) {
      case _Beat.intro:
      case _Beat.clueSpain:
      case _Beat.clueUK:
      case _Beat.clueAlgeria:
      case _Beat.clueGermany:
      case _Beat.clueBelgium:
        return _mapContent();
      case _Beat.compassIntro:
        return _compassContent(interactive: false, showWrong: false);
      case _Beat.tapPractice:
        return _tapPracticeContent();
      case _Beat.wrongDemo:
        return _compassContent(interactive: false, showWrong: true);
      case _Beat.guessPrompt:
        return _guessContent();
      case _Beat.solved:
        return _solvedContent();
    }
  }

  /// How many neighbour markers are revealed on the teaching map at [_beat].
  int get _revealedCount {
    switch (_beat) {
      case _Beat.intro:
        return 0;
      case _Beat.clueSpain:
        return 1;
      case _Beat.clueUK:
        return 2;
      case _Beat.clueAlgeria:
        return 3;
      case _Beat.clueGermany:
        return 4;
      case _Beat.clueBelgium:
        return 5;
      default:
        return 5;
    }
  }

  Widget _mapContent({bool showWrong = false}) {
    final markers = [
      for (var i = 0; i < _revealedCount; i++)
        ReconMapMarker(
          code: _clues[i].clue.countryCode,
          lngLat: _clues[i].clue.capitalLngLat,
          label: _clues[i].mapLabel,
        ),
      if (showWrong)
        ReconMapMarker(
          code: _andorraGuess.countryCode,
          lngLat: _andorraGuess.capitalLngLat,
          label: 'Andorra',
          isWrong: true,
        ),
    ];
    return Column(
      children: [
        ReconTutorialMap(
          targetCode: _targetCode,
          targetLngLat: _targetLngLat,
          showTargetName: true,
          markers: markers,
        ),
        const SizedBox(height: 6),
        Text(
          'Gold star = the hidden target · orange = a known neighbour · '
          'each line is the direction between them',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FlitColors.textMuted.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _compassContent({
    required bool interactive,
    required bool showWrong,
  }) {
    return Column(
      children: [
        TriangulationCompass(
          clues: [for (final c in _clues) c.clue],
          wrongGuesses: showWrong ? [_andorraGuess] : const [],
          clueTypes: const {ClueType.flag},
          labelTypes: const {TriLabel.country},
          centerLabel: 'TARGET',
          showClueDistances: interactive && _tapped.length == _clues.length,
          selectedClueIndex: interactive ? _selectedClue : null,
        ),
        const SizedBox(height: 4),
        Text(
          'Each arrow points from the hidden target toward that neighbour',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FlitColors.textMuted.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _tapPracticeContent() {
    return Column(
      children: [
        _compassContent(interactive: true, showWrong: false),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _clues.length; i++)
              _NeighbourChip(
                code: _clues[i].clue.countryCode,
                name: _clues[i].clue.countryName,
                inspected: _tapped.contains(i),
                selected: _selectedClue == i,
                onTap: () => _onChipTapped(i),
              ),
          ],
        ),
        if (_selectedClue != null) ...[
          const SizedBox(height: 10),
          _BearingDetail(clue: _clues[_selectedClue!]),
        ],
      ],
    );
  }

  Widget _guessContent() {
    // A gentle three-way choice; the target sits obviously at the centre of
    // the arrows. Distractors are two of the neighbours themselves.
    const options = ['ES', 'FR', 'DE'];
    return Column(
      children: [
        _compassContent(interactive: false, showWrong: true),
        const SizedBox(height: 14),
        const Text(
          'Where do all the arrows point?',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final code in options)
              _AnswerButton(
                code: code,
                name: CountryData.getCountry(code)!.name,
                onTap: () => _onAnswer(code),
              ),
          ],
        ),
      ],
    );
  }

  Widget _solvedContent() {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Text(
          'TARGET LOCATED!',
          style: TextStyle(
            color: FlitColors.success,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CountryFlag(code: _targetCode, height: 30, width: 45),
            const SizedBox(width: 10),
            Text(
              CountryData.getCountry(_targetCode)!.name,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ReconTutorialMap(
          targetCode: _targetCode,
          targetLngLat: _targetLngLat,
          showTargetName: true,
          markers: [
            for (final c in _clues)
              ReconMapMarker(
                code: c.clue.countryCode,
                lngLat: c.clue.capitalLngLat,
                label: c.mapLabel,
              ),
            ReconMapMarker(
              code: _andorraGuess.countryCode,
              lngLat: _andorraGuess.capitalLngLat,
              label: 'Andorra',
              isWrong: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '+$_lessonScore pts',
          style: const TextStyle(
            color: FlitColors.gold,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ── Bottom action bar ────────────────────────────────────────────────────

  Widget _bottomBar() {
    // The guess beat has its own answer buttons; no bottom action there.
    if (_beat == _Beat.guessPrompt) return const SizedBox(height: 8);

    final bool ready;
    final String label;
    final VoidCallback onTap;
    if (_beat == _Beat.solved) {
      ready = true;
      label = 'COMPLETE LESSON';
      onTap = _finish;
    } else if (_beat == _Beat.tapPractice) {
      ready = _tapped.length == _clues.length;
      label = ready ? 'CONTINUE' : 'TAP ALL FIVE NEIGHBOURS';
      onTap = _advance;
    } else {
      ready = true;
      label = _beat == _Beat.intro ? 'BEGIN' : 'CONTINUE';
      onTap = _advance;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: ready ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _beat == _Beat.solved ? FlitColors.gold : FlitColors.accent,
            foregroundColor: _beat == _Beat.solved
                ? FlitColors.backgroundDark
                : FlitColors.textPrimary,
            disabledBackgroundColor: FlitColors.cardBackground,
            disabledForegroundColor: FlitColors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
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

/// A tappable neighbour chip in the tap-to-inspect practice.
class _NeighbourChip extends StatelessWidget {
  const _NeighbourChip({
    required this.code,
    required this.name,
    required this.inspected,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String name;
  final bool inspected;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? FlitColors.gold.withValues(alpha: 0.18)
              : FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? FlitColors.gold
                : inspected
                    ? FlitColors.success.withValues(alpha: 0.7)
                    : FlitColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountryFlag(code: code, height: 14, width: 21),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (inspected) ...[
              const SizedBox(width: 5),
              const Icon(Icons.check_circle,
                  size: 14, color: FlitColors.success),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bearing + distance read-out shown when a neighbour chip is tapped.
class _BearingDetail extends StatelessWidget {
  const _BearingDetail({required this.clue});

  final _ReconClue clue;

  @override
  Widget build(BuildContext context) {
    final bearing = clue.clue.bearingFromTargetDeg.round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CountryFlag(code: clue.clue.countryCode, height: 16, width: 24),
              const SizedBox(width: 8),
              Text(
                clue.clue.countryName,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bearing $bearing° — ${clue.directionPhrase.replaceFirst('to the ', '')}',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          Text(
            '${formatKmAway(clue.clue.distanceFromTargetKm)} from the target',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A large answer button on the final guess beat.
class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.code,
    required this.name,
    required this.onTap,
  });

  final String code;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: FlitColors.cardBackground,
        foregroundColor: FlitColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CountryFlag(code: code, height: 18, width: 27),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
