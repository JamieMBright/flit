import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/models/daily_result.dart';
import '../../data/models/daily_streak.dart';
import '../../data/models/seasonal_theme.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/leaderboard_service.dart';
import '../../game/map/region.dart';
import '../play/play_screen.dart';

/// Daily challenge screen showing today's challenge details, seasonal events,
/// rewards, and leaderboard.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  late final DailyChallenge _challenge;
  final SeasonalTheme? _seasonalTheme = SeasonalTheme.current();
  List<DailyLeaderboardEntry> _leaderboardEntries = [];
  List<Map<String, dynamic>> _hallOfFame = [];
  int _dailyPlayerCount = 0;
  bool _loadingLeaderboard = true;

  // Licence bonuses always apply — no unlicensed/licensed split.

  bool get _hasDoneToday => ref.watch(accountProvider).hasDoneDailyToday;

  @override
  void initState() {
    super.initState();
    _challenge = DailyChallenge.forToday();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = LeaderboardService.instance;
    final results = await Future.wait([
      service.fetchDailyLeaderboard(),
      service.fetchHallOfFame(),
      service.fetchDailyPlayerCount(),
    ]);
    if (mounted) {
      setState(() {
        _leaderboardEntries = results[0] as List<DailyLeaderboardEntry>;
        _hallOfFame = results[1] as List<Map<String, dynamic>>;
        _dailyPlayerCount = results[2] as int;
        _loadingLeaderboard = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: const Text('Daily Challenge'),
      centerTitle: true,
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const _StreakSection(),
              const SizedBox(height: 12),
              _ChallengeHeader(challenge: _challenge),
              const SizedBox(height: 12),
              if (_seasonalTheme != null) ...[
                _SeasonalBanner(theme: _seasonalTheme),
                const SizedBox(height: 12),
              ],
              _RewardsSection(
                challenge: _challenge,
                playerCount: _dailyPlayerCount,
              ),
              const SizedBox(height: 12),
              const _MedalProgressSection(),
              const SizedBox(height: 16),
              _loadingLeaderboard
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: FlitColors.accent,
                        ),
                      ),
                    )
                  : _LeaderboardSection(entries: _leaderboardEntries),
              const SizedBox(height: 16),
              _HallOfFameSection(entries: _hallOfFame),
              const SizedBox(height: 16),
              _InfoFooter(bonusCoinReward: _challenge.bonusCoinReward),
              const SizedBox(height: 16),
            ],
          ),
        ),
        _hasDoneToday
            ? const _CompletedBanner()
            : _PlayButton(onPressed: _onPlay),
      ],
    ),
  );

  Future<void> _onPlay() async {
    final reward = _challenge.coinReward;
    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final account = ref.read(accountProvider);
    final companion = account.avatar.companion;
    final fuelBoost = ref.read(accountProvider.notifier).fuelBoostMultiplier;
    final license = account.license;
    final contrailId = ref.read(accountProvider).equippedContrailId;
    final contrail = CosmeticCatalog.getById(contrailId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          region: GameRegion.world,
          totalRounds: 5,
          coinReward: reward,
          planeColorScheme: plane?.colorScheme,
          planeWingSpan: plane?.wingSpan,
          equippedPlaneId: planeId,
          companionType: companion,
          fuelBoostMultiplier: fuelBoost,
          clueBoost: license.clueBoost,
          clueChance: license.clueChance,
          preferredClueType: license.preferredClueType,
          enabledClueTypes: _challenge.enabledClueTypes,
          enableFuel: true,
          planeHandling: plane?.handling ?? 1.0,
          planeSpeed: plane?.speed ?? 1.0,
          planeFuelEfficiency: plane?.fuelEfficiency ?? 1.0,
          contrailPrimaryColor: contrail?.colorScheme?['primary'] != null
              ? Color(contrail!.colorScheme!['primary']!)
              : null,
          contrailSecondaryColor: contrail?.colorScheme?['secondary'] != null
              ? Color(contrail!.colorScheme!['secondary']!)
              : null,
          isDailyChallenge: true,
          dailyTheme: _challenge.title,
          dailySeed: _challenge.seed,
          onComplete: (totalScore) {
            ref.read(accountProvider.notifier).recordDailyChallengeCompletion();
          },
          onDailyComplete: (result) {
            ref.read(accountProvider.notifier).recordDailyResult(result);
          },
        ),
      ),
    );
    // Refresh leaderboard data after returning from the game.
    if (mounted) _loadData();
  }
}

// =============================================================================
// Challenge Header
// =============================================================================

