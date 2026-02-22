import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/pilot_license.dart';
import '../../data/providers/account_provider.dart';
import '../avatar/avatar_widget.dart';
import '../shop/shop_screen.dart';

// =============================================================================
// Rarity colors
// =============================================================================

const Color _bronzeColor = Color(0xFFCD7F32);
const Color _silverColor = Color(0xFFC0C0C0);
const Color _goldColor = Color(0xFFFFD700);
const Color _diamondColor = Color(0xFFB9F2FF);

const List<Color> _perfectGradientColors = [
  Color(0xFFFF0000),
  Color(0xFFFF7F00),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF0000FF),
  Color(0xFF8B00FF),
  Color(0xFFFF0000),
];

Color _colorForRarity(String rarityTier) {
  switch (rarityTier) {
    case 'Bronze':
      return _bronzeColor;
    case 'Silver':
      return _silverColor;
    case 'Gold':
      return _goldColor;
    case 'Diamond':
      return _diamondColor;
    case 'Perfect':
      return _goldColor;
    default:
      return _bronzeColor;
  }
}

/// Returns the stat bar segment color based on the boost value (1-25).
Color _statColor(int value) {
  if (value >= 25) return const Color(0xFFFFD700);
  if (value >= 21) return const Color(0xFFFF8C00);
  if (value >= 16) return const Color(0xFF9B59B6);
  if (value >= 6) return const Color(0xFF4A90D9);
  return const Color(0xFF6AAB5C);
}

