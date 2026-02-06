import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
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
      return _goldColor; // fallback; Perfect uses gradient
    default:
      return _bronzeColor;
  }
}

/// Returns the stat bar segment color based on the boost value (1-10).
Color _statColor(int value) {
  if (value >= 10) return const Color(0xFFFFD700); // gold
  if (value >= 9) return const Color(0xFFFF8C00); // orange
  if (value >= 7) return const Color(0xFF9B59B6); // purple
  if (value >= 4) return const Color(0xFF4A90D9); // blue
  return const Color(0xFF6AAB5C); // green
}

/// Icon for a preferred clue type label.
IconData _clueTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'text':
      return Icons.text_fields;
    case 'image':
      return Icons.image;
    case 'audio':
      return Icons.headphones;
    case 'map':
      return Icons.map;
    case 'flag':
      return Icons.flag;
    case 'compass':
      return Icons.explore;
    default:
      return Icons.help_outline;
  }
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
  bool _lockType = false;
  bool _isRolling = false;

  // Animation for the perfect-rarity shimmer and max-stat pulse.
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _license = PilotLicense.random();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cost helpers
  // ---------------------------------------------------------------------------

  int get _totalCost {
    var cost = PilotLicense.rerollAllCost;
    for (final stat in _lockedStats) {
      // Scale cost based on the value of the stat being locked
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
    if (_lockType) cost += PilotLicense.lockTypeCost;
    return cost;
  }

  bool _canAfford(int coins) => coins >= _totalCost;

  // ---------------------------------------------------------------------------
  // Reroll
  // ---------------------------------------------------------------------------

  Future<void> _reroll() async {
    if (!_canAfford(ref.read(currentCoinsProvider)) || _isRolling) return;

    setState(() => _isRolling = true);

    // Brief suspense delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _license = PilotLicense.reroll(
        _license,
        lockedStats: _lockedStats,
        lockType: _lockType,
      );
      _isRolling = false;
    });
    ref.read(accountProvider.notifier).spendCoins(_totalCost);
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
            // Coin balance chip
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
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
              // ---- License card ----
              _buildLicenseCard(),
              const SizedBox(height: 24),

              // ---- Lock options ----
              _buildLockSection(coins),
              const SizedBox(height: 24),

              // ---- Reroll button ----
              _buildRerollButton(coins),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // License card
  // ---------------------------------------------------------------------------

  Widget _buildLicenseCard() {
    final rarity = _license.rarityTier;
    final rarityColor = _colorForRarity(rarity);
    final isPerfect = rarity == 'Perfect';

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        // For Perfect rarity, cycle through the rainbow for the border.
        final borderDecoration = isPerfect
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: SweepGradient(
                  center: Alignment.center,
                  startAngle: _shimmerController.value * 2 * math.pi,
                  colors: _perfectGradientColors,
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: rarityColor,
              );

        return Container(
          // Outer border container
          decoration: borderDecoration,
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: rarityColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: _isRolling
                ? _buildRollingPlaceholder()
                : _buildLicenseContent(rarityColor, isPerfect),
          ),
        );
      },
    );
  }

  Widget _buildRollingPlaceholder() => const SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(FlitColors.gold),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Rerolling...',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildLicenseContent(Color rarityColor, bool isPerfect) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + rarity badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FLIT PILOT LICENSE',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              _RarityBadge(
                tier: _license.rarityTier,
                color: rarityColor,
                isPerfect: isPerfect,
                animation: _shimmerController,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar
          Center(
            child: AvatarWidget(
              config: ref.watch(avatarProvider),
              size: 64,
            ),
          ),
          const SizedBox(height: 12),

          // Total boost
          Center(
            child: Column(
              children: [
                Text(
                  '+${_license.totalBoost}%',
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Text(
                  'TOTAL BOOST',
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat bars
          GestureDetector(
            onTap: () => _showEffectPopup('Coin Boost', 'Earn ${_license.coinBoost}% more coins from every game you play. Stacks with daily bonuses.', Icons.monetization_on),
            child: _StatBar(
              label: _license.coinBoostLabel,
              icon: Icons.monetization_on,
              value: _license.coinBoost,
              shimmer: _shimmerController,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showEffectPopup('Clue Boost', 'Increases the chance of receiving ${_license.preferredClueType} clues by ${_license.clueBoost}%. Your preferred clue type appears more often.', Icons.lightbulb_outline),
            child: _StatBar(
              label: _license.clueBoostLabel,
              icon: Icons.lightbulb_outline,
              value: _license.clueBoost,
              shimmer: _shimmerController,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showEffectPopup('Clue Chance', 'Increases the chance of receiving additional clues by ${_license.clueChance}%. More clues means more information to help you guess.', Icons.casino),
            child: _StatBar(
              label: _license.clueChanceLabel,
              icon: Icons.casino,
              value: _license.clueChance,
              shimmer: _shimmerController,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showEffectPopup('Fuel Boost', 'Extends your fuel/speed-boost duration in solo play by ${_license.fuelBoost}%. More fuel means more time to guess.', Icons.local_gas_station),
            child: _StatBar(
              label: _license.fuelBoostLabel,
              icon: Icons.local_gas_station,
              value: _license.fuelBoost,
              shimmer: _shimmerController,
            ),
          ),
          const SizedBox(height: 16),

          // Preferred clue type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _clueTypeIcon(_license.preferredClueType),
                  color: FlitColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Preferred: ${_license.preferredClueType}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
            Text(title, style: const TextStyle(color: FlitColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          description,
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

  // ---------------------------------------------------------------------------
  // Lock section
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
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
              ),
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
              label: 'Clue Boost',
              value: _license.clueBoostLabel,
              icon: Icons.lightbulb_outline,
              isLocked: _lockedStats.contains('clueBoost'),
              cost: _lockCostFor('clueBoost'),
              onChanged: (locked) => _toggleLock('clueBoost', locked),
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
              label: 'Fuel Boost',
              value: _license.fuelBoostLabel,
              icon: Icons.local_gas_station,
              isLocked: _lockedStats.contains('fuelBoost'),
              cost: _lockCostFor('fuelBoost'),
              onChanged: (locked) => _toggleLock('fuelBoost', locked),
            ),
            const SizedBox(height: 8),
            _LockRow(
              label: 'Clue Type',
              value: _license.preferredClueType,
              icon: _clueTypeIcon(_license.preferredClueType),
              isLocked: _lockType,
              cost: PilotLicense.lockTypeCost,
              onChanged: (locked) => setState(() => _lockType = locked),
            ),
            const Divider(color: FlitColors.cardBorder, height: 24),
            // Total cost summary
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
                        color: _canAfford(coins) ? FlitColors.warning : FlitColors.error,
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

  Widget _buildRerollButton(int coins) => Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _canAfford(coins) && !_isRolling ? _reroll : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canAfford(coins) ? FlitColors.accent : FlitColors.error.withOpacity(0.4),
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(FlitColors.textPrimary),
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
          if (!_canAfford(coins)) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
              ),
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Not enough coins. ',
                      style: TextStyle(color: FlitColors.error, fontSize: 12),
                    ),
                    TextSpan(
                      text: 'Play to earn more or buy from shop',
                      style: TextStyle(
                        color: FlitColors.accent,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}

// =============================================================================
// AnimatedBuilder helper (re-exports AnimatedBuilder for cleanliness)
// =============================================================================

/// Wrapper identical to [AnimatedBuilder] for readability.
class AnimatedBuilder extends AnimatedWidget {
  const AnimatedBuilder({
    super.key,
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
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          // Cycle through rainbow hue
          final hue = (t * 360) % 360;
          final rainbowColor =
              HSVColor.fromAHSV(1, hue, 0.8, 1).toColor();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rainbowColor,
                  HSVColor.fromAHSV(1, (hue + 60) % 360, 0.8, 1).toColor(),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PERFECT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// Stat bar (10-segment visual bar)
// =============================================================================

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.shimmer,
  });

  final String label;
  final IconData icon;
  final int value;
  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    final color = _statColor(value);
    final isMax = value >= 10;

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: isMax
              ? AnimatedBuilder(
                  animation: shimmer,
                  builder: (context, _) => _buildSegments(color, isMax),
                )
              : _buildSegments(color, isMax),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (isMax) ...[
          const SizedBox(width: 4),
          _PulsingDot(color: color, animation: shimmer),
        ],
      ],
    );
  }

  Widget _buildSegments(Color color, bool isMax) => LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: List.generate(10, (i) {
              final filled = i < value;
              final isLastFilled = i == value - 1 && isMax;
              final baseOpacity = filled ? 1.0 : 0.15;
              // For max stats, add a subtle pulse to the last segment
              final opacity = isLastFilled
                  ? 0.7 + 0.3 * math.sin(shimmer.value * 2 * math.pi)
                  : baseOpacity;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 9 ? 2 : 0),
                  height: 10,
                  decoration: BoxDecoration(
                    color: filled
                        ? color.withOpacity(opacity)
                        : FlitColors.backgroundLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isLastFilled
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          );
        },
      );
}

// =============================================================================
// Pulsing dot indicator for max stats
// =============================================================================

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({
    required this.color,
    required this.animation,
  });

  final Color color;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final scale = 0.8 + 0.4 * math.sin(animation.value * 2 * math.pi);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      );
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
              // Checkbox visual
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isLocked
                      ? FlitColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isLocked
                        ? FlitColors.accent
                        : FlitColors.textMuted,
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
              // Cost indicator
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
                      color: isLocked
                          ? FlitColors.warning
                          : FlitColors.textMuted,
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