/// Maps a clue-type key to its display icon.
IconData _clueIcon(String clueType) {
  switch (clueType) {
    case 'flag':
    case 'flagDescription':
      return Icons.flag_rounded;
    case 'outline':
      return Icons.crop_square_rounded;
    case 'borders':
      return Icons.border_all_rounded;
    case 'capital':
      return Icons.location_city_rounded;
    case 'stats':
      return Icons.bar_chart_rounded;
    case 'sportsTeam':
      return Icons.sports_rounded;
    case 'leader':
      return Icons.person_rounded;
    case 'nickname':
      return Icons.label_rounded;
    case 'landmark':
      return Icons.landscape_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

/// Maps a clue-type key to a short display label.
String _clueLabel(String clueType) {
  switch (clueType) {
    case 'flag':
      return 'Flag';
    case 'outline':
      return 'Outline';
    case 'borders':
      return 'Borders';
    case 'capital':
      return 'Capital';
    case 'stats':
      return 'Stats';
    case 'sportsTeam':
      return 'Sports';
    case 'leader':
      return 'Leader';
    case 'nickname':
      return 'Nickname';
    case 'landmark':
      return 'Landmark';
    case 'flagDescription':
      return 'Flag Desc';
    default:
      return clueType;
  }
}

class _ChallengeHeader extends StatelessWidget {
  const _ChallengeHeader({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final sortedClueTypes = challenge.enabledClueTypes.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date label
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: FlitColors.accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(challenge.date),
                style: const TextStyle(
                  color: FlitColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Map region
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map, color: FlitColors.gold, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Map: ${challenge.mapRegion}',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            challenge.title,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Description
          Text(
            challenge.description,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Active clue types
          const Text(
            'ACTIVE CLUES',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedClueTypes
                .map((type) => _ClueChip(clueType: type))
                .toList(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ClueChip extends StatelessWidget {
  const _ClueChip({required this.clueType});

  final String clueType;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showClueExplanation(context),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlitColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.accent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_clueIcon(clueType), color: FlitColors.accent, size: 16),
          const SizedBox(width: 6),
          Text(
            _clueLabel(clueType),
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  void _showClueExplanation(BuildContext context) {
    const explanations = {
      'flag':
          'You will see the national flag of a country. Identify which country it belongs to!',
      'outline':
          'The country silhouette/shape is shown. Recognise the outline to identify the country.',
      'borders':
          'You are told which countries border the mystery country. Use your geography knowledge!',
      'capital':
          'The capital city is revealed. Name the country it belongs to.',
      'stats':
          'Population, language, currency and other facts are shown. Deduce the country!',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Row(
          children: [
            Icon(_clueIcon(clueType), color: FlitColors.accent, size: 24),
            const SizedBox(width: 10),
            Text(
              '${_clueLabel(clueType)} Clue',
              style: const TextStyle(color: FlitColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          explanations[clueType] ??
              'Identify the country using the clue provided.',
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: FlitColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Seasonal Banner
// =============================================================================

class _SeasonalBanner extends StatelessWidget {
  const _SeasonalBanner({required this.theme});

  final SeasonalTheme theme;

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(theme.accentColor);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.25),
            accentColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Festive icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _seasonalIcon(theme.event),
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Vehicle name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SEASONAL EVENT',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  theme.vehicleName,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme.vehicleDescription,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _seasonalIcon(SeasonalEvent event) {
    switch (event) {
      case SeasonalEvent.christmas:
        return Icons.ac_unit_rounded;
      case SeasonalEvent.halloween:
        return Icons.dark_mode_rounded;
      case SeasonalEvent.easter:
        return Icons.egg_rounded;
      case SeasonalEvent.summer:
        return Icons.wb_sunny_rounded;
      case SeasonalEvent.valentines:
        return Icons.favorite_rounded;
      case SeasonalEvent.stPatricks:
        return Icons.eco_rounded;
      case SeasonalEvent.none:
        return Icons.celebration_rounded;
    }
  }
}

// =============================================================================
// Rewards Section
// =============================================================================

class _RewardsSection extends StatelessWidget {
  const _RewardsSection({required this.challenge, this.playerCount = 0});

  final DailyChallenge challenge;
  final int playerCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REWARDS',
          style: TextStyle(
            color: FlitColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        // Player count and winner info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, color: FlitColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                '$playerCount players today \u2022 Top 1,000 win prizes',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Completion reward
            Expanded(
              child: _RewardTile(
                icon: Icons.monetization_on_rounded,
                iconColor: FlitColors.gold,
                label: 'Completion',
                value: '${challenge.coinReward}',
                valueSuffix: ' coins',
              ),
            ),
            const SizedBox(width: 12),
            // Bonus reward for daily leader
            Expanded(
              child: _RewardTile(
                icon: Icons.emoji_events_rounded,
                iconColor: FlitColors.warning,
                label: 'Daily Leader',
                value: '${challenge.bonusCoinReward}',
                valueSuffix: ' bonus',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueSuffix,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FlitColors.backgroundMid,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              valueSuffix,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

// =============================================================================
// Leaderboard Section
// =============================================================================

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.entries});

  final List<DailyLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: FlitColors.gold, size: 18),
              SizedBox(width: 6),
              Text(
                'LEADERBOARD',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: FlitColors.cardBorder, height: 20),
        // Leaderboard rows
        ...entries.map((entry) => _DailyLeaderboardRow(entry: entry)),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _DailyLeaderboardRow extends StatelessWidget {
  const _DailyLeaderboardRow({required this.entry});

  final DailyLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final minutes = entry.time.inMinutes;
    final seconds = entry.time.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.rank <= 3
            ? _rankColor.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: entry.rank <= 3
            ? Border.all(color: _rankColor.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          // Rank medal or number
          SizedBox(
            width: 32,
            child: entry.rank <= 3
                ? _RankMedal(rank: entry.rank)
                : Text(
                    '#${entry.rank}',
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 10),
          // Username and score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: TextStyle(
                    color: entry.rank <= 3
                        ? FlitColors.textPrimary
                        : FlitColors.textSecondary,
                    fontSize: 14,
                    fontWeight: entry.rank <= 3
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.score} pts',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Time
          Text(
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: entry.rank <= 3
                  ? FlitColors.textPrimary
                  : FlitColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return FlitColors.textSecondary;
    }
  }
}

/// Circular medal widget for top-3 ranks.
class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = _medalColor;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0.6)]),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$rank',
          style: const TextStyle(
            color: FlitColors.backgroundDark,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Color get _medalColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return FlitColors.textMuted;
    }
  }
}

// =============================================================================
// Info Footer
// =============================================================================

class _InfoFooter extends StatelessWidget {
  const _InfoFooter({required this.bonusCoinReward});

  final int bonusCoinReward;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FlitColors.gold.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: FlitColors.gold.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.info_outline_rounded,
            color: FlitColors.gold,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Daily leader wins $bonusCoinReward bonus coins! '
            'Annual champions receive exclusive cosmetics.',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Medal Progress Section
// =============================================================================

class _MedalProgressSection extends StatelessWidget {
  const _MedalProgressSection();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DAILY MEDAL',
          style: TextStyle(
            color: FlitColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        // Medal display
        Row(
          children: [
            // Current medal icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFCD7F32).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFCD7F32).withOpacity(0.5),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.military_tech,
                  color: Color(0xFFCD7F32),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bronze Medal',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '0 daily wins \u2022 Win to earn stars!',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Star progression
        const Text(
          'PROGRESSION: 20 steps (Bronze \u2192 Silver \u2192 Gold \u2192 Platinum)',
          style: TextStyle(color: FlitColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: 0,
              backgroundColor: FlitColors.backgroundDark,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCD7F32)),
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Hall of Fame Section
// =============================================================================

class _HallOfFameSection extends StatelessWidget {
  const _HallOfFameSection({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FlitColors.gold.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.emoji_events, color: FlitColors.gold, size: 18),
            SizedBox(width: 6),
            Text(
              'HALL OF FAME',
              style: TextStyle(
                color: FlitColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No daily winners yet',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
            ),
          )
        else
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _HallOfFameRow(
                date: e['date'] as String,
                winner: e['winner'] as String,
                medal: 'Gold',
              ),
            ),
          ),
      ],
    ),
  );
}

class _HallOfFameRow extends StatelessWidget {
  const _HallOfFameRow({
    required this.date,
    required this.winner,
    required this.medal,
  });

  final String date;
  final String winner;
  final String medal;

  Color get _medalColor {
    switch (medal) {
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: FlitColors.backgroundMid,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Icon(Icons.military_tech, color: _medalColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            winner,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          date,
          style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

// =============================================================================
// Play Button
// =============================================================================

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.accent,
            foregroundColor: FlitColors.textPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 24),
              SizedBox(width: 8),
              Text(
                "PLAY TODAY'S CHALLENGE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// =============================================================================
// Completed Banner (shown when daily challenge already done today)
// =============================================================================

/// Maps a [DailyRoundResult] to its corresponding display color.
/// Kept as a top-level function because [_CompletedBanner] is a
/// [ConsumerWidget] and cannot have static helper methods.
Color _roundColor(DailyRoundResult round) {
  if (!round.completed) return const Color(0xFFCC4444); // red
  if (round.hintsUsed == 0) return FlitColors.success; // green
  if (round.hintsUsed <= 2) return FlitColors.accent; // orange
  return FlitColors.gold; // yellow
}

class _CompletedBanner extends ConsumerWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastResult = ref.watch(lastDailyResultProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: FlitColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlitColors.success.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: FlitColors.success,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'COMPLETED',
                        style: TextStyle(
                          color: FlitColors.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  if (lastResult != null) ...[
                    const SizedBox(height: 10),
                    // Round result circles (Flutter Container widgets avoid
                    // iOS emoji rendering issues with Unicode colored circles)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < lastResult.totalRounds; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < lastResult.rounds.length
                                    ? _roundColor(lastResult.rounds[i])
                                    : const Color(0xFFCC4444),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${DailyResult.formatScore(lastResult.totalScore)} pts  '
                      '\u2022  Time: ${DailyResult.formatTime(lastResult.totalTimeMs)}',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Share button
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: lastResult.toShareText()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Result copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.share,
                        color: FlitColors.accent,
                        size: 18,
                      ),
                      label: const Text(
                        'SHARE RESULT',
                        style: TextStyle(
                          color: FlitColors.accent,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FlitColors.accent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  if (lastResult == null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Try again tomorrow!',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Streak Section
// =============================================================================

class _StreakSection extends ConsumerWidget {
  const _StreakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(dailyStreakProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: streak.currentStreak > 0
            ? FlitColors.gold.withOpacity(0.08)
            : FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: streak.currentStreak > 0
              ? FlitColors.gold.withOpacity(0.4)
              : FlitColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY STREAK',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Fire icon for active streak, snowflake for no streak
              Text(
                streak.currentStreak > 0 ? '\u{1F525}' : '\u{2744}\u{FE0F}',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak.currentStreak > 0
                          ? '${streak.currentStreak} day streak!'
                          : 'No active streak',
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best: ${streak.longestStreak}  '
                      '\u2022  ${streak.totalCompleted} dailies played',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (streak.currentStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '\u{1F525} ${streak.currentStreak}',
                    style: const TextStyle(
                      color: FlitColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          // Streak recovery prompt
          if (streak.isRecoverable) ...[
            const SizedBox(height: 12),
            const Divider(color: FlitColors.cardBorder, height: 1),
            const SizedBox(height: 12),
            _StreakRecoveryPrompt(streak: streak),
          ],
        ],
      ),
    );
  }
}

class _StreakRecoveryPrompt extends ConsumerWidget {
  const _StreakRecoveryPrompt({required this.streak});

  final DailyStreak streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(currentCoinsProvider);
    final canAfford = coins >= streak.recoveryCost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlitColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: FlitColors.warning,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Streak at risk! ${streak.daysMissed} day${streak.daysMissed > 1 ? "s" : ""} missed',
                style: const TextStyle(
                  color: FlitColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recover your ${streak.currentStreak}-day streak for '
            '${streak.recoveryCost} coins',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canAfford
                  ? () => _showRecoveryDialog(context, ref)
                  : null,
              icon: const Icon(Icons.monetization_on, size: 18),
              label: Text(
                canAfford
                    ? 'RECOVER STREAK (${streak.recoveryCost} coins)'
                    : 'NOT ENOUGH COINS (${streak.recoveryCost} needed)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford
                    ? FlitColors.gold
                    : FlitColors.backgroundMid,
                foregroundColor: canAfford
                    ? FlitColors.backgroundDark
                    : FlitColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecoveryDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Row(
          children: [
            const Text('\u{1F525}', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recover ${streak.currentStreak}-Day Streak?',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You missed ${streak.daysMissed} day${streak.daysMissed > 1 ? "s" : ""}. '
              'Pay ${streak.recoveryCost} coins to keep your streak alive.',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cost:',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: FlitColors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${streak.recoveryCost}',
                        style: const TextStyle(
                          color: FlitColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final success = ref
                  .read(accountProvider.notifier)
                  .recoverStreak();
              Navigator.of(ctx).pop();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Streak recovered! Keep it going!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.gold,
              foregroundColor: FlitColors.backgroundDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'RECOVER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
