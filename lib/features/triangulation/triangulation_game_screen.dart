import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/report_capture.dart';
import '../../core/widgets/country_flag.dart';
import '../../core/widgets/mission_report_card.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../core/widgets/reveal_map.dart';
import '../../data/models/daily_result.dart';
import '../../data/providers/account_provider.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/country_data.dart';
import '../../game/quiz/fuzzy_match.dart';
import '../../game/triangulation/daily_triangulation.dart';
import '../../game/triangulation/triangulation_session.dart';
import '../../game/triangulation/triangulation_scoring.dart';
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

  /// Whether this config produces markers with tap-to-open detail cards
  /// (collapsed dense boxes, or borders lists that may be truncated).
  bool get _hasInspectableMarkers {
    final types = widget.config.clueTypes;
    final labels = widget.config.labelTypes;
    var lines = labels.length;
    if (types.contains(ClueType.capital) &&
        !labels.contains(TriLabel.capital)) {
      lines++;
    }
    if (types.contains(ClueType.borders)) lines++;
    return lines > 2 || types.contains(ClueType.borders);
  }

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  bool _showingRoundResult = false;
  bool _finished = false;
  String? _feedback;

  /// Clue marker currently expanded into the detail card, if any.
  int? _inspectedClueIndex;

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

  void _useDistanceHint() {
    if (_session.currentRound.isOver || _session.currentRound.hintUsed) {
      return;
    }
    hapticLight();
    setState(() => _session.useDistanceHint());
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
    setState(() {
      _showingRoundResult = false;
      _inspectedClueIndex = null;
    });
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
        dayNumber: widget.daily?.dayNumber,
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
          widget.daily != null ? 'Daily Recon' : 'Recon',
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
                  showClueDistances: state.hintUsed,
                  selectedClueIndex: _inspectedClueIndex,
                  onClueTap: (i) => setState(
                    () => _inspectedClueIndex =
                        _inspectedClueIndex == i ? null : i,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Arrows point from the hidden '
                  '${_isCapitalTarget ? 'capital' : 'country'} '
                  'toward each place'
                  '${_hasInspectableMarkers ? ' · tap a marker for details' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FlitColors.textMuted.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
                if (_inspectedClueIndex != null &&
                    _inspectedClueIndex! < state.round.clues.length) ...[
                  const SizedBox(height: 8),
                  TriangulationClueDetailCard(
                    clue: state.round.clues[_inspectedClueIndex!],
                    clueTypes: widget.config.clueTypes,
                    labelTypes: widget.config.labelTypes,
                    showDistance: state.hintUsed,
                    onClose: () => setState(() => _inspectedClueIndex = null),
                  ),
                ],
                const SizedBox(height: 8),
                if (!state.hintUsed)
                  OutlinedButton.icon(
                    onPressed: _useDistanceHint,
                    icon: const Icon(
                      Icons.straighten_rounded,
                      size: 16,
                      color: FlitColors.gold,
                    ),
                    label: Text(
                      'Reveal clue distances  −${triDistanceHintPenalty} pts',
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: FlitColors.gold.withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // These trailing children are keyed because the feedback banner and
        // suggestion strip appear/disappear WHILE the player is typing.
        // Without keys, positional reconciliation re-inflates the TextField
        // when an earlier sibling vanishes (first keystroke clears the
        // feedback banner), which closes the keyboard on iOS/Android.
        if (_feedback != null)
          Padding(
            key: const ValueKey('tri-feedback'),
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
            key: const ValueKey('tri-suggestions'),
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
          key: const ValueKey('tri-guess-input'),
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
    // Tint the timer to mirror the scoring curve: green in the grace
    // window, amber while decaying, red once the penalty saturates.
    final timerColor = seconds <= triTimeGraceSeconds
        ? FlitColors.success
        : seconds < triTimeMaxSeconds
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
                  state.solved ? 'TARGET LOCATED!' : 'TARGET LOST',
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
                    CountryFlag(
                      code: round.targetCountryCode,
                      height: 30,
                      width: 45,
                      borderRadius: 4,
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
                // The reveal: shared world map with the target, the
                // original clue anchors, and every wrong guess.
                RevealMap(
                  targetLngLat: round.targetCapitalLngLat,
                  clueLngLats: [
                    for (final c in round.clues) c.capitalLngLat,
                  ],
                  guessLngLats: [
                    for (final g in state.wrongGuesses) g.capitalLngLat,
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
                if (state.hintUsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Distance hint used (−$triDistanceHintPenalty)',
                      style: const TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────
// Final summary + share
// ─────────────────────────────────────────────────────────────────────────

class _SummaryView extends StatefulWidget {
  const _SummaryView({
    required this.session,
    required this.shareText,
    required this.isDaily,
    required this.isCapitalTarget,
    this.dayNumber,
    this.coinsEarned = 0,
  });

  final TriangulationSession session;
  final String shareText;
  final bool isDaily;
  final bool isCapitalTarget;
  final int? dayNumber;
  final int coinsEarned;

  @override
  State<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<_SummaryView> {
  /// Wraps the report-card preview for PNG capture.
  final GlobalKey _reportKey = GlobalKey();
  bool _savingImage = false;

  TriangulationSession get session => widget.session;
  bool get isDaily => widget.isDaily;
  bool get isCapitalTarget => widget.isCapitalTarget;
  String get shareText => widget.shareText;
  int get coinsEarned => widget.coinsEarned;

  Future<void> _saveImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      final png = await captureReportPng(_reportKey);
      if (png == null || !mounted) return;
      await shareReportImage(
        context,
        png: png,
        filename: isDaily
            ? 'flit-recon-day${widget.dayNumber ?? 0}.png'
            : 'flit-recon.png',
        fallbackText: shareText,
      );
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  Widget _buildReportCard() {
    return RepaintBoundary(
      key: _reportKey,
      child: MissionReportCard(
        modeTitle: isDaily ? 'DAILY RECON' : 'RECON',
        subtitle: [
          if (widget.dayNumber != null) 'Day ${widget.dayNumber}',
          '${isCapitalTarget ? 'capital' : 'country'} targets',
        ].join(' · '),
        score: session.totalScore,
        emojiGrid: triangulationEmojiGrid(session),
        stats: [
          ReportStat(
            'SOLVED',
            '${session.solvedRounds}/${session.rounds.length}',
          ),
          ReportStat('TIME', DailyResult.formatTime(session.totalTimeMs)),
          if (coinsEarned > 0) ReportStat('COINS', '+$coinsEarned'),
        ],
      ),
    );
  }

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
                  'TARGETS FOUND',
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
                const SizedBox(height: 18),
                // Downloadable mission report — captured exactly as shown.
                _buildReportCard(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  if (isDaily) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Result copied — paste to share!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text(
                            'SHARE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
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
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _savingImage ? null : _saveImage,
                        icon: _savingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FlitColors.backgroundDark,
                                ),
                              )
                            : const Icon(Icons.image_outlined, size: 18),
                        label: const Text(
                          'SAVE IMAGE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlitColors.accent,
                          foregroundColor: FlitColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
