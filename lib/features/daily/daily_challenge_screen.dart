import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/daily_challenge.dart';
import '../../data/models/seasonal_theme.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/region.dart';
import '../play/play_screen.dart';

/// Daily challenge screen showing today's challenge details, seasonal events,
/// rewards, and leaderboards with licensed/unlicensed toggle.
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  late final DailyChallenge _challenge;
  final SeasonalTheme? _seasonalTheme = SeasonalTheme.current();

  /// 0 = Unlicensed, 1 = Licensed.
  int _leaderboardTab = 0;

  @override
  void initState() {
    super.initState();
    _challenge = DailyChallenge.forToday();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  _ChallengeHeader(challenge: _challenge),
                  const SizedBox(height: 12),
                  if (_seasonalTheme != null) ...[
                    _SeasonalBanner(theme: _seasonalTheme),
                    const SizedBox(height: 12),
                  ],
                  _RewardsSection(challenge: _challenge),
                  const SizedBox(height: 12),
                  const _MedalProgressSection(),
                  const SizedBox(height: 16),
                  _LeaderboardSection(
                    selectedTab: _leaderboardTab,
                    onTabChanged: (tab) {
                      setState(() {
                        _leaderboardTab = tab;
                      });
                    },
                    entries: DailyChallenge.placeholderLeaderboard,
                  ),
                  const SizedBox(height: 16),
                  const _HallOfFameSection(),
                  const SizedBox(height: 16),
                  _InfoFooter(bonusCoinReward: _challenge.bonusCoinReward),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _PlayButton(onPressed: _onPlay),
          ],
        ),
      );

  void _onPlay() {
    final reward = _challenge.coinReward;
    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          region: GameRegion.world,
          totalRounds: 5,
          coinReward: reward,
          planeColorScheme: plane?.colorScheme,
          planeWingSpan: plane?.wingSpan,
          equippedPlaneId: planeId,
          onComplete: (totalScore) {
            ref.read(accountProvider.notifier).addCoins(reward);
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Challenge Header
// =============================================================================

/// Maps a clue-type key to its display icon.
IconData _clueIcon(String clueType) {
  switch (clueType) {
    case 'flag':
      return Icons.flag_rounded;
    case 'outline':
      return Icons.crop_square_rounded;
    case 'borders':
      return Icons.border_all_rounded;
    case 'capital':
      return Icons.location_city_rounded;
    case 'stats':
      return Icons.bar_chart_rounded;
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
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
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
    final explanations = {
      'flag': 'You will see the national flag of a country. Identify which country it belongs to!',
      'outline': 'The country silhouette/shape is shown. Recognise the outline to identify the country.',
      'borders': 'You are told which countries border the mystery country. Use your geography knowledge!',
      'capital': 'The capital city is revealed. Name the country it belongs to.',
      'stats': 'Population, language, currency and other facts are shown. Deduce the country!',
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
          explanations[clueType] ?? 'Identify the country using the clue provided.',
          style: const TextStyle(color: FlitColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(color: FlitColors.accent)),
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
  const _RewardsSection({required this.challenge});

  final DailyChallenge challenge;

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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, color: FlitColors.textMuted, size: 14),
                  SizedBox(width: 6),
                  Text(
                    '2,847 players today \u2022 Top 1,000 win prizes',
                    style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
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
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

// =============================================================================
// Leaderboard Section
// =============================================================================

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.selectedTab,
    required this.onTabChanged,
    required this.entries,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;
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
            // Section header + tab toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.leaderboard_rounded,
                    color: FlitColors.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LEADERBOARD',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _LeaderboardToggle(
                    selectedTab: selectedTab,
                    onTabChanged: onTabChanged,
                  ),
                ],
              ),
            ),
            const Divider(color: FlitColors.cardBorder, height: 20),
            // Leaderboard rows
            ...entries.map(
              (entry) => _DailyLeaderboardRow(entry: entry),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
}

class _LeaderboardToggle extends StatelessWidget {
  const _LeaderboardToggle({
    required this.selectedTab,
    required this.onTabChanged,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: FlitColors.backgroundDark,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleTab(
              label: 'Unlicensed',
              isSelected: selectedTab == 0,
              onTap: () => onTabChanged(0),
            ),
            _ToggleTab(
              label: 'Licensed',
              isSelected: selectedTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ],
        ),
      );
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? FlitColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? FlitColors.textPrimary
                  : FlitColors.textMuted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
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
                    fontWeight:
                        entry.rank <= 3 ? FontWeight.w600 : FontWeight.normal,
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
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.6),
          ],
        ),
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
                    border: Border.all(color: const Color(0xFFCD7F32).withOpacity(0.5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.military_tech, color: Color(0xFFCD7F32), size: 28),
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
                        style: TextStyle(color: FlitColors.textSecondary, fontSize: 12),
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
  const _HallOfFameSection();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.gold.withOpacity(0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            SizedBox(height: 12),
            _HallOfFameRow(date: '5 Feb 2026', winner: 'GlobeTrotter42', medal: 'Platinum'),
            SizedBox(height: 6),
            _HallOfFameRow(date: '4 Feb 2026', winner: 'MapMaster', medal: 'Gold'),
            SizedBox(height: 6),
            _HallOfFameRow(date: '3 Feb 2026', winner: 'AtlasAce', medal: 'Gold'),
            SizedBox(height: 6),
            _HallOfFameRow(date: '2 Feb 2026', winner: 'WanderWiz', medal: 'Silver'),
            SizedBox(height: 6),
            _HallOfFameRow(date: '1 Feb 2026', winner: 'GeoPilot', medal: 'Bronze'),
          ],
        ),
      );
}

class _HallOfFameRow extends StatelessWidget {
  const _HallOfFameRow({required this.date, required this.winner, required this.medal});

  final String date;
  final String winner;
  final String medal;

  Color get _medalColor {
    switch (medal) {
      case 'Platinum': return const Color(0xFFE5E4E2);
      case 'Gold': return const Color(0xFFFFD700);
      case 'Silver': return const Color(0xFFC0C0C0);
      default: return const Color(0xFFCD7F32);
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
                style: const TextStyle(color: FlitColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
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
