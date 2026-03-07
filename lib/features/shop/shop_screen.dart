import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/economy_config.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/economy_config_service.dart';
import '../../game/rendering/plane_renderer.dart';

/// Shop screen for purchasing cosmetics and gold.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialTabIndex = 0});

  /// Which tab to show initially: 0 = Planes, 1 = Contrails, 2 = Companions, 3 = Gold.
  final int initialTabIndex;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EconomyConfig _economyConfig = EconomyConfig.defaults();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    // Pull latest server state so purchases made via RPC are reflected.
    ref.read(accountProvider.notifier).refreshFromServer();
    // Fetch economy config for dynamic pricing and promotions.
    EconomyConfigService.instance.getConfig().then((config) {
      if (mounted) setState(() => _economyConfig = config);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Build the set of all cosmetic IDs the player owns (defaults + equipped +
  /// persisted purchases).
  Set<String> _buildOwnedIds(AccountState account) {
    return {
      'plane_default',
      'contrail_default',
      'companion_none',
      account.equippedPlaneId,
      account.equippedContrailId,
      'companion_${account.avatar.companion.name}',
      ...account.ownedCosmetics,
    };
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final coins = account.currentPlayer.coins;
    final level = account.currentPlayer.level;
    final ownedIds = _buildOwnedIds(account);
    final equippedPlane = account.equippedPlaneId;
    final equippedContrail = account.equippedContrailId;
    final equippedCompanion = 'companion_${account.avatar.companion.name}';
    final hasAnyPromo = _economyConfig.activePromotions.any(
      (p) =>
          p.type == PromotionType.shopDiscount || p.type == PromotionType.both,
    );
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor:
            hasAnyPromo ? const Color(0xFF2A2510) : FlitColors.backgroundMid,
        title: Text(hasAnyPromo ? 'Shop — SALE' : 'Shop'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: hasAnyPromo ? FlitColors.gold : FlitColors.accent,
          labelColor: FlitColors.textPrimary,
          unselectedLabelColor: FlitColors.textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Planes'),
            Tab(text: 'Contrails'),
            Tab(text: 'Companions'),
            Tab(text: 'Gold'),
          ],
        ),
        actions: [
          // Coin balance
          Container(
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
        ],
      ),
      body: Column(
        children: [
          // Promo banner when shop discount is active.
          if (hasAnyPromo) _PromoBanner(config: _economyConfig),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    _MysteryPlaneButton(
                      coins: coins,
                      ownedIds: ownedIds,
                      onReveal: (Cosmetic plane) {
                        ref.read(accountProvider.notifier).purchaseCosmetic(
                              plane.id,
                              _MysteryPlaneButton._mysteryCost,
                            );
                        setState(() {});
                      },
                    ),
                    Expanded(
                      child: _CosmeticGrid(
                        items: CosmeticCatalog.planes,
                        ownedIds: ownedIds,
                        equippedId: equippedPlane,
                        coins: coins,
                        level: level,
                        onPurchase: _purchaseItem,
                        onEquip: _equipPlane,
                        economyConfig: _economyConfig,
                      ),
                    ),
                  ],
                ),
                _CosmeticGrid(
                  items: CosmeticCatalog.contrails,
                  ownedIds: ownedIds,
                  equippedId: equippedContrail,
                  coins: coins,
                  level: level,
                  onPurchase: _purchaseItem,
                  onEquip: _equipContrail,
                  economyConfig: _economyConfig,
                ),
                _CosmeticGrid(
                  items: CosmeticCatalog.companions,
                  ownedIds: ownedIds,
                  equippedId: equippedCompanion,
                  coins: coins,
                  level: level,
                  onPurchase: _purchaseItem,
                  onEquip: _equipCompanion,
                  economyConfig: _economyConfig,
                ),
                _GoldShopTab(economyConfig: _economyConfig),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _purchaseItem(Cosmetic item) {
    final category = _categoryForType(item.type);
    final price = _economyConfig.effectivePrice(
      item.id,
      item.price,
      category: category,
    );
    final success =
        ref.read(accountProvider.notifier).purchaseCosmetic(item.id, price);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${item.name}!'),
          backgroundColor: FlitColors.success,
        ),
      );
    }
  }

  void _equipPlane(String id) {
    ref.read(accountProvider.notifier).equipPlane(id);
  }

  void _equipContrail(String id) {
    ref.read(accountProvider.notifier).equipContrail(id);
  }

  void _equipCompanion(String id) {
    ref.read(accountProvider.notifier).equipCompanion(id);
  }
}

// =============================================================================
// Rarity helpers
// =============================================================================

Color _rarityColor(CosmeticRarity rarity) {
  switch (rarity) {
    case CosmeticRarity.common:
      return const Color(0xFF8A8A8A); // gray
    case CosmeticRarity.rare:
      return const Color(0xFF4A90D9); // blue
    case CosmeticRarity.epic:
      return const Color(0xFF9B59B6); // purple
    case CosmeticRarity.legendary:
      return const Color(0xFFD4A944); // gold
  }
}

String _rarityLabel(CosmeticRarity rarity) {
  switch (rarity) {
    case CosmeticRarity.common:
      return 'COMMON';
    case CosmeticRarity.rare:
      return 'RARE';
    case CosmeticRarity.epic:
      return 'EPIC';
    case CosmeticRarity.legendary:
      return 'LEGENDARY';
  }
}

// =============================================================================
// Category helpers
// =============================================================================

/// Maps a [CosmeticType] to the promotion category string used by
/// [EconomyConfig.effectivePrice] and [Promotion.appliesToCategory].
String _categoryForType(CosmeticType type) {
  switch (type) {
    case CosmeticType.plane:
      return 'planes';
    case CosmeticType.contrail:
      return 'contrails';
    case CosmeticType.coPilot:
      return 'companions';
    default:
      return 'all';
  }
}

// =============================================================================
// Sale theme colors  (gold-themed palette for items on promotion)
// =============================================================================

/// Sale-themed colors used when a promotion is active.
abstract final class _SaleColors {
  static const Color border = Color(0xFFD4A944);
  static const Color borderGlow = Color(0x40D4A944);
  static const Color cardGradientStart = Color(0x18D4A944);
  static const Color cardGradientEnd = Color(0x08D4A944);
  static const Color bannerStart = Color(0xFFD4A944);
  static const Color bannerEnd = Color(0xFFE8C458);
  static const Color strikethroughText = Color(0xFFB8A890);
  static const Color strikethroughLine = Color(0xFFCC4444);
}

// =============================================================================
// Gold Shop Tab  (IAP placeholder)
// =============================================================================

class _GoldShopTab extends StatelessWidget {
  const _GoldShopTab({required this.economyConfig});

  final EconomyConfig economyConfig;

  @override
  Widget build(BuildContext context) {
    final configPkgs = economyConfig.effectiveGoldPackages;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: configPkgs.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: FlitColors.warning,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Buy Gold',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get coins to unlock planes and contrails',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          );
        }

        final pkg = configPkgs[index - 1];
        return _GoldPackageCard(package: pkg);
      },
    );
  }
}

class _GoldPackageCard extends StatelessWidget {
  const _GoldPackageCard({required this.package});

  final GoldPackageConfig package;

