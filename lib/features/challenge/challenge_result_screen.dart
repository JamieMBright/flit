import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/challenge.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/challenge_service.dart';

/// Data class holding pilot info for display on the result screen.
class PilotInfo {
  const PilotInfo({
    required this.name,
    this.level = 1,
    this.nationality,
    this.equippedPlaneName,
    this.rankTitle,
  });

  final String name;
  final int level;
  final String? nationality;
  final String? equippedPlaneName;
  final String? rankTitle;
}

/// Aviation rank title for a given level (mirrors profile_screen logic).
String _rankTitle(int level) {
  if (level >= 50) return 'Air Marshal';
  if (level >= 40) return 'Wing Commander';
  if (level >= 30) return 'Squadron Leader';
  if (level >= 20) return 'Flight Lieutenant';
  if (level >= 15) return 'Captain';
  if (level >= 10) return 'First Officer';
  if (level >= 5) return 'Pilot Officer';
  if (level >= 3) return 'Cadet';
  return 'Trainee';
}

/// Challenge result screen showing match outcome, pilot licenses, per-round
/// time comparisons, coins earned, and rematch / play again actions.
class ChallengeResultScreen extends ConsumerWidget {
  const ChallengeResultScreen({
    super.key,
    required this.challenge,
    required this.isChallenger,
    this.yourPilotInfo,
    this.opponentPilotInfo,
    this.onRematch,
    this.onPlayAgain,
  });

  final Challenge challenge;
  final bool isChallenger;

  /// Pilot info for the current player. If null, derived from account state.
  final PilotInfo? yourPilotInfo;

  /// Pilot info for the opponent. If null, uses challenge name only.
  final PilotInfo? opponentPilotInfo;

  /// Called when the player taps Rematch. Creates a new challenge with the
  /// same opponent. If null, the rematch button is hidden.
  final VoidCallback? onRematch;

  /// Called when the player taps Play Again. For non-H2H matches, starts a
  /// new solo round. If null, the play again button is hidden.
  final VoidCallback? onPlayAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDraw = challenge.winnerId == null;
    final youWon =
        !isDraw &&
        ((isChallenger && challenge.winnerId == challenge.challengerId) ||
            (!isChallenger && challenge.winnerId == challenge.challengedId));
    final yourWins = isChallenger
        ? challenge.challengerWins
        : challenge.challengedWins;
    final theirWins = isChallenger
        ? challenge.challengedWins
        : challenge.challengerWins;
    final opponentName = isChallenger
        ? challenge.challengedName
        : challenge.challengerName;
    final yourCoins = isChallenger
        ? challenge.challengerCoins
        : challenge.challengedCoins;

    // Build pilot info from account state if not provided externally.
    final account = ref.read(accountProvider);
    final equippedPlaneId = account.equippedPlaneId;
    final equippedPlane = CosmeticCatalog.getById(equippedPlaneId);

    final yourInfo =
        yourPilotInfo ??
        PilotInfo(
          name: 'You',
          level: account.currentPlayer.level,
          nationality: account.license.nationality,
          equippedPlaneName: equippedPlane?.name ?? 'Default',
          rankTitle: _rankTitle(account.currentPlayer.level),
        );

