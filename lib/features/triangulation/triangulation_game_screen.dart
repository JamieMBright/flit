import 'dart:async';
import 'dart:math' as math;

import 'package:flag/flag.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/models/daily_result.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/country_data.dart';
import '../../game/quiz/fuzzy_match.dart';
import '../../game/triangulation/daily_triangulation.dart';
import '../../game/triangulation/triangulation_session.dart';
import '../../game/triangulation/triangulation_share.dart';
import '../../game/triangulation/triangulation_target.dart';
import 'widgets/triangulation_compass.dart';

/// The Triangulation gameplay screen: compass + guess input, round results
/// on a map, and a final summary with spoiler-free share text.
class TriangulationGameScreen extends ConsumerStatefulWidget {
  const TriangulationGameScreen({
    super.key,
    required this.config,
    this.daily,
    this.coinReward = 0,
  });

  final TriangulationConfig config;

  /// Set when playing the daily puzzle — enables the day-number share
  /// header and records completion so the puzzle can't be replayed.
  final DailyTriangulation? daily;

  /// Coins awarded for completing the daily (0 for free play).
  final int coinReward;

  @override
  ConsumerState<TriangulationGameScreen> createState() =>
      _TriangulationGameScreenState();
}

/// One entry the player can type/tap: either a country or its capital.
class _GuessCandidate {
  const _GuessCandidate({
    required this.code,
    required this.display,
    required this.viaCapital,
  });

  final String code;
  final String display;
  final bool viaCapital;
}

