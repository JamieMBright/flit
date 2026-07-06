import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/models/ad_config.dart';
import '../../data/models/h2h_challenge.dart';
import '../../data/providers/account_provider.dart';
import '../../data/providers/subscription_provider.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/challenge_service.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import 'flight_school_screen.dart';
import 'h2h_challenge_screen.dart';

/// Results screen for a completed H2H Flight School challenge.
///
/// Shows all 3 rounds side-by-side with scores, highlights round winners,
/// and displays the overall winner with a celebration effect. Also credits
/// the coin reward exactly once via the `claim_h2h_coins` RPC.
class H2HResultsScreen extends ConsumerStatefulWidget {
  const H2HResultsScreen({super.key, required this.challenge});

  final H2HChallenge challenge;

  @override
  ConsumerState<H2HResultsScreen> createState() => _H2HResultsScreenState();
}

class _H2HResultsScreenState extends ConsumerState<H2HResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _scaleIn;

  /// Coins credited by this visit's claim; null until (and unless) claimed.
  int? _coinsEarned;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _scaleIn = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );
    // Gate the reveal animation behind a (frequency-capped) interstitial: the
    // ad plays first, then the trophy/scale reveal fires. When ads are
    // unavailable/capped/premium the gate is an instant no-op and the reveal
    // plays immediately. Coin claiming is independent and runs right away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _gateThenReveal());
    _claimCoins();
  }

  /// Show the pre-result interstitial (if eligible), then start the reveal.
  Future<void> _gateThenReveal() async {
    if (!mounted) return;
    final adService = ref.read(adServiceProvider);
    final tier = ref.read(adTierProvider);
    await adService.showInterstitial(
      context,
      AdPlacement.preH2HResult,
      tier: tier,
    );
    if (mounted) _animController.forward();
  }

  /// Credit the H2H coin reward to the player's balance.
  ///
  /// The `claim_h2h_coins` RPC atomically marks this player's share as
  /// claimed server-side and returns true exactly once, so re-opening the
  /// screen (or a second device) can never double-credit. If the RPC isn't
  /// deployed the claim silently no-ops and rewards stay display-only.
  Future<void> _claimCoins() async {
    final challenge = widget.challenge;
    if (!challenge.isComplete) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != challenge.challengerId && userId != challenge.challengedId) {
      return;
    }

    final claimed = await ChallengeService.instance.claimH2HCoins(challenge.id);
    if (!claimed || !mounted) return;

    final isChallenger = userId == challenge.challengerId;
    final roundWins =
        isChallenger ? challenge.challengerWins : challenge.challengedWins;
    final isDraw = challenge.winnerId == null;
    final isWinner = challenge.winnerId == userId;

    var coins = H2HChallenge.participationCoins +
        roundWins * H2HChallenge.roundWinCoins;
    if (isWinner) {
      coins += H2HChallenge.winnerCoins;
    } else if (!isDraw) {
      coins += H2HChallenge.loserCoins;
    }

    ref.read(accountProvider.notifier).addCoins(
          coins,
          applyBoost: false,
          source: 'h2h_challenge_reward',
        );
    setState(() => _coinsEarned = coins);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final isDraw = challenge.winnerId == null && challenge.isComplete;
    final winnerName = challenge.winnerName;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: SafeArea(
        child: MenuContentWrapper(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeIn.value,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        // Trophy / result badge
                        _buildResultBadge(isDraw, winnerName),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          isDraw
                              ? 'DRAW'
                              : winnerName != null
                                  ? '$winnerName WINS!'
                                  : 'MATCH COMPLETE',
                          style: TextStyle(
                            color: isDraw
                                ? FlitColors.textSecondary
                                : FlitColors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Matchup subtitle
                        Text(
                          '${challenge.challengerName} vs ${challenge.challengedName}',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Overall score
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: FlitColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: FlitColors.accent.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            challenge.scoreText,
                            style: const TextStyle(
                              color: FlitColors.accent,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                        // Coins credited by this visit's claim.
                        if (_coinsEarned != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    FlitColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: FlitColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '+$_coinsEarned coins earned',
                                  style: const TextStyle(
                                    color: FlitColors.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Round details
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ROUNDS',
                            style: TextStyle(
                              color: FlitColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        for (var i = 0; i < challenge.rounds.length; i++) ...[
                          _RoundResultCard(
                            round: challenge.rounds[i],
                            roundNumber: i + 1,
                            challengerName: challenge.challengerName,
                            challengedName: challenge.challengedName,
                          ),
                          if (i < challenge.rounds.length - 1)
                            const SizedBox(height: 10),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom actions
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge(bool isDraw, String? winnerName) {
    return AnimatedBuilder(
      animation: _scaleIn,
      builder: (context, child) {
        return Transform.scale(scale: _scaleIn.value, child: child);
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDraw
              ? FlitColors.textSecondary.withOpacity(0.15)
              : FlitColors.gold.withOpacity(0.15),
          border: Border.all(
            color: isDraw ? FlitColors.textSecondary : FlitColors.gold,
            width: 3,
          ),
          boxShadow: isDraw
              ? null
              : [
                  BoxShadow(
                    color: FlitColors.gold.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Icon(
          isDraw ? Icons.handshake : Icons.emoji_events,
          color: isDraw ? FlitColors.textSecondary : FlitColors.gold,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const FlightSchoolScreen(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlitColors.textSecondary,
                    side: const BorderSide(color: FlitColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'FLIGHT SCHOOL',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const H2HChallengeScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.replay, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PLAY AGAIN',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Card showing a single round's results with side-by-side scores.
class _RoundResultCard extends StatelessWidget {
  const _RoundResultCard({
    required this.round,
    required this.roundNumber,
    required this.challengerName,
    required this.challengedName,
  });

  final H2HRound round;
  final int roundNumber;
  final String challengerName;
  final String challengedName;

  @override
  Widget build(BuildContext context) {
    final winner = round.winner;
    final challengerWon = winner == 'challenger';
    final challengedWon = winner == 'challenged';
    final isDraw = winner == 'draw';

    Color borderColor;
    if (!round.isComplete) {
      borderColor = FlitColors.cardBorder;
    } else if (isDraw) {
      borderColor = FlitColors.textSecondary.withOpacity(0.5);
    } else {
      borderColor = FlitColors.gold.withOpacity(0.5);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlitColors.accent.withOpacity(0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$roundNumber',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      round.levelName,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${round.category.displayName} - ${round.difficulty.displayName}',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (round.isComplete)
                Icon(
                  isDraw ? Icons.horizontal_rule : Icons.emoji_events,
                  color: isDraw ? FlitColors.textSecondary : FlitColors.gold,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Score comparison
          Row(
            children: [
              // Challenger score
              Expanded(
                child: _buildPlayerScore(
                  name: challengerName,
                  score: round.challengerScore,
                  correct: round.challengerCorrect,
                  wrong: round.challengerWrong,
                  isWinner: challengerWon,
                ),
              ),
              // VS divider
              Container(
                width: 32,
                alignment: Alignment.center,
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Challenged score
              Expanded(
                child: _buildPlayerScore(
                  name: challengedName,
                  score: round.challengedScore,
                  correct: round.challengedCorrect,
                  wrong: round.challengedWrong,
                  isWinner: challengedWon,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerScore({
    required String name,
    required int? score,
    required int? correct,
    required int? wrong,
    required bool isWinner,
    bool alignRight = false,
  }) {
    final align =
        alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          name.length > 12 ? '${name.substring(0, 12)}...' : name,
          textAlign: textAlign,
          style: TextStyle(
            color: isWinner ? FlitColors.gold : FlitColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWinner && !alignRight)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star, color: FlitColors.gold, size: 14),
              ),
            Text(
              score != null ? '$score' : '--',
              style: TextStyle(
                color: isWinner ? FlitColors.gold : FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isWinner && alignRight)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.star, color: FlitColors.gold, size: 14),
              ),
          ],
        ),
        if (correct != null && wrong != null) ...[
          const SizedBox(height: 2),
          Text(
            '$correct correct, $wrong wrong',
            textAlign: textAlign,
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
          ),
        ],
      ],
    );
  }
}
