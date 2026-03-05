import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/h2h_challenge.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/challenge_service.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_session.dart';
import 'h2h_results_screen.dart';
import 'quiz_game_screen.dart';

/// Screen for creating and viewing H2H Flight School challenges.
///
/// Tab 1: Create Challenge - pick 3 rounds, enter opponent username, send.
/// Tab 2: My Challenges - list of sent/received challenges with status.
class H2HChallengeScreen extends ConsumerStatefulWidget {
  const H2HChallengeScreen({super.key});

  @override
  ConsumerState<H2HChallengeScreen> createState() => _H2HChallengeScreenState();
}

class _H2HChallengeScreenState extends ConsumerState<H2HChallengeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Head-to-Head',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FlitColors.accent,
          labelColor: FlitColors.accent,
          unselectedLabelColor: FlitColors.textSecondary,
          tabs: const [
            Tab(text: 'CREATE', icon: Icon(Icons.add_circle_outline, size: 20)),
            Tab(text: 'MY CHALLENGES', icon: Icon(Icons.list_alt, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_CreateChallengeTab(), _MyChallengesTab()],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Create Challenge
// =============================================================================

class _CreateChallengeTab extends ConsumerStatefulWidget {
  const _CreateChallengeTab();

  @override
  ConsumerState<_CreateChallengeTab> createState() =>
      _CreateChallengeTabState();
}

class _CreateChallengeTabState extends ConsumerState<_CreateChallengeTab> {
  final _usernameController = TextEditingController();
  bool _isSending = false;
  String? _error;

  // 3 round configs
  final List<_RoundConfig> _rounds = List.generate(3, (_) => _RoundConfig());

  /// Unlocked levels for the current player.
  List<FlightSchoolLevel> get _unlockedLevels {
    final playerLevel = ref.read(accountProvider).currentPlayer.level;
    return flightSchoolLevels
        .where((l) => playerLevel >= l.requiredLevel)
        .toList();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlockedLevels = _unlockedLevels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FlitColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sports_mma,
                    color: FlitColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Best of 3',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick 3 rounds and challenge a friend',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Round configs
          for (var i = 0; i < 3; i++) ...[
            _RoundConfigCard(
              roundNumber: i + 1,
              config: _rounds[i],
              unlockedLevels: unlockedLevels,
              onChanged: (config) => setState(() => _rounds[i] = config),
            ),
            if (i < 2) const SizedBox(height: 12),
          ],

          const SizedBox(height: 20),

          // Opponent username
          const Text(
            'OPPONENT',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: FlitColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter username...',
              hintStyle: const TextStyle(color: FlitColors.textMuted),
              prefixIcon: const Icon(
                Icons.person_search,
                color: FlitColors.textSecondary,
              ),
              filled: true,
              fillColor: FlitColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FlitColors.accent),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: FlitColors.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 20),

          // Send button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                disabledBackgroundColor: FlitColors.accent.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: FlitColors.textPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SEND CHALLENGE',
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _sendChallenge() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    final rng = Random();
    final challengerName =
        ref.read(accountProvider).currentPlayer.displayName ??
        ref.read(accountProvider).currentPlayer.username;

    final h2hRounds = _rounds.map((config) {
      return H2HRound(
        levelId: config.level.id,
        levelName: config.level.name,
        category: config.category,
        difficulty: config.difficulty,
        seed: rng.nextInt(1 << 31),
      );
    }).toList();

    final challengeId = await ChallengeService.instance.createH2HChallenge(
      challengedUsername: username,
      challengerName: challengerName,
      rounds: h2hRounds,
    );

    if (!mounted) return;

    if (challengeId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlitColors.success,
          content: Text('Challenge sent to $username!'),
        ),
      );
      _usernameController.clear();
      setState(() => _isSending = false);
    } else {
      setState(() {
        _isSending = false;
        _error = 'User not found or challenge failed. Check the username.';
      });
    }
  }
}

/// Mutable round configuration used during challenge creation.
class _RoundConfig {
  FlightSchoolLevel level = flightSchoolLevels.first;
  QuizCategory category = QuizCategory.mixed;
  QuizDifficulty difficulty = QuizDifficulty.medium;
}

/// Card widget for configuring a single H2H round.
class _RoundConfigCard extends StatelessWidget {
  const _RoundConfigCard({
    required this.roundNumber,
    required this.config,
    required this.unlockedLevels,
    required this.onChanged,
  });