    final opponentInfo = opponentPilotInfo ?? PilotInfo(name: opponentName);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Challenge Complete'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Result header
            _ResultHeader(
              youWon: youWon,
              isDraw: isDraw,
              opponentName: opponentName,
            ),
            const SizedBox(height: 24),
            // Pilot license cards side by side
            _PilotCards(
              yourInfo: yourInfo,
              opponentInfo: opponentInfo,
              youWon: youWon,
              isDraw: isDraw,
            ),
            const SizedBox(height: 24),
            // Score display
            _ScoreDisplay(yourWins: yourWins, theirWins: theirWins),
            const SizedBox(height: 24),
            // Per-round time comparison
            _RoundBreakdown(
              rounds: challenge.rounds,
              isChallenger: isChallenger,
              yourName: yourInfo.name,
              opponentName: opponentInfo.name,
            ),
            const SizedBox(height: 24),
            // Coins earned
            _RewardsDisplay(coins: yourCoins),
            const SizedBox(height: 24),
            // Actions
            _ResultActions(
              onRematch:
                  onRematch ??
                  () {
                    _handleRematch(context, ref);
                  },
              onHome: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              onPlayAgain: onPlayAgain,
            ),
          ],
        ),
      ),
    );
  }

  void _handleRematch(BuildContext context, WidgetRef ref) {
    final account = ref.read(accountProvider);
    final opponentId = isChallenger
        ? challenge.challengedId
        : challenge.challengerId;
    final opponentName = isChallenger
        ? challenge.challengedName
        : challenge.challengerName;
    final myName = account.currentPlayer.name;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: FlitColors.accent),
            SizedBox(height: 16),
            Text(
              'Sending rematch...',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    ChallengeService.instance
        .createChallenge(
          challengedId: opponentId,
          challengedName: opponentName,
          challengerName: myName,
        )
        .then((challengeId) {
          if (context.mounted) {
            Navigator.of(context).pop(); // Dismiss loading dialog
            if (challengeId != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rematch sent to $opponentName!'),
                  backgroundColor: FlitColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to send rematch'),
                  backgroundColor: FlitColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        });
  }
}

// ---------------------------------------------------------------------------
// Result Header
// ---------------------------------------------------------------------------

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.youWon,
    required this.isDraw,
    required this.opponentName,
  });

  final bool youWon;
  final bool isDraw;
  final String opponentName;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        isDraw
            ? Icons.handshake
            : youWon
            ? Icons.emoji_events
            : Icons.sentiment_dissatisfied,
        size: 64,
        color: isDraw
            ? FlitColors.textSecondary
            : youWon
            ? FlitColors.warning
            : FlitColors.textSecondary,
      ),
      const SizedBox(height: 16),
      Text(
        isDraw
            ? 'DRAW'
            : youWon
            ? 'VICTORY!'
            : 'DEFEAT',
        style: TextStyle(
          color: isDraw
              ? FlitColors.textSecondary
              : youWon
              ? FlitColors.warning
              : FlitColors.textSecondary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'vs $opponentName',
        style: const TextStyle(color: FlitColors.textSecondary, fontSize: 16),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Pilot License Cards
// ---------------------------------------------------------------------------

class _PilotCards extends StatelessWidget {
  const _PilotCards({
    required this.yourInfo,
    required this.opponentInfo,
    required this.youWon,
    required this.isDraw,
  });

  final PilotInfo yourInfo;
  final PilotInfo opponentInfo;
  final bool youWon;
  final bool isDraw;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PilotCard(
          info: yourInfo,
          isWinner: !isDraw && youWon,
          label: 'YOU',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _PilotCard(
          info: opponentInfo,
          isWinner: !isDraw && !youWon,
          label: 'OPP',
        ),
      ),
    ],
  );
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({
    required this.info,
    required this.isWinner,
    required this.label,
  });

  final PilotInfo info;
  final bool isWinner;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isWinner ? FlitColors.gold : FlitColors.cardBorder,
        width: isWinner ? 2 : 1,
      ),
    ),
    child: Column(
      children: [
        // Winner crown or label
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWinner)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.emoji_events,
                  color: FlitColors.gold,
                  size: 16,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isWinner ? FlitColors.gold : FlitColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Flag
        if (info.nationality != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 36,
              height: 24,
              child: Flag.fromString(
                info.nationality!,
                height: 24,
                width: 36,
                fit: BoxFit.cover,
                borderRadius: 3,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        // Name
        Text(
          info.name,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Rank / Level
        if (info.rankTitle != null || info.level > 1)
          Text(
            info.rankTitle ?? 'Lv.${info.level}',
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        if (info.level > 1 && info.rankTitle != null)
          Text(
            'Lv.${info.level}',
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
          ),
        // Plane
        if (info.equippedPlaneName != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flight, color: FlitColors.textMuted, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  info.equippedPlaneName!,
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Score Display
// ---------------------------------------------------------------------------

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({required this.yourWins, required this.theirWins});

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
            style: TextStyle(color: FlitColors.textMuted, fontSize: 32),
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

// ---------------------------------------------------------------------------
// Round Breakdown with Side-by-Side Times
// ---------------------------------------------------------------------------

class _RoundBreakdown extends StatelessWidget {
  const _RoundBreakdown({
    required this.rounds,
    required this.isChallenger,
    required this.yourName,
    required this.opponentName,
  });

  final List<ChallengeRound> rounds;
  final bool isChallenger;
  final String yourName;
  final String opponentName;

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
        // Header row
        Row(
          children: [
            const SizedBox(width: 36),
            Expanded(
              child: Text(
                yourName,
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                opponentName,
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: FlitColors.cardBorder, height: 1),
        const SizedBox(height: 8),
        ...rounds
            .where((r) => r.isComplete)
            .map(
              (round) => _RoundRow(round: round, isChallenger: isChallenger),
            ),
        // Total time row
        if (rounds.where((r) => r.isComplete).length > 1) ...[
          const SizedBox(height: 8),
          const Divider(color: FlitColors.cardBorder, height: 1),
          const SizedBox(height: 8),
          _TotalTimeRow(
            rounds: rounds.where((r) => r.isComplete).toList(),
            isChallenger: isChallenger,
          ),
        ],
      ],
    ),
  );
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round, required this.isChallenger});

  final ChallengeRound round;
  final bool isChallenger;

  @override
  Widget build(BuildContext context) {
    final yourTime = isChallenger ? round.challengerTime : round.challengedTime;
    final theirTime = isChallenger
        ? round.challengedTime
        : round.challengerTime;
    final youWon =
        (isChallenger && round.winner == 'challenger') ||
        (!isChallenger && round.winner == 'challenged');
    final draw = round.winner == 'draw';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Round number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: draw
                  ? FlitColors.textMuted
                  : youWon
                  ? FlitColors.success
                  : FlitColors.error,
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
          const SizedBox(width: 8),
          // Your time
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: youWon
                    ? FlitColors.success.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTime(yourTime),
                style: TextStyle(
                  color: youWon ? FlitColors.success : FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: youWon ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Their time
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: !youWon && !draw
                    ? FlitColors.error.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTime(theirTime),
                style: TextStyle(
                  color: !youWon && !draw
                      ? FlitColors.error
                      : FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: !youWon && !draw
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(Duration? time) {
    if (time == null) return '--';
    final seconds = time.inSeconds;
    final millis = (time.inMilliseconds % 1000) ~/ 10;
    return '$seconds.${millis.toString().padLeft(2, '0')}s';
  }
}

class _TotalTimeRow extends StatelessWidget {
  const _TotalTimeRow({required this.rounds, required this.isChallenger});

  final List<ChallengeRound> rounds;
  final bool isChallenger;

  @override
  Widget build(BuildContext context) {
    var yourTotalMs = 0;
    var theirTotalMs = 0;
    for (final r in rounds) {
      final yourTime = isChallenger ? r.challengerTime : r.challengedTime;
      final theirTime = isChallenger ? r.challengedTime : r.challengerTime;
      if (yourTime != null) yourTotalMs += yourTime.inMilliseconds;
      if (theirTime != null) theirTotalMs += theirTime.inMilliseconds;
    }

    final yourTotal = Duration(milliseconds: yourTotalMs);
    final theirTotal = Duration(milliseconds: theirTotalMs);
    final youFaster = yourTotalMs < theirTotalMs;

    return Row(
      children: [
        const SizedBox(
          width: 36,
          child: Text(
            'Total',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _formatTotalTime(yourTotal),
            style: TextStyle(
              color: youFaster ? FlitColors.success : FlitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            _formatTotalTime(theirTotal),
            style: TextStyle(
              color: !youFaster ? FlitColors.error : FlitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  static String _formatTotalTime(Duration time) {
    final m = time.inMinutes;
    final s = time.inSeconds % 60;
    final ms = (time.inMilliseconds % 1000) ~/ 10;
    if (m > 0) {
      return '$m'
          'm $s.${ms.toString().padLeft(2, '0')}s';
    }
    return '$s.${ms.toString().padLeft(2, '0')}s';
  }
}

// ---------------------------------------------------------------------------
// Rewards Display
// ---------------------------------------------------------------------------

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
        const Icon(Icons.monetization_on, color: FlitColors.warning, size: 32),
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
          'coins earned',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 16),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Result Actions
// ---------------------------------------------------------------------------

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onRematch,
    required this.onHome,
    this.onPlayAgain,
  });

  final VoidCallback onRematch;
  final VoidCallback onHome;
  final VoidCallback? onPlayAgain;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: FlitColors.textSecondary,
                side: const BorderSide(color: FlitColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('HOME'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onRematch,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('REMATCH'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      if (onPlayAgain != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPlayAgain,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('PLAY AGAIN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlitColors.accent,
            side: const BorderSide(color: FlitColors.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ],
  );
}