  @override
  Widget build(BuildContext context) {
    final hasPromo =
        package.promoPrice != null && package.promoPrice! < package.basePrice;
    final displayPrice = hasPromo ? package.promoPrice! : package.basePrice;
    final coinsPerDollar =
        displayPrice > 0 ? package.coins / displayPrice : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              gradient: hasPromo
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _SaleColors.cardGradientStart,
                        _SaleColors.cardGradientEnd,
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: package.isBestValue
                    ? FlitColors.warning
                    : (hasPromo ? _SaleColors.border : FlitColors.cardBorder),
                width: (package.isBestValue || hasPromo) ? 2.5 : 1,
              ),
              boxShadow: hasPromo
                  ? [
                      BoxShadow(
                        color: _SaleColors.borderGlow,
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Coin icon stack
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: FlitColors.warning.withOpacity(0.3),
                        size: 48,
                      ),
                      const Icon(
                        Icons.monetization_on,
                        color: FlitColors.warning,
                        size: 36,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${package.coins} Coins',
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (hasPromo) ...[
                            Text(
                              '\$${package.basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: _SaleColors.strikethroughText,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: _SaleColors.strikethroughLine,
                                decorationThickness: 2.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '\$${displayPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: hasPromo
                                  ? FlitColors.success
                                  : FlitColors.textSecondary,
                              fontSize: 14,
                              fontWeight: hasPromo
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (hasPromo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: FlitColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${((1 - displayPrice / package.basePrice) * 100).round()}% OFF',
                                style: const TextStyle(
                                  color: FlitColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${coinsPerDollar.toStringAsFixed(0)} coins/\$',
                        style: const TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Buy button
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming Soon'),
                        backgroundColor: FlitColors.backgroundMid,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent.withOpacity(0.4),
                    foregroundColor: FlitColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Coming Soon'),
                ),
              ],
            ),
          ),
          // Best Value badge
          if (package.isBestValue)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FlitColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: FlitColors.backgroundDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mystery Plane Button
// =============================================================================

class _MysteryPlaneButton extends StatelessWidget {
  const _MysteryPlaneButton({
    required this.coins,
    required this.ownedIds,
    required this.onReveal,
  });

  final int coins;
  final Set<String> ownedIds;
  final void Function(Cosmetic) onReveal;

  static const int _mysteryCost = 10000;

  /// Pick a random plane weighted by rarity:
  /// common 50%, rare 30%, epic 15%, legendary 5%
  Cosmetic? _rollPlane() {
    final unowned = CosmeticCatalog.planes
        .where((p) => !ownedIds.contains(p.id) && p.price > 0)
        .toList();
    if (unowned.isEmpty) return null;

    // Build a weighted pool
    final weights = <Cosmetic, int>{};
    for (final p in unowned) {
      switch (p.rarity) {
        case CosmeticRarity.common:
          weights[p] = 50;
        case CosmeticRarity.rare:
          weights[p] = 30;
        case CosmeticRarity.epic:
          weights[p] = 15;
        case CosmeticRarity.legendary:
          weights[p] = 5;
      }
    }

    final totalWeight = weights.values.fold<int>(0, (a, b) => a + b);
    var roll = math.Random().nextInt(totalWeight);
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return unowned.last;
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= _mysteryCost;

    return GestureDetector(
      onTap: () {
        if (!canAfford) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough coins! Need 10,000.'),
              backgroundColor: FlitColors.error,
            ),
          );
          return;
        }

        final plane = _rollPlane();
        if (plane == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already own all planes!'),
              backgroundColor: FlitColors.gold,
            ),
          );
          return;
        }

        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: FlitColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Mystery Plane',
              style: TextStyle(color: FlitColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, color: FlitColors.gold, size: 48),
                SizedBox(height: 12),
                Text(
                  'Spend 10,000 coins for a random plane weighted by rarity.\nRarer planes are harder to get!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: FlitColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onReveal(plane);

                  final rarityCol = _rarityColor(plane.rarity);

                  showDialog<void>(
                    context: context,
                    builder: (revealCtx) => AlertDialog(
                      backgroundColor: FlitColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'You got: ${plane.name}!',
                        style: const TextStyle(color: FlitColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: FlitColors.backgroundMid,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: rarityCol, width: 2),
                            ),
                            child: CustomPaint(
                              size: const Size(100, 100),
                              painter: PlanePainter(
                                planeId: plane.id,
                                colorScheme: plane.colorScheme,
                                wingSpan: plane.wingSpan ?? 26.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: rarityCol.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _rarityLabel(plane.rarity),
                              style: TextStyle(
                                color: rarityCol,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (plane.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              plane.description!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: FlitColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(revealCtx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlitColors.accent,
                            foregroundColor: FlitColors.textPrimary,
                          ),
                          child: const Text('Nice!'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.gold,
                  foregroundColor: FlitColors.backgroundDark,
                ),
                child: const Text('Roll!'),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FlitColors.gold.withOpacity(0.25),
              FlitColors.gold.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline, color: FlitColors.gold, size: 22),
            const SizedBox(width: 10),
            const Text(
              'MYSTERY PLANE',
              style: TextStyle(
                color: FlitColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: canAfford
                    ? FlitColors.gold.withOpacity(0.3)
                    : FlitColors.error.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on,
                    size: 14,
                    color: canAfford ? FlitColors.gold : FlitColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '10,000',
                    style: TextStyle(
                      color: canAfford ? FlitColors.gold : FlitColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
// Cosmetic Grid (Planes / Contrails)
// =============================================================================

class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({
    required this.items,
    required this.ownedIds,
    required this.equippedId,
    required this.coins,
    required this.level,
    required this.onPurchase,
    required this.onEquip,
    required this.economyConfig,
  });

  final List<Cosmetic> items;
  final Set<String> ownedIds;
  final String equippedId;
  final int coins;
  final int level;
  final void Function(Cosmetic) onPurchase;
  final void Function(String) onEquip;
  final EconomyConfig economyConfig;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isOwned = ownedIds.contains(item.id);
          final isEquipped = equippedId == item.id;
          final category = _categoryForType(item.type);
          final effectivePrice = economyConfig.effectivePrice(
            item.id,
            item.price,
            category: category,
          );
          final canAfford = coins >= effectivePrice;
          final meetsLevel =
              item.requiredLevel == null || level >= item.requiredLevel!;
          final isOnSale =
              !isOwned && meetsLevel && effectivePrice < item.price;

          return _CosmeticCard(
            item: item,
            isOwned: isOwned,
            isEquipped: isEquipped,
            canAfford: canAfford,
            meetsLevel: meetsLevel,
            effectivePrice: effectivePrice,
            isOnSale: isOnSale,
            onTap: () {
              if (isOwned) {
                _showOwnedDialog(context, item, isEquipped);
              } else if (meetsLevel) {
                _showPurchaseDialog(context, item, canAfford, effectivePrice);
              }
            },
          );
        },
      );

  void _showOwnedDialog(BuildContext context, Cosmetic item, bool isEquipped) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Text(
          item.name,
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: const Text(
          'You own this item.',
          style: TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          if (!isEquipped)
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                onEquip(item.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
              ),
              child: const Text('Equip'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _showGiftDialog(context, item);
            },
            icon: const Icon(Icons.card_giftcard, size: 16),
            label: const Text('Gift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.gold,
              foregroundColor: FlitColors.backgroundDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(
    BuildContext context,
    Cosmetic item,
    bool canAfford,
    int effectivePrice,
  ) {
    final deficit = effectivePrice - coins;
    final isDiscounted = effectivePrice < item.price;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Text(
          'Purchase ${item.name}?',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coin price row
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: canAfford ? FlitColors.warning : FlitColors.error,
                ),
                const SizedBox(width: 8),
                if (isDiscounted) ...[
                  Text(
                    '${item.price}',
                    style: const TextStyle(
                      color: _SaleColors.strikethroughText,
                      fontSize: 15,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _SaleColors.strikethroughLine,
                      decorationThickness: 2.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$effectivePrice coins',
                  style: TextStyle(
                    color: canAfford
                        ? (isDiscounted
                            ? FlitColors.success
                            : FlitColors.textPrimary)
                        : FlitColors.error,
                    fontSize: 18,
                    fontWeight:
                        isDiscounted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isDiscounted) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: FlitColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${((1 - effectivePrice / item.price) * 100).round()}% OFF',
                      style: const TextStyle(
                        color: FlitColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!canAfford) ...[
              const SizedBox(height: 8),
              Text(
                'You need $deficit more coins to buy this!',
                style: const TextStyle(color: FlitColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () {
                    Navigator.of(dialogCtx).pop();
                    onPurchase(item);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford
                  ? FlitColors.accent
                  : FlitColors.textMuted.withOpacity(0.3),
              foregroundColor: FlitColors.textPrimary,
              disabledBackgroundColor: FlitColors.textMuted.withOpacity(0.3),
              disabledForegroundColor: FlitColors.textMuted,
            ),
            child: const Text('Buy'),
          ),
          ElevatedButton.icon(
            onPressed: canAfford
                ? () {
                    Navigator.of(dialogCtx).pop();
                    // Use the outer context (not the dialog context which
                    // is unmounted after pop) to open the gift dialog.
                    _showGiftDialog(context, item);
                  }
                : null,
            icon: const Icon(Icons.card_giftcard, size: 16),
            label: const Text('Gift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.gold,
              foregroundColor: FlitColors.backgroundDark,
              disabledBackgroundColor: FlitColors.textMuted.withOpacity(0.3),
              disabledForegroundColor: FlitColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showGiftDialog(BuildContext context, Cosmetic item) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Text(
          'Gift ${item.name}',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send this item to a friend!',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: FlitColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Friend\'s username',
                hintStyle: const TextStyle(color: FlitColors.textMuted),
                prefixText: '@',
                prefixStyle: const TextStyle(color: FlitColors.textSecondary),
                filled: true,
                fillColor: FlitColors.backgroundMid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gift sent to @${controller.text}!'),
                  backgroundColor: FlitColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.gold,
              foregroundColor: FlitColors.backgroundDark,
            ),
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cosmetic Card
// =============================================================================

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.item,
    required this.isOwned,
    required this.isEquipped,
    required this.canAfford,
    required this.meetsLevel,
    required this.onTap,
    this.effectivePrice,
    this.isOnSale = false,
  });

  final Cosmetic item;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final bool meetsLevel;
  final VoidCallback onTap;
  final int? effectivePrice;
  final bool isOnSale;

  @override
  Widget build(BuildContext context) {
    final isLocked = !meetsLevel;
    final rarityCol = _rarityColor(item.rarity);

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          gradient: isOnSale
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _SaleColors.cardGradientStart,
                    _SaleColors.cardGradientEnd,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped
                ? FlitColors.success
                : isOnSale
                    ? _SaleColors.border
                    : isLocked
                        ? FlitColors.textMuted
                        : FlitColors.cardBorder,
            width: isEquipped ? 2 : (isOnSale ? 2.5 : 1),
          ),
          boxShadow: isOnSale
              ? [
                  BoxShadow(
                    color: _SaleColors.borderGlow,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview area
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlitColors.backgroundMid,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: item.type == CosmeticType.plane
                            ? CustomPaint(
                                size: const Size(80, 80),
                                painter: PlanePainter(
                                  planeId: item.id,
                                  colorScheme: item.colorScheme,
                                  wingSpan: item.wingSpan ?? 26.0,
                                ),
                              )
                            : item.type == CosmeticType.coPilot
                                ? _CompanionPreview(companionId: item.id)
                                : _ContrailPreview(
                                    colorScheme: item.colorScheme,
                                    isLocked: isLocked,
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Rarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: rarityCol.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _rarityLabel(item.rarity),
                      style: TextStyle(
                        color: rarityCol,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Name
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isLocked
                          ? FlitColors.textMuted
                          : FlitColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Plane attribute bars (only for planes with non-default attributes)
                  if (item.type == CosmeticType.plane &&
                      (item.handling != 1.0 ||
                          item.speed != 1.0 ||
                          item.fuelEfficiency != 1.0)) ...[
                    _AttrBar(
                      label: 'Handling',
                      value: item.handling,
                      color: FlitColors.accent,
                    ),
                    _AttrBar(
                      label: 'Speed',
                      value: item.speed,
                      color: FlitColors.success,
                    ),
                    _AttrBar(
                      label: 'Fuel Eff.',
                      value: item.fuelEfficiency,
                      color: FlitColors.warning,
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Price or status
                  if (isOwned)
                    Text(
                      isEquipped ? 'Equipped' : 'Owned',
                      style: TextStyle(
                        color: isEquipped
                            ? FlitColors.success
                            : FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else if (isLocked)
                    Text(
                      'Level ${item.requiredLevel}',
                      style: const TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 12,
                      ),
                    )
                  else
                    _PriceRow(
                      item: item,
                      canAfford: canAfford,
                      effectivePrice: effectivePrice,
                    ),
                ],
              ),
            ),
            // Lock overlay
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundDark.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      color: FlitColors.textMuted,
                      size: 32,
                    ),
                  ),
                ),
              ),
            // Equipped badge
            if (isEquipped)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'IN USE',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Premium badge
            if (item.isPremium && !isOwned)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4A944), Color(0xFFE8C458)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            // Sale badge
            if (isOnSale)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_SaleColors.bannerStart, _SaleColors.bannerEnd],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: _SaleColors.borderGlow, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    '-${((1 - (effectivePrice ?? item.price) / item.price) * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Attribute Bar  (compact stat indicator for plane cards)
// =============================================================================

class _AttrBar extends StatelessWidget {
  const _AttrBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Map value range [0.5 – 1.5] → [0.0 – 1.0] for display.
    final pct = ((value - 0.5) / 1.0).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Price Row  (coin price + optional real-money price)
// =============================================================================

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.item,
    required this.canAfford,
    this.effectivePrice,
  });

  final Cosmetic item;
  final bool canAfford;
  final int? effectivePrice;

  @override
  Widget build(BuildContext context) {
    final price = effectivePrice ?? item.price;
    final isDiscounted = price < item.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.monetization_on,
              size: 14,
              color: canAfford ? FlitColors.warning : FlitColors.error,
            ),
            const SizedBox(width: 4),
            if (isDiscounted) ...[
              Text(
                item.price.toString(),
                style: const TextStyle(
                  color: _SaleColors.strikethroughText,
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _SaleColors.strikethroughLine,
                  decorationThickness: 2.0,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              price.toString(),
              style: TextStyle(
                color: isDiscounted
                    ? FlitColors.success
                    : (canAfford ? FlitColors.warning : FlitColors.error),
                fontSize: isDiscounted ? 13 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Promo Banner
// =============================================================================

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.config});

  final EconomyConfig config;

  String _categoryLabel(List<String> categories) {
    if (categories.isEmpty || categories.contains('all')) return 'all items';
    final labels = categories.map((c) {
      switch (c) {
        case 'planes':
          return 'planes';
        case 'contrails':
          return 'contrails';
        case 'companions':
          return 'companions';
        case 'gold':
          return 'gold packages';
        default:
          return c;
      }
    }).toList();
    if (labels.length == 1) return labels.first;
    return '${labels.sublist(0, labels.length - 1).join(', ')} & ${labels.last}';
  }

  @override
  Widget build(BuildContext context) {
    final shopPromos = config.activePromotions.where(
      (p) =>
          p.type == PromotionType.shopDiscount || p.type == PromotionType.both,
    );
    if (shopPromos.isEmpty) return const SizedBox.shrink();
    final bestDiscount = shopPromos
        .map((p) => p.shopDiscountPercent)
        .reduce((a, b) => a > b ? a : b);
    final promoName = shopPromos.first.name;
    final categoryText = _categoryLabel(shopPromos.first.appliesTo);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF3D3015), // dark gold bg
            Color(0xFF2A2510),
          ],
        ),
        border: Border(bottom: BorderSide(color: _SaleColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _SaleColors.border.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer,
              color: _SaleColors.border,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promoName,
                  style: const TextStyle(
                    color: _SaleColors.bannerEnd,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bestDiscount% off $categoryText!',
                  style: TextStyle(
                    color: FlitColors.textPrimary.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_SaleColors.bannerStart, _SaleColors.bannerEnd],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$bestDiscount% OFF',
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Contrail Preview  (simple colored gradient bar)
// =============================================================================

class _ContrailPreview extends StatelessWidget {
  const _ContrailPreview({required this.colorScheme, required this.isLocked});

  final Map<String, int>? colorScheme;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    if (isLocked || colorScheme == null) {
      return Icon(
        Icons.blur_on,
        size: 48,
        color: isLocked ? FlitColors.textMuted : FlitColors.accent,
      );
    }
    final primary = Color(colorScheme!['primary'] ?? 0xFFFFFFFF);
    final secondary = Color(colorScheme!['secondary'] ?? 0xFFFFFFFF);

    return CustomPaint(
      size: const Size(80, 80),
      painter: _ContrailPainter(primary: primary, secondary: secondary),
    );
  }
}

class _ContrailPainter extends CustomPainter {
  _ContrailPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw a series of fading dots trailing to the left
    for (var i = 0; i < 8; i++) {
      final t = i / 7.0;
      final x = cx + 28 - i * 8.0;
      final y = cy + math.sin(i * 0.6) * 4;
      final radius = 6.0 - i * 0.5;
      final color = Color.lerp(
        primary,
        secondary,
        t,
      )!
          .withOpacity(1.0 - t * 0.7);
      canvas.drawCircle(
        Offset(x, y),
        radius.clamp(1.5, 6.0),
        Paint()..color = color,
      );
    }

    // Leading dot (bright)
    canvas.drawCircle(
      Offset(cx + 30, cy),
      3,
      Paint()..color = FlitColors.textPrimary,
    );
  }

  @override
  bool shouldRepaint(covariant _ContrailPainter oldDelegate) =>
      primary != oldDelegate.primary || secondary != oldDelegate.secondary;
}

// =============================================================================
// Companion Preview  (icon-based preview for companion creatures)
// =============================================================================

class _CompanionPreview extends StatelessWidget {
  const _CompanionPreview({required this.companionId});

  final String companionId;

  @override
  Widget build(BuildContext context) {
    if (companionId == 'companion_none') {
      return const Icon(Icons.block, size: 48, color: FlitColors.textMuted);
    }
    return CustomPaint(
      size: const Size(64, 64),
      painter: _CompanionPreviewPainter(companionId: companionId),
    );
  }
}

class _CompanionPreviewPainter extends CustomPainter {
  _CompanionPreviewPainter({required this.companionId});

  final String companionId;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);

    // Scale so each creature's coordinate system maps nicely into preview.
    final scale = size.shortestSide / 64;
    canvas.scale(scale);

    switch (companionId) {
      case 'companion_pidgey':
        _paintPidgey(canvas);
      case 'companion_sparrow':
        _paintSparrow(canvas);
      case 'companion_eagle':
        _paintEagle(canvas);
      case 'companion_parrot':
        _paintParrot(canvas);
      case 'companion_phoenix':
        _paintPhoenix(canvas);
      case 'companion_dragon':
        _paintDragon(canvas);
      case 'companion_charizard':
        _paintCharizard(canvas);
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Pidgey — Adorable chibi bird with rosy cheeks and big eyes.
  // ---------------------------------------------------------------------------
  void _paintPidgey(Canvas canvas) {
    const s = 14.0; // doubled from in-game 7.0 for preview clarity
    const brown = Color(0xFF9E7B5A);
    const cream = Color(0xFFF5E8D0);
    const darkBrown = Color(0xFF6B5238);

    // Soft drop shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0.5, s * 0.22),
        width: s * 1.0,
        height: s * 0.3,
      ),
      Paint()
        ..color = const Color(0xFF000000).withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Tail feathers.
    _drawTailFeathers(canvas, s, darkBrown, 3, 0.35, 0.12);

    // Wings (spread, static flapOffset=0).
    _drawWing(canvas, s, 0, darkBrown.withOpacity(0.85), true, 0.7, 2);
    _drawWing(canvas, s, 0, darkBrown.withOpacity(0.85), false, 0.7, 2);

    // Pudgy body.
    _drawBody(canvas, s * 0.95, s * 0.6, brown, cream);

    // Round head.
    canvas.drawCircle(
      const Offset(0, -s * 0.32),
      s * 0.28,
      Paint()..color = brown,
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.18,
      Paint()..color = cream,
    );
    canvas.drawCircle(
      const Offset(-s * 0.05, -s * 0.42),
      s * 0.08,
      Paint()..color = _lighten(brown, 0.15).withOpacity(0.5),
    );

    // Big cute eyes.
    _drawEyes(
      canvas,
      const Offset(-s * 0.1, -s * 0.35),
      const Offset(s * 0.1, -s * 0.35),
      s * 0.07,
    );

    // Tiny beak.
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.52),
      s * 0.15,
      const Color(0xFFE8962A),
    );

    // Rosy cheeks.
    canvas.drawCircle(
      const Offset(-s * 0.15, -s * 0.26),
      s * 0.05,
      Paint()..color = const Color(0xFFE88080).withOpacity(0.35),
    );
    canvas.drawCircle(
      const Offset(s * 0.15, -s * 0.26),
      s * 0.05,
      Paint()..color = const Color(0xFFE88080).withOpacity(0.35),
    );
  }

  // ---------------------------------------------------------------------------
  // Sparrow — Sleek barn swallow with navy back, forked tail.
  // ---------------------------------------------------------------------------
  void _paintSparrow(Canvas canvas) {
    const s = 16.0;
    const navy = Color(0xFF2C3E6B);
    const russet = Color(0xFFB85C38);
    const cream = Color(0xFFF0E6D4);

    // Forked tail.
    final leftFork = Path()
      ..moveTo(-s * 0.05, s * 0.2)
      ..quadraticBezierTo(-s * 0.2, s * 0.55, -s * 0.18, s * 0.7)
      ..quadraticBezierTo(-s * 0.12, s * 0.5, -s * 0.02, s * 0.35)
      ..close();
    final rightFork = Path()
      ..moveTo(s * 0.05, s * 0.2)
      ..quadraticBezierTo(s * 0.2, s * 0.55, s * 0.18, s * 0.7)
      ..quadraticBezierTo(s * 0.12, s * 0.5, s * 0.02, s * 0.35)
      ..close();
    canvas.drawPath(leftFork, Paint()..color = navy);
    canvas.drawPath(rightFork, Paint()..color = navy);

    // Long swept wings.
    _drawWing(
      canvas,
      s,
      0,
      navy.withOpacity(0.9),
      true,
      0.95,
      4,
      tipColor: const Color(0xFF1A2A4D),
    );
    _drawWing(
      canvas,
      s,
      0,
      navy.withOpacity(0.9),
      false,
      0.95,
      4,
      tipColor: const Color(0xFF1A2A4D),
    );

    // Streamlined body.
    _drawBody(canvas, s * 0.8, s * 0.45, navy, cream);

    // Head.
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.18,
      Paint()..color = navy,
    );
    // Russet throat patch.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.2),
        width: s * 0.2,
        height: s * 0.12,
      ),
      Paint()..color = russet,
    );

    // Sharp eyes.
    _drawEyes(
      canvas,
      const Offset(-s * 0.07, -s * 0.31),
      const Offset(s * 0.07, -s * 0.31),
      s * 0.04,
      irisColor: const Color(0xFF111122),
    );

    // Small pointed beak.
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.44),
      s * 0.12,
      const Color(0xFF2A2A2A),
    );
  }

  // ---------------------------------------------------------------------------
  // Eagle — Majestic golden raptor with white head.
  // ---------------------------------------------------------------------------
  void _paintEagle(Canvas canvas) {
    const s = 20.0;
    const darkBrown = Color(0xFF4A3222);
    const goldenBrown = Color(0xFF8B6B3A);
    const white = Color(0xFFF5F0E8);
    const gold = Color(0xFFD4A030);

    // Broad fanned tail.
    _drawTailFeathers(canvas, s, darkBrown, 5, 0.45, 0.2);

    // Massive soaring wings.
    _drawWing(
      canvas,
      s,
      0,
      goldenBrown.withOpacity(0.9),
      true,
      1.15,
      5,
      tipColor: darkBrown,
    );
    _drawWing(
      canvas,
      s,
      0,
      goldenBrown.withOpacity(0.9),
      false,
      1.15,
      5,
      tipColor: darkBrown,
    );

    // Wing bar pattern.
    for (final sign in [-1.0, 1.0]) {
      final bar = Path()
        ..moveTo(sign * s * 0.4, -s * 0.2)
        ..lineTo(sign * s * 0.8, -s * 0.32)
        ..lineTo(sign * s * 0.82, -s * 0.27)
        ..lineTo(sign * s * 0.42, -s * 0.15)
        ..close();
      canvas.drawPath(bar, Paint()..color = gold.withOpacity(0.3));
    }

    // Powerful body.
    _drawBody(canvas, s * 0.85, s * 0.5, goldenBrown, const Color(0xFFE8D8B8));

    // White head.
    canvas.drawCircle(
      const Offset(0, -s * 0.32),
      s * 0.22,
      Paint()..color = white,
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.18,
      Paint()..color = const Color(0xFFE8E0D0),
    );

    // Fierce eyes.
    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.34),
      const Offset(s * 0.08, -s * 0.34),
      s * 0.04,
      irisColor: const Color(0xFFCC8800),
      fierce: true,
    );

    // Prominent hooked beak.
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.52),
      s * 0.18,
      const Color(0xFFE8A820),
      hooked: true,
    );

    // Brow ridges.
    canvas.drawLine(
      const Offset(-s * 0.14, -s * 0.38),
      const Offset(-s * 0.03, -s * 0.36),
      Paint()
        ..color = const Color(0xFFD0C8B8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(s * 0.14, -s * 0.38),
      const Offset(s * 0.03, -s * 0.36),
      Paint()
        ..color = const Color(0xFFD0C8B8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Parrot — Vivid scarlet macaw with multicolor wings and tail streamers.
  // ---------------------------------------------------------------------------
  void _paintParrot(Canvas canvas) {
    const s = 16.0;
    const scarlet = Color(0xFFDD2828);
    const royalBlue = Color(0xFF1845A0);
    const emerald = Color(0xFF22AA44);
    const gold = Color(0xFFFFCC22);
    const white = Color(0xFFF8F4F0);

    // Long tail streamers.
    for (var i = 0; i < 3; i++) {
      final colors = [royalBlue, scarlet, emerald];
      final offsets = [-0.08, 0.0, 0.08];
      final lengths = [0.85, 0.95, 0.8];
      final streamer = Path()
        ..moveTo(s * offsets[i], s * 0.2)
        ..cubicTo(
          s * offsets[i] * 2,
          s * 0.5,
          s * offsets[i] * 0.5,
          s * 0.7,
          s * offsets[i] * 1.5,
          s * lengths[i],
        )
        ..quadraticBezierTo(
          s * offsets[i],
          s * (lengths[i] - 0.1),
          s * offsets[i] * 0.5,
          s * 0.2,
        )
        ..close();
      canvas.drawPath(streamer, Paint()..color = colors[i].withOpacity(0.85));
    }

    // Multicolored wings.
    for (final isLeft in [true, false]) {
      _drawWing(
        canvas,
        s,
        0,
        royalBlue.withOpacity(0.9),
        isLeft,
        0.85,
        3,
        tipColor: const Color(0xFF0D2D6B),
      );
      final sign = isLeft ? -1.0 : 1.0;
      // Green secondary band.
      final greenBand = Path()
        ..moveTo(sign * s * 0.25, -s * 0.05)
        ..lineTo(sign * s * 0.55, -s * 0.25)
        ..lineTo(sign * s * 0.58, -s * 0.18)
        ..lineTo(sign * s * 0.28, s * 0.02)
        ..close();
      canvas.drawPath(greenBand, Paint()..color = emerald.withOpacity(0.7));
      // Gold covert stripe.
      final goldStripe = Path()
        ..moveTo(sign * s * 0.2, 0)
        ..lineTo(sign * s * 0.45, -s * 0.12)
        ..lineTo(sign * s * 0.47, -s * 0.08)
        ..lineTo(sign * s * 0.22, s * 0.04)
        ..close();
      canvas.drawPath(goldStripe, Paint()..color = gold.withOpacity(0.5));
    }

    // Scarlet body.
    _drawBody(canvas, s * 0.8, s * 0.48, scarlet, const Color(0xFFEE5555));

    // Round head.
    canvas.drawCircle(
      const Offset(0, -s * 0.3),
      s * 0.2,
      Paint()..color = scarlet,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.38),
      s * 0.06,
      Paint()..color = _lighten(scarlet, 0.15).withOpacity(0.4),
    );

    // White eye patches.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-s * 0.09, -s * 0.3),
        width: s * 0.12,
        height: s * 0.14,
      ),
      Paint()..color = white.withOpacity(0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(s * 0.09, -s * 0.3),
        width: s * 0.12,
        height: s * 0.14,
      ),
      Paint()..color = white.withOpacity(0.85),
    );

    // Eyes.
    _drawEyes(
      canvas,
      const Offset(-s * 0.09, -s * 0.31),
      const Offset(s * 0.09, -s * 0.31),
      s * 0.04,
      irisColor: const Color(0xFF222222),
    );

    // Curved parrot beak.
    final upperBeak = Path()
      ..moveTo(0, -s * 0.42)
      ..cubicTo(-s * 0.1, -s * 0.48, -s * 0.08, -s * 0.56, 0, -s * 0.58)
      ..cubicTo(s * 0.08, -s * 0.56, s * 0.1, -s * 0.48, 0, -s * 0.42);
    canvas.drawPath(upperBeak, Paint()..color = const Color(0xFF1A1A1A));
    final lowerBeak = Path()
      ..moveTo(-s * 0.04, -s * 0.42)
      ..quadraticBezierTo(0, -s * 0.46, s * 0.04, -s * 0.42)
      ..quadraticBezierTo(0, -s * 0.39, -s * 0.04, -s * 0.42);
    canvas.drawPath(lowerBeak, Paint()..color = const Color(0xFF333333));
  }

  // ---------------------------------------------------------------------------
  // Phoenix — Ethereal fire bird with warm aura glow and flame crest.
  // ---------------------------------------------------------------------------
  void _paintPhoenix(Canvas canvas) {
    const s = 18.0;
    const deepOrange = Color(0xFFE85D04);
    const brightOrange = Color(0xFFFF8C22);
    const gold = Color(0xFFFFCC00);
    const paleGold = Color(0xFFFFE888);
    const crimson = Color(0xFFCC1100);

    // Warm aura.
    canvas.drawCircle(
      Offset.zero,
      s * 0.9,
      Paint()
        ..color = const Color(0xFFFF6600).withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.1),
      s * 0.5,
      Paint()
        ..color = gold.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Flame tail tongues.
    final tongueColors = [crimson, deepOrange, gold, brightOrange, crimson];
    for (var i = 0; i < 5; i++) {
      final t = (i - 2) * 0.06;
      final tongue = Path()
        ..moveTo(s * t, s * 0.2)
        ..cubicTo(
          s * t,
          s * 0.5,
          s * t * 2,
          s * 0.7,
          s * t * 1.5,
          s * (0.75 + i * 0.06),
        )
        ..quadraticBezierTo(s * t, s * (0.6 + i * 0.03), s * t * 0.5, s * 0.2)
        ..close();
      canvas.drawPath(
        tongue,
        Paint()..color = tongueColors[i].withOpacity(0.7),
      );
    }

    // Flame wings.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      // Wing glow.
      final glowWing = Path()
        ..moveTo(sign * s * 0.15, 0)
        ..cubicTo(
          sign * s * 0.5,
          -s * 0.3,
          sign * s * 0.8,
          -s * 0.55,
          sign * s * 1.05,
          -s * 0.15,
        )
        ..lineTo(sign * s * 0.1, s * 0.05)
        ..close();
      canvas.drawPath(
        glowWing,
        Paint()
          ..color = gold.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      _drawWing(
        canvas,
        s,
        0,
        deepOrange.withOpacity(0.85),
        isLeft,
        1.05,
        4,
        tipColor: crimson.withOpacity(0.8),
      );
    }

    // Luminous body.
    _drawBody(canvas, s * 0.75, s * 0.42, deepOrange, paleGold);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.5, height: s * 0.25),
      Paint()
        ..color = gold.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Elegant head.
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.18,
      Paint()..color = brightOrange,
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.12,
      Paint()
        ..color = gold.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Crown crest — three flame plumes.
    final plumeColors = [crimson, gold, deepOrange];
    final plumeLengths = [s * 0.28, s * 0.35, s * 0.25];
    for (var i = 0; i < 3; i++) {
      final offX = (i - 1) * s * 0.08;
      final plume = Path()
        ..moveTo(offX, -s * 0.42)
        ..quadraticBezierTo(
          offX,
          -s * 0.42 - plumeLengths[i] * 0.6,
          offX * 0.5,
          -s * 0.42 - plumeLengths[i],
        )
        ..quadraticBezierTo(
          offX,
          -s * 0.42 - plumeLengths[i] * 0.4,
          offX,
          -s * 0.42,
        )
        ..close();
      canvas.drawPath(plume, Paint()..color = plumeColors[i].withOpacity(0.8));
    }

    // Bright eyes.
    _drawEyes(
      canvas,
      const Offset(-s * 0.07, -s * 0.3),
      const Offset(s * 0.07, -s * 0.3),
      s * 0.035,
      irisColor: const Color(0xFFFFDD00),
    );

    // Small beak.
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.44),
      s * 0.1,
      const Color(0xFFCC6600),
    );
  }

  // ---------------------------------------------------------------------------
  // Dragon — Western wyvern with bat-membrane wings, horns, fire tail.
  // ---------------------------------------------------------------------------
  void _paintDragon(Canvas canvas) {
    const s = 20.0;
    const forestGreen = Color(0xFF2D6B3F);
    const darkGreen = Color(0xFF1A4228);
    const paleGreen = Color(0xFFA8D8A0);
    const amber = Color(0xFFE8A820);
    const hornColor = Color(0xFF5C4A32);

    // Spined tail with flame tip.
    final tail = Path()
      ..moveTo(0, s * 0.25)
      ..cubicTo(-s * 0.08, s * 0.5, -s * 0.15, s * 0.7, -s * 0.08, s * 0.85)
      ..lineTo(0, s * 0.78)
      ..lineTo(s * 0.08, s * 0.85)
      ..cubicTo(s * 0.15, s * 0.7, s * 0.08, s * 0.5, 0, s * 0.25)
      ..close();
    canvas.drawPath(tail, Paint()..color = forestGreen);
    // Tail spines.
    for (var i = 0; i < 3; i++) {
      final t = 0.35 + i * 0.15;
      final spine = Path()
        ..moveTo(-s * 0.02, s * t)
        ..lineTo(-s * 0.06, s * t - s * 0.04)
        ..lineTo(0, s * t - s * 0.01)
        ..close();
      canvas.drawPath(spine, Paint()..color = darkGreen);
    }
    // Flame tail tip.
    final flameTip = Path()
      ..moveTo(-s * 0.08, s * 0.82)
      ..lineTo(-s * 0.1, s * 0.96)
      ..lineTo(0, s * 0.9)
      ..lineTo(s * 0.1, s * 0.96)
      ..lineTo(s * 0.08, s * 0.82)
      ..close();
    canvas.drawPath(flameTip, Paint()..color = const Color(0xFFFF6600));
    canvas.drawPath(
      flameTip,
      Paint()
        ..color = amber.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Bat-like membrane wings with finger bones.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      final membrane = Path()
        ..moveTo(sign * s * 0.3, -s * 0.05)
        ..lineTo(sign * s * 0.95, -s * 0.7)
        ..quadraticBezierTo(
          sign * s * 0.7,
          -s * 0.3,
          sign * s * 0.75,
          -s * 0.28,
        )
        ..lineTo(sign * s * 1.15, -s * 0.45)
        ..quadraticBezierTo(
          sign * s * 0.85,
          -s * 0.12,
          sign * s * 0.88,
          -s * 0.08,
        )
        ..lineTo(sign * s * 1.05, -s * 0.15)
        ..quadraticBezierTo(sign * s * 0.7, s * 0.05, sign * s * 0.15, s * 0.02)
        ..close();
      canvas.drawPath(
        membrane,
        Paint()..color = const Color(0xFF3D8B55).withOpacity(0.7),
      );
      canvas.drawPath(membrane, Paint()..color = paleGreen.withOpacity(0.1));

      // Finger bones.
      final bonePaint = Paint()
        ..color = darkGreen.withOpacity(0.7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(sign * s * 0.3, -s * 0.05),
        Offset(sign * s * 0.65, -s * 0.35),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.65, -s * 0.35),
        Offset(sign * s * 0.95, -s * 0.7),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.65, -s * 0.35),
        Offset(sign * s * 1.15, -s * 0.45),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.65, -s * 0.35),
        Offset(sign * s * 1.05, -s * 0.15),
        bonePaint,
      );
    }

    // Muscular body.
    _drawBody(canvas, s * 0.85, s * 0.52, forestGreen, paleGreen);
    // Scale chevrons.
    for (var i = 0; i < 4; i++) {
      final sy = -s * 0.08 + i * s * 0.06;
      canvas.drawLine(
        Offset(-s * 0.12, sy),
        Offset(0, sy + s * 0.02),
        Paint()
          ..color = darkGreen.withOpacity(0.2)
          ..strokeWidth = 0.6,
      );
      canvas.drawLine(
        Offset(0, sy + s * 0.02),
        Offset(s * 0.12, sy),
        Paint()
          ..color = darkGreen.withOpacity(0.2)
          ..strokeWidth = 0.6,
      );
    }

    // Head.
    final snout = Path()
      ..moveTo(-s * 0.12, -s * 0.32)
      ..quadraticBezierTo(0, -s * 0.55, s * 0.12, -s * 0.32)
      ..quadraticBezierTo(0, -s * 0.28, -s * 0.12, -s * 0.32);
    canvas.drawPath(snout, Paint()..color = forestGreen);
    canvas.drawCircle(
      const Offset(0, -s * 0.34),
      s * 0.18,
      Paint()..color = forestGreen,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.3),
        width: s * 0.18,
        height: s * 0.08,
      ),
      Paint()..color = paleGreen.withOpacity(0.6),
    );

    // Horns.
    for (final sign in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(sign * s * 0.1, -s * 0.46)
        ..cubicTo(
          sign * s * 0.18,
          -s * 0.58,
          sign * s * 0.22,
          -s * 0.68,
          sign * s * 0.16,
          -s * 0.72,
        )
        ..lineTo(sign * s * 0.08, -s * 0.5)
        ..close();
      canvas.drawPath(horn, Paint()..color = hornColor);
    }

    // Fierce slit eyes.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(sign * s * 0.08, -s * 0.38),
        s * 0.04,
        Paint()
          ..color = amber.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.38),
          width: s * 0.06,
          height: s * 0.045,
        ),
        Paint()..color = amber,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.38),
          width: s * 0.015,
          height: s * 0.04,
        ),
        Paint()..color = const Color(0xFF111111),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Charizard — Ultimate flame dragon with scalloped wings and fire aura.
  // ---------------------------------------------------------------------------
  void _paintCharizard(Canvas canvas) {
    const s = 22.0;
    const deepOrange = Color(0xFFD85A10);
    const brightOrange = Color(0xFFFF8833);
    const paleYellow = Color(0xFFFFE8A0);
    const tealWing = Color(0xFF1B8B7A);
    const darkTeal = Color(0xFF0E5E52);
    const hornColor = Color(0xFF5C4432);
    const fireRed = Color(0xFFEE2200);
    const fireGold = Color(0xFFFFCC00);

    // Fiery aura.
    canvas.drawCircle(
      Offset.zero,
      s * 1.0,
      Paint()
        ..color = const Color(0xFFFF4400).withOpacity(0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.15),
      s * 0.55,
      Paint()
        ..color = fireGold.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Thick tail with multi-layered flame.
    final tail = Path()
      ..moveTo(0, s * 0.25)
      ..cubicTo(-s * 0.1, s * 0.55, -s * 0.18, s * 0.75, -s * 0.1, s * 0.9)
      ..lineTo(0, s * 0.82)
      ..lineTo(s * 0.1, s * 0.9)
      ..cubicTo(s * 0.18, s * 0.75, s * 0.1, s * 0.55, 0, s * 0.25)
      ..close();
    canvas.drawPath(tail, Paint()..color = deepOrange);
    // Tail belly stripe.
    final tailBelly = Path()
      ..moveTo(-s * 0.03, s * 0.3)
      ..cubicTo(-s * 0.04, s * 0.55, -s * 0.06, s * 0.75, -s * 0.03, s * 0.82)
      ..lineTo(s * 0.03, s * 0.82)
      ..cubicTo(s * 0.06, s * 0.75, s * 0.04, s * 0.55, s * 0.03, s * 0.3)
      ..close();
    canvas.drawPath(tailBelly, Paint()..color = paleYellow.withOpacity(0.4));
    // Tail flame.
    final flameCore = Path()
      ..moveTo(-s * 0.04, s * 0.88)
      ..lineTo(0, s * 1.05)
      ..lineTo(s * 0.04, s * 0.88)
      ..close();
    canvas.drawPath(flameCore, Paint()..color = const Color(0xFFFFEE88));
    canvas.drawCircle(
      const Offset(0, s * 0.95),
      s * 0.12,
      Paint()
        ..color = fireRed.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Massive bat-membrane wings with scalloped edges.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      final membrane = Path()..moveTo(sign * s * 0.3, -s * 0.08);
      membrane.lineTo(sign * s * 1.0, -s * 0.8);
      membrane.quadraticBezierTo(
        sign * s * 0.78,
        -s * 0.38,
        sign * s * 0.82,
        -s * 0.35,
      );
      membrane.lineTo(sign * s * 1.3, -s * 0.55);
      membrane.quadraticBezierTo(
        sign * s * 0.98,
        -s * 0.18,
        sign * s * 1.0,
        -s * 0.12,
      );
      membrane.lineTo(sign * s * 1.18, -s * 0.18);
      membrane.quadraticBezierTo(
        sign * s * 0.75,
        s * 0.08,
        sign * s * 0.15,
        s * 0.05,
      );
      membrane.close();
      canvas.drawPath(membrane, Paint()..color = tealWing.withOpacity(0.8));
      // Inner membrane lighter.
      final inner = Path()
        ..moveTo(sign * s * 0.35, -s * 0.05)
        ..lineTo(sign * s * 0.82, -s * 0.35)
        ..lineTo(sign * s * 1.0, -s * 0.12)
        ..quadraticBezierTo(sign * s * 0.6, s * 0.06, sign * s * 0.15, s * 0.03)
        ..close();
      canvas.drawPath(
        inner,
        Paint()..color = const Color(0xFF40C4B0).withOpacity(0.2),
      );

      // Finger bones.
      final bonePaint = Paint()
        ..color = darkTeal.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(sign * s * 0.3, -s * 0.08),
        Offset(sign * s * 0.7, -s * 0.4),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.7, -s * 0.4),
        Offset(sign * s * 1.0, -s * 0.8),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.7, -s * 0.4),
        Offset(sign * s * 1.3, -s * 0.55),
        bonePaint,
      );
      canvas.drawLine(
        Offset(sign * s * 0.7, -s * 0.4),
        Offset(sign * s * 1.18, -s * 0.18),
        bonePaint,
      );

      // Wing claw.
      final claw = Path()
        ..moveTo(sign * s * 0.68, -s * 0.4)
        ..lineTo(sign * s * 0.62, -s * 0.48)
        ..lineTo(sign * s * 0.72, -s * 0.42)
        ..close();
      canvas.drawPath(claw, Paint()..color = hornColor);
    }

    // Powerful body.
    _drawBody(canvas, s * 0.85, s * 0.52, deepOrange, paleYellow);
    // Scale chevrons.
    for (var i = 0; i < 5; i++) {
      final sy = -s * 0.1 + i * s * 0.05;
      canvas.drawLine(
        Offset(-s * 0.14, sy),
        Offset(0, sy + s * 0.02),
        Paint()
          ..color = const Color(0xFFDDB870).withOpacity(0.25)
          ..strokeWidth = 0.6,
      );
      canvas.drawLine(
        Offset(0, sy + s * 0.02),
        Offset(s * 0.14, sy),
        Paint()
          ..color = const Color(0xFFDDB870).withOpacity(0.25)
          ..strokeWidth = 0.6,
      );
    }

    // Head.
    final snout = Path()
      ..moveTo(-s * 0.14, -s * 0.33)
      ..cubicTo(-s * 0.08, -s * 0.52, s * 0.08, -s * 0.52, s * 0.14, -s * 0.33)
      ..quadraticBezierTo(0, -s * 0.3, -s * 0.14, -s * 0.33);
    canvas.drawPath(snout, Paint()..color = deepOrange);
    canvas.drawCircle(
      const Offset(0, -s * 0.36),
      s * 0.2,
      Paint()..color = deepOrange,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.32),
        width: s * 0.2,
        height: s * 0.08,
      ),
      Paint()..color = paleYellow.withOpacity(0.5),
    );

    // Prominent double horns.
    for (final sign in [-1.0, 1.0]) {
      final outerHorn = Path()
        ..moveTo(sign * s * 0.12, -s * 0.5)
        ..cubicTo(
          sign * s * 0.2,
          -s * 0.62,
          sign * s * 0.28,
          -s * 0.75,
          sign * s * 0.22,
          -s * 0.82,
        )
        ..lineTo(sign * s * 0.08, -s * 0.54)
        ..close();
      canvas.drawPath(outerHorn, Paint()..color = hornColor);
      final innerHorn = Path()
        ..moveTo(sign * s * 0.06, -s * 0.52)
        ..lineTo(sign * s * 0.1, -s * 0.66)
        ..lineTo(sign * s * 0.03, -s * 0.54)
        ..close();
      canvas.drawPath(innerHorn, Paint()..color = _lighten(hornColor, 0.1));
    }

    // Fierce glowing slit eyes.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(sign * s * 0.08, -s * 0.4),
        s * 0.045,
        Paint()
          ..color = const Color(0xFFFFAA00).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.4),
          width: s * 0.065,
          height: s * 0.05,
        ),
        Paint()..color = const Color(0xFFFFBB00),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.4),
          width: s * 0.015,
          height: s * 0.045,
        ),
        Paint()..color = const Color(0xFF111111),
      );
      canvas.drawCircle(
        Offset(sign * s * 0.065, -s * 0.41),
        s * 0.01,
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.6),
      );
    }

    // Brow ridges.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(sign * s * 0.14, -s * 0.43),
        Offset(sign * s * 0.04, -s * 0.41),
        Paint()
          ..color = _darken(deepOrange, 0.2)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Open mouth with fire glow.
    final mouth = Path()
      ..moveTo(-s * 0.07, -s * 0.48)
      ..quadraticBezierTo(0, -s * 0.52, s * 0.07, -s * 0.48)
      ..quadraticBezierTo(0, -s * 0.46, -s * 0.07, -s * 0.48);
    canvas.drawPath(mouth, Paint()..color = const Color(0xFFBB1100));
  }

  // ---------------------------------------------------------------------------
  // Shared helpers (static preview versions of CompanionRenderer helpers)
  // ---------------------------------------------------------------------------

  void _drawWing(
    Canvas canvas,
    double size,
    double flapOffset,
    Color color,
    bool isLeft,
    double spread,
    int featherCount, {
    Color? tipColor,
  }) {
    final sign = isLeft ? -1.0 : 1.0;
    final paint = Paint()..color = color;
    final wing = Path()
      ..moveTo(sign * size * 0.2, 0)
      ..cubicTo(
        sign * size * 0.5,
        flapOffset - size * 0.3,
        sign * size * 0.75,
        flapOffset - size * 0.55,
        sign * size * spread,
        flapOffset - size * 0.2,
      );

    final featherStep = size * 0.15;
    for (var i = 0; i < featherCount; i++) {
      final fx = sign * (size * spread - (i + 1) * featherStep * 0.6);
      final fy = flapOffset - size * 0.2 + (i + 1) * featherStep * 0.4;
      wing.lineTo(fx, fy);
      if (i < featherCount - 1) {
        wing.lineTo(
          sign *
              (size * spread -
                  (i + 1) * featherStep * 0.6 -
                  featherStep * 0.15),
          fy - featherStep * 0.1,
        );
      }
    }
    wing
      ..lineTo(sign * size * 0.1, size * 0.05)
      ..close();
    canvas.drawPath(wing, paint);

    if (tipColor != null) {
      final tip = Path()
        ..moveTo(sign * size * (spread - 0.15), flapOffset - size * 0.35)
        ..cubicTo(
          sign * size * (spread - 0.05),
          flapOffset - size * 0.3,
          sign * size * spread,
          flapOffset - size * 0.25,
          sign * size * spread,
          flapOffset - size * 0.2,
        )
        ..lineTo(sign * size * (spread - 0.12), flapOffset - size * 0.12)
        ..close();
      canvas.drawPath(tip, Paint()..color = tipColor);
    }
  }

  void _drawBody(
    Canvas canvas,
    double width,
    double height,
    Color baseColor,
    Color bellyColor,
  ) {
    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, height * 0.08),
        width: width * 0.95,
        height: height * 0.6,
      ),
      Paint()..color = _darken(baseColor, 0.3),
    );
    // Main body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()..color = baseColor,
    );
    // Belly.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, height * 0.06),
        width: width * 0.6,
        height: height * 0.45,
      ),
      Paint()..color = bellyColor,
    );
    // Top highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -height * 0.12),
        width: width * 0.35,
        height: height * 0.15,
      ),
      Paint()..color = _lighten(baseColor, 0.2).withOpacity(0.4),
    );
  }

  void _drawEyes(
    Canvas canvas,
    Offset leftCenter,
    Offset rightCenter,
    double radius, {
    Color irisColor = const Color(0xFF1A1A2E),
    bool fierce = false,
  }) {
    for (final center in [leftCenter, rightCenter]) {
      if (fierce) {
        final eye = Path()
          ..addOval(
            Rect.fromCenter(
              center: center,
              width: radius * 2.4,
              height: radius * 1.6,
            ),
          );
        canvas.drawPath(eye, Paint()..color = irisColor);
        canvas.drawCircle(
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.2),
          radius * 0.3,
          Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.7),
        );
      } else {
        canvas.drawCircle(
          center,
          radius * 1.2,
          Paint()..color = const Color(0xFFF8F4F0),
        );
        canvas.drawCircle(center, radius, Paint()..color = irisColor);
        canvas.drawCircle(
          Offset(center.dx - radius * 0.35, center.dy - radius * 0.35),
          radius * 0.35,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }
  }

  void _drawBeak(
    Canvas canvas,
    Offset tip,
    double size,
    Color color, {
    bool hooked = false,
  }) {
    final upperBeak = Path()..moveTo(tip.dx, tip.dy);
    if (hooked) {
      upperBeak
        ..quadraticBezierTo(
          tip.dx - size * 0.5,
          tip.dy + size * 0.3,
          tip.dx - size * 0.3,
          tip.dy + size * 0.7,
        )
        ..quadraticBezierTo(
          tip.dx,
          tip.dy + size * 0.5,
          tip.dx + size * 0.3,
          tip.dy + size * 0.7,
        )
        ..quadraticBezierTo(
          tip.dx + size * 0.5,
          tip.dy + size * 0.3,
          tip.dx,
          tip.dy,
        );
    } else {
      upperBeak
        ..lineTo(tip.dx - size * 0.35, tip.dy + size * 0.5)
        ..quadraticBezierTo(
          tip.dx,
          tip.dy + size * 0.65,
          tip.dx + size * 0.35,
          tip.dy + size * 0.5,
        )
        ..close();
    }
    canvas.drawPath(upperBeak, Paint()..color = color);
    final lower = Path()
      ..moveTo(tip.dx - size * 0.25, tip.dy + size * 0.45)
      ..quadraticBezierTo(
        tip.dx,
        tip.dy + size * 0.7,
        tip.dx + size * 0.25,
        tip.dy + size * 0.45,
      )
      ..close();
    canvas.drawPath(lower, Paint()..color = _darken(color, 0.2));
  }

  void _drawTailFeathers(
    Canvas canvas,
    double size,
    Color color,
    int count,
    double length,
    double splay,
  ) {
    for (var i = 0; i < count; i++) {
      final t = (i - (count - 1) / 2.0) / math.max(count - 1, 1);
      final feather = Path()
        ..moveTo(t * size * splay * 0.5, size * 0.2)
        ..quadraticBezierTo(
          t * size * splay * 1.5,
          size * (0.2 + length * 0.5),
          t * size * splay,
          size * (0.2 + length),
        )
        ..quadraticBezierTo(
          t * size * splay * 0.8,
          size * (0.2 + length * 0.4),
          t * size * splay * 0.3,
          size * 0.2,
        )
        ..close();
      final featherColor = i.isEven ? color : _darken(color, 0.1);
      canvas.drawPath(feather, Paint()..color = featherColor);
    }
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _CompanionPreviewPainter old) =>
      companionId != old.companionId;
}

