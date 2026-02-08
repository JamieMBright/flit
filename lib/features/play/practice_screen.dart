import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/region.dart';
import '../shop/shop_screen.dart';
import 'play_screen.dart';

// =============================================================================
// Clue type metadata
// =============================================================================

/// Display metadata for each [ClueType] toggle card.
class _ClueTypeMeta {
  const _ClueTypeMeta({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });

  final ClueType type;
  final String name;
  final String description;
  final IconData icon;
}

const List<_ClueTypeMeta> _clueTypeMetas = [
  _ClueTypeMeta(
    type: ClueType.flag,
    name: 'Flag',
    description: 'Identify countries by their national flag',
    icon: Icons.flag,
  ),
  _ClueTypeMeta(
    type: ClueType.outline,
    name: 'Outline',
    description: 'Recognise the country silhouette shape',
    icon: Icons.crop_square,
  ),
  _ClueTypeMeta(
    type: ClueType.borders,
    name: 'Borders',
    description: 'Guess from neighbouring countries',
    icon: Icons.border_all,
  ),
  _ClueTypeMeta(
    type: ClueType.capital,
    name: 'Capital',
    description: 'Name the country from its capital city',
    icon: Icons.location_city,
  ),
  _ClueTypeMeta(
    type: ClueType.stats,
    name: 'Stats',
    description: 'Deduce from population, language, and other facts',
    icon: Icons.bar_chart,
  ),
];

// =============================================================================
// Milestone system
// =============================================================================

/// A progress milestone for clue-type mastery.
class _Milestone {
  const _Milestone({required this.threshold, required this.title});

  final int threshold;
  final String title;
}

const List<_Milestone> _milestones = [
  _Milestone(threshold: 50, title: 'Novice'),
  _Milestone(threshold: 100, title: 'Apprentice'),
  _Milestone(threshold: 250, title: 'Expert'),
  _Milestone(threshold: 500, title: 'Master'),
];

/// Returns the current milestone title and next milestone target for a given
/// correct-answer count.
({String title, int nextTarget, int previousTarget}) _milestoneFor(
    int correct) {
  // Before reaching the first milestone
  if (correct < _milestones.first.threshold) {
    return (
      title: 'Beginner',
      nextTarget: _milestones.first.threshold,
      previousTarget: 0,
    );
  }

  // Walk through milestones to find where the player sits
  for (var i = 0; i < _milestones.length; i++) {
    final isLast = i == _milestones.length - 1;
    if (isLast || correct < _milestones[i + 1].threshold) {
      return (
        title: _milestones[i].title,
        nextTarget: isLast
            ? _milestones[i].threshold
            : _milestones[i + 1].threshold,
        previousTarget: _milestones[i].threshold,
      );
    }
  }

  // Fallback (should not reach)
  return (
    title: _milestones.last.title,
    nextTarget: _milestones.last.threshold,
    previousTarget: _milestones.last.threshold,
  );
}

// =============================================================================
// Constants
// =============================================================================

/// Cost in coins per disabled clue type.
const int _costPerDisabledClue = 25;

// =============================================================================
// PracticeScreen
// =============================================================================