  final int roundNumber;
  final _RoundConfig config;
  final List<FlightSchoolLevel> unlockedLevels;
  final ValueChanged<_RoundConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlitColors.accent.withOpacity(0.15),
                  border: Border.all(color: FlitColors.accent, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$roundNumber',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Round $roundNumber',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Level selector
          _buildDropdown<FlightSchoolLevel>(
            context: context,
            label: 'Region',
            value: config.level,
            items: unlockedLevels,
            itemLabel: (l) => l.name,
            onChanged: (level) {
              if (level == null) return;
              final newConfig = _RoundConfig()
                ..level = level
                ..category = level.availableCategories.contains(config.category)
                    ? config.category
                    : QuizCategory.mixed
                ..difficulty = config.difficulty;
              onChanged(newConfig);
            },
          ),
          const SizedBox(height: 8),

          // Category selector
          _buildDropdown<QuizCategory>(
            context: context,
            label: 'Category',
            value: config.category,
            items: config.level.availableCategories,
            itemLabel: (c) => c.displayName,
            onChanged: (cat) {
              if (cat == null) return;
              final newConfig = _RoundConfig()
                ..level = config.level
                ..category = cat
                ..difficulty = config.difficulty;
              onChanged(newConfig);
            },
          ),
          const SizedBox(height: 8),

          // Difficulty selector
          _buildDropdown<QuizDifficulty>(
            context: context,
            label: 'Difficulty',
            value: config.difficulty,
            items: QuizDifficulty.values,
            itemLabel: (d) => d.displayName,
            onChanged: (diff) {
              if (diff == null) return;
              final newConfig = _RoundConfig()
                ..level = config.level
                ..category = config.category
                ..difficulty = diff;
              onChanged(newConfig);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FlitColors.cardBorder.withOpacity(0.6)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: items.contains(value) ? value : items.first,
                isExpanded: true,
                dropdownColor: FlitColors.backgroundMid,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Tab 2: My Challenges
// =============================================================================

class _MyChallengesTab extends ConsumerStatefulWidget {
  const _MyChallengesTab();

  @override
  ConsumerState<_MyChallengesTab> createState() => _MyChallengesTabState();
}

class _MyChallengesTabState extends ConsumerState<_MyChallengesTab> {
  List<H2HChallenge>? _challenges;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    final challenges = await ChallengeService.instance.fetchMyH2HChallenges();
    if (mounted) {
      setState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: FlitColors.accent),
      );
    }

    final challenges = _challenges ?? [];
    if (challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_mma,
              size: 56,
              color: FlitColors.textMuted.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No challenges yet',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create one to get started!',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final userId = ref.read(accountProvider).currentPlayer.id;

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      color: FlitColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          final challenge = challenges[index];
          return _ChallengeListItem(
            challenge: challenge,
            currentUserId: userId,
            onTap: () => _onChallengeTap(challenge),
          );
        },
      ),
    );
  }

  void _onChallengeTap(H2HChallenge challenge) {
    final userId = ref.read(accountProvider).currentPlayer.id;
    final isChallenger = challenge.challengerId == userId;
    final isChallenged = challenge.challengedId == userId;

    switch (challenge.status) {
      case H2HStatus.pending:
        if (isChallenged) {
          _showAcceptDeclineDialog(challenge);
        }
        break;
      case H2HStatus.inProgress:
        _navigateToNextRound(challenge, isChallenger);
        break;
      case H2HStatus.completed:
        _navigateToResults(challenge);
        break;
      case H2HStatus.declined:
      case H2HStatus.expired:
        break;
    }
  }

  void _showAcceptDeclineDialog(H2HChallenge challenge) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Challenge Received',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${challenge.challengerName} challenges you!',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < challenge.rounds.length; i++) ...[
              Text(
                'Round ${i + 1}: ${challenge.rounds[i].levelName} '
                '(${challenge.rounds[i].category.displayName}, '
                '${challenge.rounds[i].difficulty.displayName})',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              if (i < challenge.rounds.length - 1) const SizedBox(height: 4),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ChallengeService.instance.declineH2HChallenge(challenge.id);
              _loadChallenges();
            },
            child: const Text(
              'DECLINE',
              style: TextStyle(color: FlitColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ChallengeService.instance.acceptH2HChallenge(challenge.id);
              await _loadChallenges();
              // Navigate to the first round
              final updated = await ChallengeService.instance.fetchH2HChallenge(
                challenge.id,
              );
              if (updated != null && mounted) {
                final isChallenger =
                    updated.challengerId ==
                    ref.read(accountProvider).currentPlayer.id;
                _navigateToNextRound(updated, isChallenger);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
            ),
            child: const Text(
              'ACCEPT',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToNextRound(H2HChallenge challenge, bool isChallenger) {
    // Find the next round that this player hasn't completed.
    int? nextIndex;
    for (var i = 0; i < challenge.rounds.length; i++) {
      final round = challenge.rounds[i];
      final hasPlayed = isChallenger
          ? round.challengerPlayed
          : round.challengedPlayed;
      if (!hasPlayed) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex == null) {
      // All rounds played by this player — show results or wait.
      if (challenge.isComplete) {
        _navigateToResults(challenge);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: FlitColors.backgroundMid,
            content: Text(
              'Waiting for opponent to play their rounds...',
              style: TextStyle(color: FlitColors.textPrimary),
            ),
          ),
        );
      }
      return;
    }

    final round = challenge.rounds[nextIndex];
    final opponentName = isChallenger
        ? challenge.challengedName
        : challenge.challengerName;

    // Find the FlightSchoolLevel for this round.
    final level = flightSchoolLevels.firstWhere(
      (l) => l.id == round.levelId,
      orElse: () => flightSchoolLevels.first,
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => QuizGameScreen(
              mode: QuizMode.allStates,
              category: round.category,
              region: level.region,
              difficulty: round.difficulty,
              challengeId: challenge.id,
              challengeOpponentName: opponentName,
              seed: round.seed,
              flightSchoolLevelId: round.levelId,
              h2hRoundIndex: nextIndex,
            ),
          ),
        )
        .then((_) => _loadChallenges());
  }

  void _navigateToResults(H2HChallenge challenge) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => H2HResultsScreen(challenge: challenge),
      ),
    );
  }
}

