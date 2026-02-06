import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/challenge.dart';

/// Challenge result screen showing match outcome and route replay.
class ChallengeResultScreen extends StatelessWidget {
  const ChallengeResultScreen({
    super.key,
    required this.challenge,
    required this.isChallenger,
  });

  final Challenge challenge;
  final bool isChallenger;

  @override
  Widget build(BuildContext context) {
    final youWon = (isChallenger && challenge.winnerId == challenge.challengerId) ||
        (!isChallenger && challenge.winnerId == challenge.challengedId);
    final yourWins = isChallenger ? challenge.challengerWins : challenge.challengedWins;
    final theirWins = isChallenger ? challenge.challengedWins : challenge.challengerWins;
    final opponentName = isChallenger ? challenge.challengedName : challenge.challengerName;
    final yourCoins = isChallenger ? challenge.challengerCoins : challenge.challengedCoins;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Challenge Complete'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Result header
            _ResultHeader(youWon: youWon, opponentName: opponentName),
            const SizedBox(height: 24),
            // Score
            _ScoreDisplay(yourWins: yourWins, theirWins: theirWins),
            const SizedBox(height: 24),
            // Route map placeholder
            _RouteMapPlaceholder(),
            const SizedBox(height: 24),
            // Round breakdown
            _RoundBreakdown(
              rounds: challenge.rounds,
              isChallenger: isChallenger,
            ),
            const SizedBox(height: 24),
            // Rewards
            _RewardsDisplay(coins: yourCoins),
            const SizedBox(height: 24),
            // Actions
            _ResultActions(
              onRematch: () {
                // TODO: Send rematch
              },
              onHome: () => Navigator.of(context).popUntil(
                (route) => route.isFirst,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.youWon,
    required this.opponentName,
  });

  final bool youWon;
  final String opponentName;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(
            youWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 64,
            color: youWon ? FlitColors.warning : FlitColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            youWon ? 'VICTORY!' : 'DEFEAT',
            style: TextStyle(
              color: youWon ? FlitColors.warning : FlitColors.textSecondary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'vs $opponentName',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      );
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({
    required this.yourWins,
    required this.theirWins,
  });

  final int yourWins;
  final int theirWins;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              yourWins.toString(),
              style: TextStyle(
                color: yourWins > theirWins
                    ? FlitColors.success
                    : FlitColors.textPrimary,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '-',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 32,
                ),
              ),
            ),
            Text(
              theirWins.toString(),
              style: TextStyle(
                color: theirWins > yourWins
                    ? FlitColors.error
                    : FlitColors.textPrimary,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

class _RouteMapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        decoration: BoxDecoration(
          color: FlitColors.backgroundMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map,
                size: 48,
                color: FlitColors.textMuted,
              ),
              SizedBox(height: 8),
              Text(
                'Route Replay',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 14,
                ),
              ),
              Text(
                '(Coming soon)',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
}

class _RoundBreakdown extends StatelessWidget {
  const _RoundBreakdown({
    required this.rounds,
    required this.isChallenger,
  });

  final List<ChallengeRound> rounds;
  final bool isChallenger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Round Breakdown',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...rounds
                .where((r) => r.isComplete)
                .map((round) => _RoundRow(
                      round: round,
                      isChallenger: isChallenger,
                    )),
          ],
        ),
      );
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.round,
    required this.isChallenger,
  });

  final ChallengeRound round;
  final bool isChallenger;

  @override
  Widget build(BuildContext context) {
    final yourTime = isChallenger ? round.challengerTime : round.challengedTime;
    final theirTime = isChallenger ? round.challengedTime : round.challengerTime;
    final youWon = (isChallenger && round.winner == 'challenger') ||
        (!isChallenger && round.winner == 'challenged');

    String formatTime(Duration? time) {
      if (time == null) return '--';
      final seconds = time.inSeconds;
      final millis = (time.inMilliseconds % 1000) ~/ 10;
      return '$seconds.${millis.toString().padLeft(2, '0')}s';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Round number
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: youWon ? FlitColors.success : FlitColors.error,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                round.roundNumber.toString(),
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Your time
          Expanded(
            child: Text(
              'You: ${formatTime(yourTime)}',
              style: TextStyle(
                color: youWon ? FlitColors.success : FlitColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          // Their time
          Text(
            'Them: ${formatTime(theirTime)}',
            style: TextStyle(
              color: !youWon ? FlitColors.error : FlitColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsDisplay extends StatelessWidget {
  const _RewardsDisplay({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.monetization_on,
              color: FlitColors.warning,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              '+$coins',
              style: const TextStyle(
                color: FlitColors.warning,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'coins',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onRematch,
    required this.onHome,
  });

  final VoidCallback onRematch;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: FlitColors.textSecondary,
                side: const BorderSide(color: FlitColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('HOME'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: onRematch,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('REMATCH'),
            ),
          ),
        ],
      );
}
