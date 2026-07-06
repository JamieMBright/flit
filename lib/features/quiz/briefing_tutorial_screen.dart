import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/country_flag.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../game/tutorial/coach.dart';
import '../../game/tutorial/training_missions.dart';
import '../campaign/coach_speech_panel.dart';
import 'widgets/briefing_tutorial_map.dart';

/// Fully guided, beginner-friendly Training Briefing lesson.
///
/// Lotfia El Nadi — the first woman in Africa and the Arab world to earn her
/// wings — walks the pilot through the Briefing mechanic ("I name a country,
/// you find it and tap it") over her own region: Egypt and its neighbours
/// (Libya, Sudan, Saudi Arabia, Jordan). The lesson does one country
/// together, demonstrates what a wrong answer looks like, then lets the pilot
/// find two more unaided — all fully forgiving, with no timer. It ends by
/// recording completion through [onComplete] exactly as the old briefing quiz
/// did, so Daily Briefing still unlocks and Basic Training still progresses
/// toward the pilot's wings.
class BriefingTutorialScreen extends StatefulWidget {
  const BriefingTutorialScreen({super.key, required this.onComplete});

  /// Called once, when the lesson is finished, with the (generous) score to
  /// record for the mission. Mirrors the old briefing quiz's completion hook.
  final void Function(int score) onComplete;

  @override
  State<BriefingTutorialScreen> createState() => _BriefingTutorialScreenState();
}

/// The ordered beats of the lesson.
enum _Beat {
  intro,
  learnRegion,
  walkEgypt,
  wrongDemo,
  tapLibya,
  tapSudan,
  solved,
}

class _BriefingTutorialScreenState extends State<BriefingTutorialScreen> {
  static const Coach _coach = trainingCoachLotfiaBriefing;

  /// A generous, fixed "well-flown lesson" score — three clean finds, no
  /// clock. The old briefing quiz posted its `summary.totalScore`; this keeps
  /// completion scoring positive and pleasant.
  static const int _lessonScore = 1500;

  /// The lesson region — Egypt first (walked together), then its neighbours.
  static const List<BriefingCountry> _region = [
    BriefingCountry(
      code: 'EG',
      name: 'Egypt',
      blurb: 'my home, on the Nile between the Mediterranean and the Red Sea',
    ),
    BriefingCountry(
      code: 'LY',
      name: 'Libya',
      blurb: 'Egypt\'s neighbour to the west',
    ),
    BriefingCountry(
      code: 'SD',
      name: 'Sudan',
      blurb: 'directly south of Egypt, down the Nile',
    ),
    BriefingCountry(
      code: 'SA',
      name: 'Saudi Arabia',
      blurb: 'east across the Red Sea',
    ),
    BriefingCountry(
      code: 'JO',
      name: 'Jordan',
      blurb: 'north-east, a small country above Saudi Arabia',
    ),
  ];

  _Beat _beat = _Beat.intro;

  /// Region codes the pilot has correctly tapped so far.
  final Set<String> _found = {};

  /// The most recent wrong tap on the current beat (cleared on advance).
  String? _wrong;

  /// Once the pilot mis-taps on a solo beat, reveal the answer as a gentle
  /// helping hand: the label + gold ring appear so they can always succeed.
  bool _hintRevealed = false;

  BriefingCountry _country(String code) =>
      _region.firstWhere((c) => c.code == code);

  /// The country the pilot must tap on an interactive beat.
  String? get _target {
    switch (_beat) {
      case _Beat.walkEgypt:
        return 'EG';
      case _Beat.tapLibya:
        return 'LY';
      case _Beat.tapSudan:
        return 'SD';
      default:
        return null;
    }
  }

  bool get _targetFound => _target != null && _found.contains(_target);

  // ── Beat flow ──────────────────────────────────────────────────────────

  void _advance() {
    hapticLight();
    setState(() {
      const order = _Beat.values;
      _beat = order[math.min(_beat.index + 1, order.length - 1)];
      _wrong = null;
      _hintRevealed = false;
    });
  }