class _TriangulationGameScreenState
    extends ConsumerState<TriangulationGameScreen> {
  late final TriangulationSession _session;
  late final FuzzyMatcher _countryMatcher;
  FuzzyMatcher? _capitalMatcher;
  late final List<_GuessCandidate> _candidates;

  bool get _isCapitalTarget =>
      widget.config.targetType == TriTargetType.capital;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  bool _showingRoundResult = false;
  bool _finished = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _session = TriangulationSession(widget.config);

    final eligible = CountryData.playableCountries
        .where((c) => CountryData.getCapital(c.code) != null)
        .toList();
    _countryMatcher = FuzzyMatcher({for (final c in eligible) c.code: c.name});
    // On country-target days capitals are not answer candidates at all —
    // only country names count.
    if (_isCapitalTarget) {
      _capitalMatcher = FuzzyMatcher({
        for (final c in eligible) c.code: CountryData.getCapital(c.code)!.name,
      });
    }
    _candidates = [
      for (final c in eligible) ...[
        _GuessCandidate(code: c.code, display: c.name, viaCapital: false),
        if (_isCapitalTarget)
          _GuessCandidate(
            code: c.code,
            display: CountryData.getCapital(c.code)!.name,
            viaCapital: true,
          ),
      ],
    ];

    _stopwatch.start();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Set<String> get _guessedCodes =>
      _session.currentRound.guesses.map((g) => g.countryCode).toSet();

  List<_GuessCandidate> _suggestionsFor(String input) {
    final query = input.trim().toLowerCase();
    if (query.length < 2) return const [];
    final guessed = _guessedCodes;
    final starts = <_GuessCandidate>[];
    final contains = <_GuessCandidate>[];
    for (final c in _candidates) {
      if (guessed.contains(c.code)) continue;
      final name = c.display.toLowerCase();
      if (name.startsWith(query)) {
        starts.add(c);
      } else if (name.contains(query)) {
        contains.add(c);
      }
    }
    return [...starts, ...contains].take(6).toList();
  }

  void _submitTyped(String input) {
    if (input.trim().isEmpty) return;
    // Prefer capital matches (full points), then country names; both
    // matchers are typo-tolerant with alias support. On country-target
    // days there is no capital matcher — only country names resolve.
    final capitalMatch =
        _capitalMatcher?.bestMatch(input, excludeCodes: _guessedCodes);
    final countryMatch =
        _countryMatcher.bestMatch(input, excludeCodes: _guessedCodes);
    _GuessCandidate? chosen;
    if (capitalMatch != null &&
        (countryMatch == null ||
            capitalMatch.distance <= countryMatch.distance)) {
      chosen = _GuessCandidate(
        code: capitalMatch.code,
        display: capitalMatch.canonicalName,
        viaCapital: true,
      );
    } else if (countryMatch != null) {
      chosen = _GuessCandidate(
        code: countryMatch.code,
        display: countryMatch.canonicalName,
        viaCapital: false,
      );
    }
    if (chosen == null) {
      setState(
        () => _feedback = _isCapitalTarget
            ? 'No country or capital matches "$input"'
            : 'No country matches "$input"',
      );
      return;
    }
    _submitCandidate(chosen);
  }

  void _submitCandidate(_GuessCandidate candidate) {
    if (_session.currentRound.isOver) return;
    final guess = _session.submitGuess(
      candidate.code,
      viaCapital: candidate.viaCapital,
      elapsedMs: _stopwatch.elapsedMilliseconds,
    );
    _inputController.clear();
    if (guess.isCorrect) {
      hapticSuccess();
    } else {
      hapticLight();
    }
    setState(() {
      _feedback = guess.isCorrect
          ? null
          : '${proximityEmoji(guess.distanceKm)} '
              '${guess.viaCapital ? guess.capitalName : guess.countryName}'
              ' — not it';
      if (_session.currentRound.isOver) {
        _stopwatch.stop();
        _showingRoundResult = true;
        _feedback = null;
      }
    });
  }

  Future<void> _continueFromResult() async {
    if (_session.isLastRound) {
      await _recordDailyResult();
      setState(() {
        _showingRoundResult = false;
        _finished = true;
      });
      return;
    }
    _session.advanceRound();
    _stopwatch
      ..reset()
      ..start();
    setState(() => _showingRoundResult = false);
  }

  Future<void> _recordDailyResult() async {
    final daily = widget.daily;
    if (daily == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'daily_triangulation_${daily.dateKey}',
      buildTriangulationShareText(_session, dayNumber: daily.dayNumber),
    );
    await prefs.setInt(
      'daily_triangulation_score_${daily.dateKey}',
      _session.totalScore,
    );
    // Server-side parity with the other dailies: persist the score row
    // (region 'daily_triangulation') and award the completion coins.
    // Solving at least one round counts as completing the daily.
    await ref.read(accountProvider.notifier).recordGameCompletion(
          elapsed: Duration(milliseconds: _session.totalTimeMs),
          score: _session.totalScore,
          roundsCompleted: _session.solvedRounds,
          coinReward: _session.solvedRounds > 0 ? widget.coinReward : 0,
          region: 'daily_triangulation',
          roundEmojis: _session.rounds
              .map(
                (r) =>
                    r.wrongGuesses
                        .map((g) => proximityEmoji(g.distanceKm))
                        .join() +
                    (r.solved ? '✅' : '❌'),
              )
              .join(' '),
        );
  }

  String get _shareText => buildTriangulationShareText(
        _session,
        dayNumber: widget.daily?.dayNumber ?? 0,
      );

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_finished) {
      body = _SummaryView(
        session: _session,
        shareText: _shareText,
        isDaily: widget.daily != null,
        isCapitalTarget: _isCapitalTarget,
        coinsEarned: _session.solvedRounds > 0 ? widget.coinReward : 0,
      );
    } else if (_showingRoundResult) {
      body = _RoundResultView(
        state: _session.currentRound,
        isLastRound: _session.isLastRound,
        isCapitalTarget: _isCapitalTarget,
        onContinue: _continueFromResult,
      );
    } else {
      body = _buildPlayView();
    }

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text(
          widget.daily != null ? 'Daily Triangulation' : 'Triangulation',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(child: MenuContentWrapper(child: body)),
    );
  }

  Widget _buildPlayView() {
    final state = _session.currentRound;
    final suggestions = _suggestionsFor(_inputController.text);
    final seconds = _stopwatch.elapsedMilliseconds ~/ 1000;

    return Column(
      children: [
        _StatusBar(
          roundNumber: _session.currentRoundNumber,
          totalRounds: _session.rounds.length,
          guessesRemaining: _session.guessesRemaining,
          totalGuesses: widget.config.guessesPerRound,
          seconds: seconds,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                TriangulationCompass(
                  clues: state.round.clues,
                  wrongGuesses: state.wrongGuesses,
                  clueTypes: widget.config.clueTypes,
                  labelTypes: widget.config.labelTypes,
                  centerLabel: _isCapitalTarget ? 'CAPITAL' : 'COUNTRY',
                ),
                const SizedBox(height: 4),
                Text(
                  'Arrows point from the hidden '
                  '${_isCapitalTarget ? 'capital' : 'country'} '
                  'toward each place',
                  style: TextStyle(
                    color: FlitColors.textMuted.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_feedback != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _feedback!,
              style: const TextStyle(
                color: FlitColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (suggestions.isNotEmpty)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6),
                    child: ActionChip(
                      backgroundColor: FlitColors.cardBackground,
                      side: BorderSide(
                        color: s.viaCapital
                            ? FlitColors.gold.withOpacity(0.6)
                            : FlitColors.cardBorder,
                      ),
                      label: Text(
                        s.viaCapital ? '${s.display} ★' : s.display,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () => _submitCandidate(s),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  onChanged: (_) => setState(() => _feedback = null),
                  onSubmitted: _submitTyped,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(color: FlitColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isCapitalTarget
                        ? 'Capital (full pts) or country (×0.7)…'
                        : 'Name the country…',
                    hintStyle: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: FlitColors.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FlitColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FlitColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: FlitColors.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => _submitTyped(_inputController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.explore),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Status bar: round, guesses, timer
// ─────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.roundNumber,
    required this.totalRounds,
    required this.guessesRemaining,
    required this.totalGuesses,
    required this.seconds,
  });

  final int roundNumber;
  final int totalRounds;
  final int guessesRemaining;
  final int totalGuesses;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    // Full points inside 10s, decaying to 60s — tint the timer to match.
    final timerColor = seconds <= 10
        ? FlitColors.success
        : seconds < 60
            ? FlitColors.warning
            : FlitColors.error;
    return Container(
      color: FlitColors.backgroundMid,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ROUND $roundNumber/$totalRounds',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < totalGuesses; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < guessesRemaining
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 12,
                    color: i < guessesRemaining
                        ? FlitColors.accent
                        : FlitColors.textMuted,
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: timerColor),
              const SizedBox(width: 4),
              Text(
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: timerColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Round result: answer revealed on a map
// ─────────────────────────────────────────────────────────────────────────

class _RoundResultView extends StatelessWidget {
  const _RoundResultView({
    required this.state,
    required this.isLastRound,
    required this.isCapitalTarget,
    required this.onContinue,
  });

  final TriangulationRoundState state;
  final bool isLastRound;
  final bool isCapitalTarget;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final round = state.round;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  state.solved ? 'TRIANGULATED!' : 'TARGET LOST',
                  style: TextStyle(
                    color: state.solved ? FlitColors.success : FlitColors.error,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (round.targetCountryCode.length == 2 &&
                        !round.targetCountryCode.startsWith('X'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Flag.fromString(
                          round.targetCountryCode,
                          height: 30,
                          width: 45,
                          fit: BoxFit.contain,
                          borderRadius: 4,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lead with whatever the player was hunting.
                        Text(
                          isCapitalTarget
                              ? round.targetCapitalName
                              : round.targetCountryName,
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isCapitalTarget
                              ? round.targetCountryName
                              : round.targetCapitalName,
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // The reveal: world map with the target and every guess.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: FlitColors.backgroundMid,
                    child: AspectRatio(
                      aspectRatio: 2,
                      child: CustomPaint(
                        painter: _ResultMapPainter(
                          targetLngLat: round.targetCapitalLngLat,
                          guesses: state.wrongGuesses,
                          clues: round.clues,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Map legend.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: FlitColors.gold, size: 13),
                    const SizedBox(width: 3),
                    const Text(
                      'answer',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.circle_outlined,
                      color: FlitColors.accent,
                      size: 11,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'clues',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (state.wrongGuesses.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.circle,
                        color: FlitColors.error,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'your guesses',
                        style: TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (state.wrongGuesses.isNotEmpty)
                  Column(
                    children: [
                      for (final g in state.wrongGuesses)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                proximityEmoji(g.distanceKm),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${g.countryName} — '
                                '${g.distanceKm.round()} km away',
                                style: const TextStyle(
                                  color: FlitColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  '+${DailyResult.formatScore(state.score)} pts',
                  style: TextStyle(
                    color:
                        state.solved ? FlitColors.gold : FlitColors.textMuted,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (state.solved && state.solvedAsCountry)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Solved by country name (×0.7)',
                      style: TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isLastRound ? 'SEE RESULTS' : 'NEXT ROUND',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Equirectangular world map with the target capital (gold star), each
/// wrong guess (red dot), and the round's original clue anchors (accent
/// ringed dots) so the reveal shows the full triangulation picture.
class _ResultMapPainter extends CustomPainter {
  _ResultMapPainter({
    required this.targetLngLat,
    required this.guesses,
    required this.clues,
  });

  final Vector2 targetLngLat;
  final List<TriangulationGuess> guesses;
  final List<TriangulationClue> clues;

  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.45);
    final borderPaint = Paint()
      ..color = FlitColors.border.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    Offset project(double lng, double lat) => Offset(
          (lng + 180) / 360 * size.width,
          (90 - lat) / 180 * size.height,
        );

    for (final country in CountryData.countries) {
      for (final poly in country.polygons) {
        if (poly.length < 3) continue;
        final path = Path();
        for (var i = 0; i < poly.length; i++) {
          final pt = project(poly[i].x, poly[i].y);
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, landPaint);
        canvas.drawPath(path, borderPaint);
      }
    }

    final target = project(targetLngLat.x, targetLngLat.y);

    // Original clue anchors: accent ringed dots with a faint line to the
    // target, so the reveal shows what the arrows were pointing at.
    for (final clue in clues) {
      final pos = project(clue.capitalLngLat.x, clue.capitalLngLat.y);
      canvas.drawLine(
        pos,
        target,
        Paint()
          ..color = FlitColors.textSecondary.withOpacity(0.3)
          ..strokeWidth = 0.8,
      );
      canvas.drawCircle(
        pos,
        3,
        Paint()..color = FlitColors.backgroundDark,
      );
      canvas.drawCircle(
        pos,
        3,
        Paint()
          ..color = FlitColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Guess dots + connector lines toward the target.
    for (final g in guesses) {
      final pos = project(g.capitalLngLat.x, g.capitalLngLat.y);
      canvas.drawLine(
        pos,
        target,
        Paint()
          ..color = FlitColors.error.withOpacity(0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(pos, 3.5, Paint()..color = FlitColors.error);
    }

    // Target star.
    _drawStar(canvas, target, 7, Paint()..color = FlitColors.gold);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pt =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ResultMapPainter old) =>
      targetLngLat != old.targetLngLat ||
      guesses.length != old.guesses.length ||
      clues.length != old.clues.length;
}

// ─────────────────────────────────────────────────────────────────────────
// Final summary + share
// ─────────────────────────────────────────────────────────────────────────

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.session,
    required this.shareText,
    required this.isDaily,
    required this.isCapitalTarget,
    this.coinsEarned = 0,
  });

  final TriangulationSession session;
  final String shareText;
  final bool isDaily;
  final bool isCapitalTarget;
  final int coinsEarned;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.explore, color: FlitColors.gold, size: 44),
                const SizedBox(height: 10),
                Text(
                  '${session.solvedRounds}/${session.rounds.length} '
                  'TRIANGULATED',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < session.rounds.length; i++)
                  _roundRow(i, session.rounds[i]),
                const SizedBox(height: 18),
                Text(
                  '${DailyResult.formatScore(session.totalScore)} pts',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Time: ${DailyResult.formatTime(session.totalTimeMs)}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (coinsEarned > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: FlitColors.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$coinsEarned coins',
                        style: const TextStyle(
                          color: FlitColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (isDaily)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result copied — paste to share!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'SHARE RESULT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.gold,
                      foregroundColor: FlitColors.backgroundDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (isDaily) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.cardBackground,
                    foregroundColor: FlitColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: FlitColors.cardBorder),
                    ),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundRow(int index, TriangulationRoundState state) {
    final squares = StringBuffer();
    for (final g in state.guesses.where((g) => !g.isCorrect)) {
      squares.write(proximityEmoji(g.distanceKm));
    }
    squares.write(state.solved ? '✅' : '❌');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              isCapitalTarget
                  ? state.round.targetCapitalName
                  : state.round.targetCountryName,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(squares.toString(), style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              '${DailyResult.formatScore(state.score)} pts',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