/// Aviation rank title for player level (mirrors profile_screen).
String _aviationRankTitle(int level) {
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

// =============================================================================
// LicenseScreen
// =============================================================================

/// Pilot license gacha screen where players view license stats and reroll them.
class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen>
    with SingleTickerProviderStateMixin {
  late PilotLicense _license;
  final Set<String> _lockedStats = {};
  bool _lockClueType = false;
  bool _isRolling = false;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // Read the license from the account provider so rerolls persist.
    _license = ref.read(licenseProvider);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Pull latest server state so license stats are always current.
    ref.read(accountProvider.notifier).refreshFromServer();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cost helpers
  // ---------------------------------------------------------------------------

  /// Cost to lock selected stats (without the base reroll cost).
  int get _lockOnlyCost {
    var cost = 0;
    for (final stat in _lockedStats) {
      int statValue;
      switch (stat) {
        case 'coinBoost':
          statValue = _license.coinBoost;
        case 'clueBoost':
          statValue = _license.clueBoost;
        case 'clueChance':
          statValue = _license.clueChance;
        case 'fuelBoost':
          statValue = _license.fuelBoost;
        default:
          statValue = 1;
      }
      cost += PilotLicense.lockCostForValue(statValue);
    }
    if (_lockClueType) cost += PilotLicense.lockTypeCost;
    return cost;
  }

  /// Total cost for a paid reroll (base cost + lock costs).
  int get _totalCost => PilotLicense.rerollAllCost + _lockOnlyCost;

  bool _canAfford(int coins) => coins >= _totalCost;

  // ---------------------------------------------------------------------------
  // Reroll
  // ---------------------------------------------------------------------------

  Future<void> _reroll() async {
    if (!_canAfford(ref.read(currentCoinsProvider)) || _isRolling) return;

    setState(() => _isRolling = true);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final avatarLuck = ref.read(avatarProvider).luckBonus;
    setState(() {
      _license = PilotLicense.reroll(
        _license,
        lockedStats: _lockedStats,
        lockType: _lockClueType,
        luckBonus: avatarLuck,
      );
      _isRolling = false;
    });
    ref.read(accountProvider.notifier).spendCoins(_totalCost);
    // Persist the rerolled license to the account provider.
    ref.read(accountProvider.notifier).updateLicense(_license);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(currentCoinsProvider);
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Pilot License'),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ShopScreen(initialTabIndex: 2),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: FlitColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: FlitColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    coins.toString(),
                    style: const TextStyle(
                      color: FlitColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildLicenseCard(),
            const SizedBox(height: 24),
            _buildLockSection(coins),
            const SizedBox(height: 24),
            _buildFreeRerollButton(),
            const SizedBox(height: 12),
            _buildDailyScrambleRerollButton(),
            const SizedBox(height: 12),
            _buildRerollButton(coins),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // License card (credit-card aspect ratio)
  // ---------------------------------------------------------------------------

  Widget _buildLicenseCard() {
    final rarity = _license.rarityTier;
    final rarityColor = _colorForRarity(rarity);
    final isPerfect = rarity == 'Perfect';

    return _AnimBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final borderDecoration = isPerfect
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: SweepGradient(
                  center: Alignment.center,
                  startAngle: _shimmerController.value * 2 * math.pi,
                  colors: _perfectGradientColors,
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: rarityColor,
              );

        return Container(
          decoration: borderDecoration,
          padding: const EdgeInsets.all(2.5),
          child: AspectRatio(
            aspectRatio: 85.6 / 54.0, // credit card ratio
            child: Container(
              decoration: BoxDecoration(
                color: FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: _isRolling
                  ? _buildRollingPlaceholder()
                  : _buildLicenseContent(rarityColor, isPerfect),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRollingPlaceholder() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(FlitColors.gold),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Rerolling...',
          style: TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );

  Widget _buildLicenseContent(Color rarityColor, bool isPerfect) {
    final player = ref.watch(currentPlayerProvider);
    final avatarConfig = ref.watch(avatarProvider);
    final equippedPlaneId = ref.watch(equippedPlaneIdProvider);
    final equippedPlane = CosmeticCatalog.getById(equippedPlaneId);
    final rank = _aviationRankTitle(player.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Top row: title + rarity badge ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'FLIT PILOT LICENSE',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showRarityExplanation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RarityBadge(
                    tier: _license.rarityTier,
                    color: rarityColor,
                    isPerfect: isPerfect,
                    animation: _shimmerController,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    color: rarityColor.withOpacity(0.6),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(flex: 1),

        // --- Middle row: plane | name/rank/level | avatar ---
        Row(
          children: [
            // Equipped plane preview (left)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                size: const Size(56, 56),
                painter: PlanePainter(
                  planeId: equippedPlaneId,
                  colorScheme: equippedPlane?.colorScheme,
                  wingSpan: equippedPlane?.wingSpan ?? 26.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name, rank, level (center)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rank,
                    style: const TextStyle(
                      color: FlitColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Level ${player.level}',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Avatar (top right)
            AvatarWidget(config: avatarConfig, size: 56),
          ],
        ),
        const Spacer(flex: 1),

        // --- Stat bars: coins, fuel, clue chance ---
        _WideStatBar(
          label: _license.coinBoostLabel,
          icon: Icons.monetization_on,
          value: _license.coinBoost,
          shimmer: _shimmerController,
          onTap: () => _showEffectPopup(
            'Extra Coins',
            'Earn ${_license.coinBoost}% more coins from every game you play. Stacks with daily bonuses.',
            Icons.monetization_on,
          ),
        ),
        const SizedBox(height: 3),
        _WideStatBar(
          label: _license.fuelBoostLabel,
          icon: Icons.local_gas_station,
          value: _license.fuelBoost,
          shimmer: _shimmerController,
          onTap: () => _showEffectPopup(
            'Fuel Efficiency',
            'Extends your fuel/speed-boost duration in solo play by ${_license.fuelBoost}%. More fuel means more time to guess.',
            Icons.local_gas_station,
          ),
        ),
        const SizedBox(height: 3),
        _WideStatBar(
          label: _license.clueChanceLabel,
          icon: Icons.casino,
          value: _license.clueChance,
          shimmer: _shimmerController,
          onTap: () => _showEffectPopup(
            'Clue Chance',
            'Increases the chance of receiving additional clues by ${_license.clueChance}%. More clues means more information to help you guess.',
            Icons.casino,
          ),
        ),
        const SizedBox(height: 3),
        // Preferred clue type (no bar — just an info row)
        _ClueTypeRow(
          preferredType: _license.preferredClueType,
          clueBoost: _license.clueBoost,
          onTap: () => _showEffectPopup(
            'Preferred Clue Type',
            'You have a ${_license.clueBoost}% bonus chance of receiving ${_license.preferredClueType} clues. '
                'This stacks with your Clue Chance stat.',
            Icons.lightbulb_outline,
          ),
        ),

        const Spacer(flex: 1),

        // --- Bottom: total boost ---
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Total: +${_license.totalBoost}%',
              style: TextStyle(
                color: rarityColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showRarityExplanation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: const Text(
          'License Rarity',
          style: TextStyle(color: FlitColors.textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your license rarity is based on the total of all four stat boosts combined. Higher total = rarer license.',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _rarityTierRow('Bronze', '4-25 total', _bronzeColor),
            const SizedBox(height: 6),
            _rarityTierRow('Silver', '26-50 total', _silverColor),
            const SizedBox(height: 6),
            _rarityTierRow('Gold', '51-75 total', _goldColor),
            const SizedBox(height: 6),
            _rarityTierRow('Diamond', '76-90 total', _diamondColor),
            const SizedBox(height: 6),
            _rarityTierRow('Perfect', '91-100 total', const Color(0xFFFF0000)),
            const SizedBox(height: 16),
            const Text(
              'Each stat rolls from 1-25 with weighted odds. High values (21-25) are extremely rare, making a Perfect license nearly impossible.',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
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

  Widget _rarityTierRow(String name, String range, Color color) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        range,
        style: const TextStyle(color: FlitColors.textMuted, fontSize: 12),
      ),
    ],
  );

  void _showEffectPopup(String title, String description, IconData icon) {
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
            Icon(icon, color: FlitColors.accent, size: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          description,
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

  // ---------------------------------------------------------------------------
  // Lock section (no clue type lock)
  // ---------------------------------------------------------------------------

  Widget _buildLockSection(int coins) => Container(
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
          'Lock Stats',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lock stats you want to keep before rerolling.',
          style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _LockRow(
          label: 'Coin Boost',
          value: _license.coinBoostLabel,
          icon: Icons.monetization_on,
          isLocked: _lockedStats.contains('coinBoost'),
          cost: _lockCostFor('coinBoost'),
          onChanged: (locked) => _toggleLock('coinBoost', locked),
        ),
        const SizedBox(height: 8),
        _LockRow(
          label: 'Fuel Boost',
          value: _license.fuelBoostLabel,
          icon: Icons.local_gas_station,
          isLocked: _lockedStats.contains('fuelBoost'),
          cost: _lockCostFor('fuelBoost'),
          onChanged: (locked) => _toggleLock('fuelBoost', locked),
        ),
        const SizedBox(height: 8),
        _LockRow(
          label: 'Clue Chance',
          value: _license.clueChanceLabel,
          icon: Icons.casino,
          isLocked: _lockedStats.contains('clueChance'),
          cost: _lockCostFor('clueChance'),
          onChanged: (locked) => _toggleLock('clueChance', locked),
        ),
        const SizedBox(height: 8),
        _LockRow(
          label: 'Clue Type',
          value: _license.clueBoostLabel,
          icon: Icons.lightbulb_outline,
          isLocked: _lockClueType,
          cost: PilotLicense.lockTypeCost,
          onChanged: (locked) => setState(() => _lockClueType = locked),
        ),
        const Divider(color: FlitColors.cardBorder, height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Reroll Cost',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: FlitColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _totalCost.toString(),
                  style: TextStyle(
                    color: _canAfford(coins)
                        ? FlitColors.warning
                        : FlitColors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  int _lockCostFor(String stat) {
    int statValue;
    switch (stat) {
      case 'coinBoost':
        statValue = _license.coinBoost;
      case 'clueBoost':
        statValue = _license.clueBoost;
      case 'clueChance':
        statValue = _license.clueChance;
      case 'fuelBoost':
        statValue = _license.fuelBoost;
      default:
        statValue = 1;
    }
    return PilotLicense.lockCostForValue(statValue);
  }

  void _toggleLock(String stat, bool locked) {
    setState(() {
      if (locked) {
        _lockedStats.add(stat);
      } else {
        _lockedStats.remove(stat);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reroll button
  // ---------------------------------------------------------------------------

  Widget _buildFreeRerollButton() {
    final hasFree = ref.watch(accountProvider).hasFreeRerollToday;
    final coins = ref.watch(currentCoinsProvider);
    final lockCost = _lockOnlyCost;
    final canAffordLocks = lockCost == 0 || coins >= lockCost;
    final enabled = hasFree && !_isRolling && canAffordLocks;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: enabled ? _freeReroll : null,
            icon: Icon(
              hasFree ? Icons.card_giftcard : Icons.check_circle_outline,
              size: 20,
            ),
            label: Text(
              hasFree ? 'FREE DAILY REROLL' : 'FREE REROLL USED TODAY',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasFree
                  ? FlitColors.success
                  : FlitColors.backgroundMid,
              foregroundColor: FlitColors.textPrimary,
              disabledBackgroundColor: FlitColors.backgroundMid,
              disabledForegroundColor: FlitColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: hasFree ? 4 : 0,
            ),
          ),
        ),
        if (hasFree && lockCost > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 12, color: FlitColors.textMuted),
                const SizedBox(width: 4),
                const Icon(
                  Icons.monetization_on,
                  size: 12,
                  color: FlitColors.warning,
                ),
                const SizedBox(width: 2),
                Text(
                  '$lockCost lock cost',
                  style: TextStyle(
                    color: canAffordLocks
                        ? FlitColors.textMuted
                        : FlitColors.error,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _freeReroll() async {
    if (_isRolling) return;

    setState(() => _isRolling = true);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final success = ref
        .read(accountProvider.notifier)
        .useFreeReroll(lockedStats: _lockedStats, lockType: _lockClueType);
    if (success) {
      _license = ref.read(licenseProvider);
    }
    setState(() => _isRolling = false);
  }

  // ---------------------------------------------------------------------------
  // Daily scramble bonus reroll
  // ---------------------------------------------------------------------------

  Widget _buildDailyScrambleRerollButton() {
    final hasBonus = ref.watch(accountProvider).hasDailyScrambleReroll;
    if (!hasBonus) return const SizedBox.shrink();
    final coins = ref.watch(currentCoinsProvider);
    final lockCost = _lockOnlyCost;
    final canAffordLocks = lockCost == 0 || coins >= lockCost;
    final enabled = !_isRolling && canAffordLocks;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: enabled ? _dailyScrambleReroll : null,
            icon: const Icon(Icons.today_rounded, size: 20),
            label: const Text(
              'DAILY SCRAMBLE REROLL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              disabledBackgroundColor: FlitColors.backgroundMid,
              disabledForegroundColor: FlitColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
          ),
        ),
        if (lockCost > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 12, color: FlitColors.textMuted),
                const SizedBox(width: 4),
                const Icon(
                  Icons.monetization_on,
                  size: 12,
                  color: FlitColors.warning,
                ),
                const SizedBox(width: 2),
                Text(
                  '$lockCost lock cost',
                  style: TextStyle(
                    color: canAffordLocks
                        ? FlitColors.textMuted
                        : FlitColors.error,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _dailyScrambleReroll() async {
    if (_isRolling) return;

    setState(() => _isRolling = true);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final success = ref
        .read(accountProvider.notifier)
        .useDailyScrambleReroll(
          lockedStats: _lockedStats,
          lockType: _lockClueType,
        );
    if (success) {
      _license = ref.read(licenseProvider);
    }
    setState(() => _isRolling = false);
  }

  // ---------------------------------------------------------------------------
  // Paid reroll button
  // ---------------------------------------------------------------------------

  Widget _buildRerollButton(int coins) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _canAfford(coins) && !_isRolling ? _reroll : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canAfford(coins)
                ? FlitColors.accent
                : FlitColors.error.withOpacity(0.4),
            foregroundColor: FlitColors.textPrimary,
            disabledBackgroundColor: FlitColors.error.withOpacity(0.25),
            disabledForegroundColor: FlitColors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: _canAfford(coins) ? 4 : 0,
          ),
          child: _isRolling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FlitColors.textPrimary,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.casino, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'REROLL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
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
                            color: FlitColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _totalCost.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      // Avatar luck bonus indicator
      Builder(
        builder: (context) {
          final luck = ref.watch(avatarProvider).luckBonus;
          final rarity = ref.watch(avatarProvider).rarityTier;
          if (luck <= 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: FlitColors.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  '$rarity avatar: +$luck luck',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      if (!_canAfford(coins)) ...[
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Not enough coins. Play or ',
                style: TextStyle(color: FlitColors.error, fontSize: 12),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShopScreen(initialTabIndex: 2),
                    ),
                  ),
                  child: const Text(
                    'buy',
                    style: TextStyle(
                      color: FlitColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: FlitColors.accent,
                    ),
                  ),
                ),
              ),
              const TextSpan(
                text: ' more coins.',
                style: TextStyle(color: FlitColors.error, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

// =============================================================================
// _AnimBuilder helper
// =============================================================================

class _AnimBuilder extends AnimatedWidget {
  const _AnimBuilder({
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// =============================================================================
// Rarity badge
// =============================================================================

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({
    required this.tier,
    required this.color,
    required this.isPerfect,
    required this.animation,
  });

  final String tier;
  final Color color;
  final bool isPerfect;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (isPerfect) {
      return _AnimBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final hue = (t * 360) % 360;
          final rainbowColor = HSVColor.fromAHSV(1, hue, 0.8, 1).toColor();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rainbowColor,
                  HSVColor.fromAHSV(1, (hue + 60) % 360, 0.8, 1).toColor(),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PERFECT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// Wide stat bar (stretches across the full license width)
// =============================================================================

class _WideStatBar extends StatelessWidget {
  const _WideStatBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.shimmer,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final int value;
  final Animation<double> shimmer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statColor(value);
    final isMax = value >= 25;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label row: icon + label + value
          Row(
            children: [
              Icon(icon, color: color, size: 11),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
              Text(
                '$value/25',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Full-width segmented bar
          SizedBox(
            height: 10,
            width: double.infinity,
            child: isMax
                ? _AnimBuilder(
                    animation: shimmer,
                    builder: (context, _) => _buildSegments(color, isMax),
                  )
                : _buildSegments(color, isMax),
          ),
        ],
      ),
    );
  }

  Widget _buildSegments(Color color, bool isMax) => Row(
    children: List.generate(25, (i) {
      final filled = i < value;
      final isLastFilled = i == value - 1 && isMax;
      final baseOpacity = filled ? 1.0 : 0.15;
      final opacity = isLastFilled
          ? 0.7 + 0.3 * math.sin(shimmer.value * 2 * math.pi)
          : baseOpacity;

      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: i < 24 ? 0.5 : 0),
          height: 10,
          decoration: BoxDecoration(
            color: filled
                ? color.withOpacity(opacity)
                : FlitColors.backgroundLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }),
  );
}

// =============================================================================
// Clue type info row (no bar — just displays the type and boost %)
// =============================================================================

class _ClueTypeRow extends StatelessWidget {
  const _ClueTypeRow({
    required this.preferredType,
    required this.clueBoost,
    this.onTap,
  });

  final String preferredType;
  final int clueBoost;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typeLabel =
        '${preferredType[0].toUpperCase()}${preferredType.substring(1)}';

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: FlitColors.accent,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            'Preferred: $typeLabel',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '+$clueBoost% boost',
            style: const TextStyle(
              color: FlitColors.accent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Lock row
// =============================================================================

class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isLocked,
    required this.cost,
    required this.onChanged,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isLocked;
  final int cost;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!isLocked),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocked
            ? FlitColors.accent.withOpacity(0.1)
            : FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked
              ? FlitColors.accent.withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isLocked ? FlitColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isLocked ? FlitColors.accent : FlitColors.textMuted,
                width: 1.5,
              ),
            ),
            child: isLocked
                ? const Icon(
                    Icons.lock,
                    size: 14,
                    color: FlitColors.textPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Icon(icon, color: FlitColors.textSecondary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                size: 13,
                color: FlitColors.warning,
              ),
              const SizedBox(width: 3),
              Text(
                '+$cost',
                style: TextStyle(
                  color: isLocked ? FlitColors.warning : FlitColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