/// Solo practice mode where players can toggle individual clue types on/off.
///
/// Isolating clue types (having fewer than all 5 enabled) costs coins, pushing
/// players to play global league to earn more coins.
///
/// Pricing:
///   - All 5 enabled: Free
///   - Each disabled clue costs [_costPerDisabledClue] coins
///   - Isolating 1 type (4 disabled) = 100 coins
///
/// Practice gives XP and counts toward clue-specific progress for social
/// titles. It is NOT ranked on the global leaderboard.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  /// Which clue types are currently enabled.
  final Map<ClueType, bool> _enabledClues = {
    for (final type in ClueType.values) type: true,
  };

  /// Placeholder clue progress data (correct answers per type).
  final Map<ClueType, int> _clueProgress = {
    ClueType.flag: 73,
    ClueType.outline: 41,
    ClueType.borders: 12,
    ClueType.capital: 108,
    ClueType.stats: 5,
  };

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  int get _enabledCount =>
      _enabledClues.values.where((enabled) => enabled).length;

  int get _disabledCount => ClueType.values.length - _enabledCount;

  /// Coin cost for the current toggle configuration.
  int get _coinCost => _disabledCount * _costPerDisabledClue;

  bool _canAffordWith(int coins) => coins >= _coinCost;

  bool get _hasAnyEnabled => _enabledCount > 0;

  /// Whether the given type is the only one still enabled.
  bool _isLastEnabled(ClueType type) =>
      _enabledCount == 1 && (_enabledClues[type] ?? false);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _toggleClue(ClueType type, bool value) {
    // Prevent disabling the last enabled clue type.
    if (!value && _isLastEnabled(type)) return;

    setState(() {
      _enabledClues[type] = value;
    });
  }

  void _startPractice() {
    final coins = ref.read(currentCoinsProvider);
    if (!(_hasAnyEnabled && _canAffordWith(coins))) return;
    final cost = _coinCost;
    if (cost > 0) {
      ref.read(accountProvider.notifier).spendCoins(cost);
    }
    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final companion = ref.read(accountProvider).avatar.companion;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          region: GameRegion.world,
          totalRounds: 10,
          planeColorScheme: plane?.colorScheme,
          planeWingSpan: plane?.wingSpan,
          equippedPlaneId: planeId,
          companionType: companion,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(currentCoinsProvider);
    final canStart = _hasAnyEnabled && _canAffordWith(coins);

    return Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text(
            'Practice Mode',
            style: TextStyle(color: FlitColors.textPrimary),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: FlitColors.textPrimary),
          actions: [
            // Coin balance chip - tappable to open shop
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: FlitColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: FlitColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      coins.toString(),
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // Coin cost display
                      _buildCostDisplay(coins),
                      const SizedBox(height: 20),

                      // Section label: Clue Types
                      _buildSectionLabel('CLUE TYPES', Icons.tune),
                      const SizedBox(height: 10),

                      // Clue type toggle cards
                      ..._buildClueToggleCards(),
                      const SizedBox(height: 24),

                      // Section label: Clue Progress
                      _buildSectionLabel('CLUE PROGRESS', Icons.trending_up),
                      const SizedBox(height: 10),

                      // Clue progress cards
                      ..._buildClueProgressCards(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom action bar (always visible)
              _buildBottomBar(coins, canStart),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlitColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school,
                color: FlitColors.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'PRACTICE MODE',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Train your skills without rank pressure',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FlitColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FlitColors.accent.withOpacity(0.25),
                ),
              ),
              child: const Text(
                'Not ranked on the global leaderboard',
                style: TextStyle(
                  color: FlitColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Coin cost display
  // ---------------------------------------------------------------------------

  Widget _buildCostDisplay(int coins) {
    final isFree = _coinCost == 0;
    final costColor = isFree
        ? FlitColors.success
        : _canAffordWith(coins)
            ? FlitColors.gold
            : FlitColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFree
              ? FlitColors.success.withOpacity(0.4)
              : costColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFree ? Icons.check_circle : Icons.monetization_on,
                color: costColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Game Cost',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isFree
                ? const Text(
                    'FREE',
                    key: ValueKey('free'),
                    style: TextStyle(
                      color: FlitColors.success,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  )
                : Row(
                    key: ValueKey(_coinCost),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cost: ',
                        style: TextStyle(
                          color: costColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.monetization_on,
                        color: costColor,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_coinCost coins',
                        style: TextStyle(
                          color: costColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section label
  // ---------------------------------------------------------------------------

  Widget _buildSectionLabel(String label, IconData icon) => Row(
        children: [
          Icon(icon, color: FlitColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Clue toggle cards
  // ---------------------------------------------------------------------------

  List<Widget> _buildClueToggleCards() {
    final cards = <Widget>[];
    for (final meta in _clueTypeMetas) {
      final enabled = _enabledClues[meta.type] ?? true;
      final isLast = _isLastEnabled(meta.type);
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ClueToggleCard(
            meta: meta,
            enabled: enabled,
            isLastEnabled: isLast,
            onChanged: (value) => _toggleClue(meta.type, value),
          ),
        ),
      );
    }
    return cards;
  }

  // ---------------------------------------------------------------------------
  // Clue progress cards
  // ---------------------------------------------------------------------------

  List<Widget> _buildClueProgressCards() {
    final cards = <Widget>[];
    for (final meta in _clueTypeMetas) {
      final correct = _clueProgress[meta.type] ?? 0;
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ClueProgressCard(
            meta: meta,
            correctCount: correct,
          ),
        ),
      );
    }
    return cards;
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(int coins, bool canStart) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(
            top: BorderSide(color: FlitColors.cardBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Not-enough-coins warning with shop link
            if (!_canAffordWith(coins) && _hasAnyEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: FlitColors.error, size: 16),
                      const SizedBox(width: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Need ${_coinCost - coins} more coins. ',
                              style: const TextStyle(color: FlitColors.error, fontSize: 12),
                            ),
                            const TextSpan(
                              text: 'Visit Shop',
                              style: TextStyle(
                                color: FlitColors.accent,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Start button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canStart ? _startPractice : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart
                      ? FlitColors.accent
                      : FlitColors.backgroundLight,
                  foregroundColor: FlitColors.textPrimary,
                  disabledBackgroundColor:
                      FlitColors.backgroundLight.withOpacity(0.5),
                  disabledForegroundColor: FlitColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: canStart ? 4 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flight_takeoff, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'START PRACTICE',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    if (_coinCost > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              size: 14,
                              color: FlitColors.gold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _coinCost.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// =============================================================================
// Clue Toggle Card
// =============================================================================

/// A single card representing one [ClueType] with a toggle switch.
class _ClueToggleCard extends StatelessWidget {
  const _ClueToggleCard({
    required this.meta,
    required this.enabled,
    required this.isLastEnabled,
    required this.onChanged,
  });

  final _ClueTypeMeta meta;
  final bool enabled;
  final bool isLastEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          // Prevent disabling the last enabled type.
          if (enabled && isLastEnabled) return;
          onChanged(!enabled);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled
                ? FlitColors.cardBackground
                : FlitColors.backgroundMid.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? FlitColors.accent.withOpacity(0.5)
                  : FlitColors.cardBorder.withOpacity(0.4),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? FlitColors.accent.withOpacity(0.15)
                      : FlitColors.backgroundDark.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  meta.icon,
                  color: enabled ? FlitColors.accent : FlitColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Name and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.name,
                          style: TextStyle(
                            color: enabled
                                ? FlitColors.textPrimary
                                : FlitColors.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isLastEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REQUIRED',
                              style: TextStyle(
                                color: FlitColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.description,
                      style: TextStyle(
                        color: enabled
                            ? FlitColors.textSecondary
                            : FlitColors.textMuted.withOpacity(0.7),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Toggle switch
              Switch.adaptive(
                value: enabled,
                onChanged: (value) {
                  if (!value && isLastEnabled) return;
                  onChanged(value);
                },
                activeColor: FlitColors.accent,
                activeTrackColor: FlitColors.accent.withOpacity(0.35),
                inactiveThumbColor: FlitColors.textMuted,
                inactiveTrackColor: FlitColors.backgroundDark,
              ),
            ],
          ),
        ),
      );
}

// =============================================================================
// Clue Progress Card
// =============================================================================

/// A card showing per-type clue progress with a progress bar toward the next
/// milestone.
class _ClueProgressCard extends StatelessWidget {
  const _ClueProgressCard({
    required this.meta,
    required this.correctCount,
  });

  final _ClueTypeMeta meta;
  final int correctCount;

  @override
  Widget build(BuildContext context) {
    final milestone = _milestoneFor(correctCount);
    final range = milestone.nextTarget - milestone.previousTarget;
    final progressInRange = correctCount - milestone.previousTarget;
    // Clamp to 0..1 for the progress bar. If the player has surpassed the
    // final milestone, the bar stays full.
    final progress = range > 0
        ? (progressInRange / range).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FlitColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              meta.icon,
              color: FlitColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Progress info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meta.name,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: FlitColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        milestone.title,
                        style: const TextStyle(
                          color: FlitColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Correct count
                Text(
                  '$correctCount correct',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: FlitColors.backgroundDark,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        FlitColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Next milestone label
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    correctCount >= _milestones.last.threshold
                        ? 'Max milestone reached'
                        : 'Next: ${milestone.nextTarget}',
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