  void _onTapCountry(String? code) {
    final target = _target;
    if (target == null || code == null) return; // ignore sea / off-region taps
    if (_targetFound) return; // already solved this beat
    if (code == target) {
      hapticSuccess();
      setState(() {
        _found.add(code);
        _wrong = null;
      });
    } else {
      hapticLight();
      setState(() {
        _wrong = code;
        _hintRevealed = true; // reveal help on the solo beats
      });
    }
  }

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
      case _Beat.learnRegion:
        return 'Here is your theatre — my Egypt at the centre, with the Nile '
            'running through it. Libya lies to the west, Sudan to the south, '
            'and across the Red Sea sit Saudi Arabia and little Jordan. Learn '
            'these shapes; a briefing is simply finding the one I name.';
      case _Beat.walkEgypt:
        if (_wrong != null && !_targetFound) {
          return 'That is ${_country(_wrong!).name}. Egypt is the one ringed '
              'in gold, dead centre on the Nile — tap there.';
        }
        if (_targetFound) {
          return 'Egypt — found, exactly right! That is all a briefing is: I '
              'name it, you tap it. Now watch how a WRONG answer looks before '
              'you try alone.';
        }
        return 'Let us do the first one together. Find EGYPT — my home, ringed '
            'in gold on the Nile. Tap it on the map.';
      case _Beat.wrongDemo:
        return 'Watch closely. Say the briefing named SAUDI ARABIA (ringed in '
            'gold), but your finger landed on JORDAN next door — you would see '
            'that red flash. No harm done: a wrong tap is simply shown and '
            'corrected. Nothing is lost. Now you try two on your own.';
      case _Beat.tapLibya:
        if (_wrong != null && !_targetFound) {
          return 'Not quite — that is ${_country(_wrong!).name}. Libya is '
              'Egypt\'s neighbour to the WEST, now shown for you. Tap it.';
        }
        if (_targetFound) {
          return 'Libya — well found, to the west. One more.';
        }
        return 'Your turn, unaided. The labels are off now. Find LIBYA — '
            'Egypt\'s neighbour to the west. Tap it.';
      case _Beat.tapSudan:
        if (_wrong != null && !_targetFound) {
          return 'Close — that is ${_country(_wrong!).name}. Sudan sits '
              'directly SOUTH of Egypt, down the Nile. Tap it.';
        }
        if (_targetFound) {
          return 'Sudan — found, to the south. Three for three, cleanly done.';
        }
        return 'Last one. Find SUDAN — directly south of Egypt, down the '
            'Nile. Tap it.';
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
          'Briefing Lesson',
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
    if (_beat == _Beat.solved) return _solvedContent();

    final bool showLabels;
    final String? promptCode;
    final String? wrongCode;
    switch (_beat) {
      case _Beat.intro:
      case _Beat.learnRegion:
        showLabels = true;
        promptCode = null;
        wrongCode = null;
      case _Beat.walkEgypt:
        showLabels = true;
        promptCode = 'EG'; // always ringed — this one is guided
        wrongCode = _wrong;
      case _Beat.wrongDemo:
        showLabels = true;
        promptCode = 'SA'; // the "named" country in the demo
        wrongCode = 'JO'; // the illustrative wrong tap
      case _Beat.tapLibya:
        showLabels = _hintRevealed;
        promptCode = _hintRevealed ? 'LY' : null;
        wrongCode = _wrong;
      case _Beat.tapSudan:
        showLabels = _hintRevealed;
        promptCode = _hintRevealed ? 'SD' : null;
        wrongCode = _wrong;
      case _Beat.solved:
        showLabels = true;
        promptCode = null;
        wrongCode = null;
    }

    final interactive = _target != null;
    return Column(
      children: [
        BriefingTutorialMap(
          region: _region,
          promptCode: promptCode,
          foundCodes: _found,
          wrongCode: wrongCode,
          showLabels: showLabels,
          onTapCountry: interactive ? _onTapCountry : null,
        ),
        const SizedBox(height: 6),
        Text(
          interactive
              ? 'Tap the country on the map'
              : 'Gold ring = the country being named · green = found',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FlitColors.textMuted.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
        if (interactive) ...[
          const SizedBox(height: 10),
          _TargetChip(
            country: _country(_target!),
            found: _targetFound,
          ),
        ],
      ],
    );
  }

  Widget _solvedContent() {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Text(
          'BRIEFING COMPLETE!',
          style: TextStyle(
            color: FlitColors.success,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),
        const BriefingTutorialMap(
          region: _region,
          foundCodes: {'EG', 'LY', 'SD'},
          showLabels: true,
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in const ['EG', 'LY', 'SD'])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountryFlag(code: code, height: 16, width: 24),
                  const SizedBox(width: 5),
                  Text(
                    _country(code).name,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '+$_lessonScore pts',
          style: TextStyle(
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
    final bool ready;
    final String label;
    final VoidCallback onTap;
    if (_beat == _Beat.solved) {
      ready = true;
      label = 'COMPLETE LESSON';
      onTap = _finish;
    } else if (_target != null) {
      // Interactive tap beat — gated until the named country is found.
      ready = _targetFound;
      label =
          ready ? 'CONTINUE' : 'TAP ${_country(_target!).name.toUpperCase()}';
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

/// The "find this country" prompt chip shown under the map on tap beats.
class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.country, required this.found});

  final BriefingCountry country;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: found
            ? FlitColors.success.withValues(alpha: 0.15)
            : FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: found ? FlitColors.success : FlitColors.gold,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            found ? Icons.check_circle : Icons.travel_explore_rounded,
            size: 18,
            color: found ? FlitColors.success : FlitColors.gold,
          ),
          const SizedBox(width: 8),
          Text(
            found ? 'Found ${country.name}' : 'Find: ${country.name}',
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