// =============================================================================
// Plane Preview Painter  (CustomPaint using shared PlaneRenderer)
// =============================================================================
//
// Uses the same PlaneRenderer as in-game PlaneComponent so shop previews
// look identical to gameplay. Passes bankCos=1.0, bankSin=0.0 for level
// flight and applies the same perspectiveScaleY foreshortening.
// =============================================================================

class PlanePainter extends CustomPainter {
  PlanePainter({required this.planeId, this.colorScheme, this.wingSpan = 26.0});

  final String planeId;
  final Map<String, int>? colorScheme;
  final double wingSpan;

  /// Match PlaneComponent.perspectiveScaleY so shop looks like in-game.
  static const double _perspectiveScaleY = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);

    // Apply the same perspective foreshortening as in-game.
    canvas.scale(1.0, _perspectiveScaleY);

    // Scale to fit the preview box — in-game planes draw at ~±20px from
    // center, so a scale of ~1.2 fills a 100×100 preview nicely.
    final previewScale = size.shortestSide / 52;
    canvas.scale(previewScale);

    // Level flight: no banking.
    PlaneRenderer.renderPlane(
      canvas: canvas,
      bankCos: 1.0,
      bankSin: 0.0,
      wingSpan: wingSpan,
      planeId: planeId,
      colorScheme: colorScheme,
      propAngle: 0.0,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlanePainter oldDelegate) =>
      planeId != oldDelegate.planeId ||
      colorScheme != oldDelegate.colorScheme ||
      wingSpan != oldDelegate.wingSpan;
}