/// List item widget for a single H2H challenge.
class _ChallengeListItem extends StatelessWidget {
  const _ChallengeListItem({
    required this.challenge,
    required this.currentUserId,
    required this.onTap,
  });

  final H2HChallenge challenge;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isChallenger = challenge.challengerId == currentUserId;
    final opponentName = isChallenger
        ? challenge.challengedName
        : challenge.challengerName;
    final statusInfo = _statusInfo(isChallenger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusInfo.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      statusInfo.icon,
                      color: statusInfo.color,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'vs $opponentName',
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (challenge.status == H2HStatus.completed ||
                              challenge.status == H2HStatus.inProgress)
                            Text(
                              challenge.scoreText,
                              style: TextStyle(
                                color: statusInfo.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                          color: statusInfo.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Round summaries
                      Row(
                        children: [
                          for (var i = 0; i < challenge.rounds.length; i++) ...[
                            _RoundChip(round: challenge.rounds[i], index: i),
                            if (i < challenge.rounds.length - 1)
                              const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: FlitColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({String label, Color color, IconData icon}) _statusInfo(bool isChallenger) {
    switch (challenge.status) {
      case H2HStatus.pending:
        if (isChallenger) {
          return (
            label: 'Waiting for response...',
            color: FlitColors.warning,
            icon: Icons.hourglass_top,
          );
        }
        return (
          label: 'Tap to accept or decline',
          color: FlitColors.accent,
          icon: Icons.notification_important,
        );
      case H2HStatus.inProgress:
        return (
          label: 'In progress - tap to play',
          color: FlitColors.oceanHighlight,
          icon: Icons.play_circle_outline,
        );
      case H2HStatus.completed:
        final won = challenge.winnerId == currentUserId;
        final draw = challenge.winnerId == null;
        if (draw) {
          return (
            label: 'Draw',
            color: FlitColors.textSecondary,
            icon: Icons.handshake,
          );
        }
        return won
            ? (
                label: 'Victory!',
                color: FlitColors.gold,
                icon: Icons.emoji_events,
              )
            : (
                label: 'Defeated',
                color: FlitColors.error,
                icon: Icons.sentiment_dissatisfied,
              );
      case H2HStatus.declined:
        return (
          label: 'Declined',
          color: FlitColors.textMuted,
          icon: Icons.block,
        );
      case H2HStatus.expired:
        return (
          label: 'Expired',
          color: FlitColors.textMuted,
          icon: Icons.timer_off,
        );
    }
  }
}

/// Small chip showing a round's level abbreviation.
class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.round, required this.index});

  final H2HRound round;
  final int index;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    if (round.isComplete) {
      final winner = round.winner;
      if (winner == 'draw') {
        bgColor = FlitColors.textSecondary.withOpacity(0.15);
        textColor = FlitColors.textSecondary;
      } else {
        bgColor = FlitColors.success.withOpacity(0.15);
        textColor = FlitColors.success;
      }
    } else {
      bgColor = FlitColors.backgroundMid;
      textColor = FlitColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        round.levelName.length > 6
            ? round.levelName.substring(0, 6)
            : round.levelName,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
