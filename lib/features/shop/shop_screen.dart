import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../core/widgets/rating_tier_chip.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/economy_config.dart';
import '../../data/models/rating_tier.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/economy_config_service.dart';
import '../../data/services/matchmaking_service.dart';
import '../../data/services/shop_rotation.dart';
import '../../data/services/sortie_service.dart';
import '../../game/economy/fuel_tank.dart';
import '../../game/rendering/plane_renderer.dart';
import '../../data/models/avatar_config.dart';
import '../../game/rendering/companion_art.dart';

/// Shop screen for purchasing cosmetics and gold.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialTabIndex = 0});

  /// Which tab to show initially: 0 = Weekly, 1 = Planes, 2 = Contrails,
  /// 3 = Companions, 4 = Gold & Supplies.
  final int initialTabIndex;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EconomyConfig _economyConfig = EconomyConfig.defaults();

  /// The player's Standard Sortie rating — prestige cosmetics are gated by
  /// BOTH rating tier and coins. Null until fetched.
  RatingInfo? _sortieRating;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    // Pull latest server state so purchases made via RPC are reflected.
    ref.read(accountProvider.notifier).refreshFromServer();
    // Fetch economy config for dynamic pricing and promotions.
    EconomyConfigService.instance.getConfig().then((config) {
      if (mounted) setState(() => _economyConfig = config);
    });
    // Fetch the sortie rating for prestige tier gating.
    final player = ref.read(accountProvider).currentPlayer;
    if (player.id.isNotEmpty) {
      MatchmakingService.instance
          .fetchRating(
        userId: player.id,
        gameMode: SortieService.gameMode,
        fallbackLevel: player.level,
        fallbackBestScore: player.bestScore ?? 0,
      )
          .then((info) {
        if (mounted) setState(() => _sortieRating = info);
      });
    }
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
            Tab(text: 'Weekly'),
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
      body: MenuContentWrapper(
        child: Column(
          children: [
            // Promo banner when shop discount is active.
            if (hasAnyPromo) _PromoBanner(config: _economyConfig),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _WeeklyShopTab(
                    ownedIds: ownedIds,
                    coins: coins,
                    sortieRating: _sortieRating,
                    onPurchase: _purchaseWeeklyOffer,
                  ),
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
                  _GoldShopTab(
                    economyConfig: _economyConfig,
                    refuelCanisters: account.refuelCanisters,
                    onBuyCanisters: _buyCanisters,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the player's Standard Sortie tier satisfies a prestige item's
  /// requirement. Tier-gated items need a REAL (non-provisional) rating —
  /// money must never buy the flex.
  bool _meetsTierRequirement(String cosmeticId) {
    final required = ShopRotation.prestigeTierRequirements[cosmeticId];
    if (required == null) return true;
    final rating = _sortieRating;
    if (rating == null || rating.provisional) return false;
    return RatingTier.fromRating(rating.rating).index >= required.index;
  }

  void _showTierLockedSnack(String cosmeticId) {
    final required = ShopRotation.prestigeTierRequirements[cosmeticId];
    if (required == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Requires ${required.displayName} rating in Standard Sortie',
        ),
        backgroundColor: FlitColors.backgroundMid,
      ),
    );
  }

  void _purchaseItem(Cosmetic item) {
    if (!_meetsTierRequirement(item.id)) {
      _showTierLockedSnack(item.id);
      return;
    }
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

  void _purchaseWeeklyOffer(ShopOffer offer) {
    if (!_meetsTierRequirement(offer.cosmetic.id)) {
      _showTierLockedSnack(offer.cosmetic.id);
      return;
    }
    final success = ref
        .read(accountProvider.notifier)
        .purchaseCosmetic(offer.cosmetic.id, offer.price);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${offer.cosmetic.name}!'),
          backgroundColor: FlitColors.success,
        ),
      );
      setState(() {});
    }
  }

  void _buyCanisters(int count) {
    final ok = ref.read(accountProvider.notifier).buyRefuelCanisters(count);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bought $count refuel canister${count == 1 ? '' : 's'}!'
              : 'Not enough coins',
        ),
        backgroundColor: ok ? FlitColors.success : FlitColors.error,
      ),
    );
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
  const _GoldShopTab({
    required this.economyConfig,
    required this.refuelCanisters,
    required this.onBuyCanisters,
  });

  final EconomyConfig economyConfig;

  /// Refuel canisters the player currently owns.
  final int refuelCanisters;

  /// Called with the number of canisters to buy.
  final void Function(int count) onBuyCanisters;

  @override
  Widget build(BuildContext context) {
    final configPkgs = economyConfig.effectiveGoldPackages;
    // Layout: supplies header, canister card, gold header, packages.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SuppliesSection(
          refuelCanisters: refuelCanisters,
          onBuyCanisters: onBuyCanisters,
        ),
        const SizedBox(height: 20),
        const Padding(
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
        ),
        for (final pkg in configPkgs) _GoldPackageCard(package: pkg),
      ],
    );
  }
}

// =============================================================================
// Supplies (refuel canisters) — coin sink for the free-flight fuel tank
// =============================================================================

class _SuppliesSection extends StatelessWidget {
  const _SuppliesSection({
    required this.refuelCanisters,
    required this.onBuyCanisters,
  });

  final int refuelCanisters;
  final void Function(int count) onBuyCanisters;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(
                Icons.local_gas_station,
                color: FlitColors.accent,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'REFUEL CANISTERS',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FlitColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Owned: $refuelCanisters',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'One canister = one instant full tank for free-flight earning. '
            'Cheaper than refuelling on the spot.',
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CanisterBuyButton(
                  label: 'BUY 1',
                  cost: FuelTank.canisterCoinCost,
                  onTap: () => onBuyCanisters(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CanisterBuyButton(
                  label: 'BUY 5',
                  cost: FuelTank.canisterCoinCost * 5,
                  onTap: () => onBuyCanisters(5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CanisterBuyButton extends StatelessWidget {
  const _CanisterBuyButton({
    required this.label,
    required this.cost,
    required this.onTap,
  });

  final String label;
  final int cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: FlitColors.accent,
        foregroundColor: FlitColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.monetization_on, size: 14, color: FlitColors.gold),
          const SizedBox(width: 2),
          Text(
            '$cost',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Weekly rotating shop — deterministic ISO-week rotation (ShopRotation)
// =============================================================================

class _WeeklyShopTab extends StatelessWidget {
  const _WeeklyShopTab({
    required this.ownedIds,
    required this.coins,
    required this.sortieRating,
    required this.onPurchase,
  });

  final Set<String> ownedIds;
  final int coins;
  final RatingInfo? sortieRating;
  final void Function(ShopOffer offer) onPurchase;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final offers = ShopRotation.weeklyOffers(now);
    final end = ShopRotation.rotationEnd(now);
    final remaining = end.difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Rotation countdown header.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FlitColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront, color: FlitColors.gold, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "THIS WEEK'S HANGAR",
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Same lineup for every pilot. New stock every Monday.',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FlitColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  days > 0 ? '${days}d ${hours}h' : '${remaining.inHours}h',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WeeklyOfferCard(
              offer: offer,
              owned: ownedIds.contains(offer.cosmetic.id),
              coins: coins,
              sortieRating: sortieRating,
              onPurchase: () => onPurchase(offer),
            ),
          ),
      ],
    );
  }
}

class _WeeklyOfferCard extends StatelessWidget {
  const _WeeklyOfferCard({
    required this.offer,
    required this.owned,
    required this.coins,
    required this.sortieRating,
    required this.onPurchase,
  });

  final ShopOffer offer;
  final bool owned;
  final int coins;
  final RatingInfo? sortieRating;
  final VoidCallback onPurchase;

  bool get _tierMet {
    final required = offer.requiredTier;
    if (required == null) return true;
    final rating = sortieRating;
    if (rating == null || rating.provisional) return false;
    return RatingTier.fromRating(rating.rating).index >= required.index;
  }

  @override
  Widget build(BuildContext context) {
    final item = offer.cosmetic;
    final rarity = _rarityColor(item.rarity);
    final affordable = coins >= offer.price;
    final buyable = !owned && affordable && _tierMet;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: offer.discountPct > 0
              ? _SaleColors.border
              : rarity.withValues(alpha: 0.5),
          width: offer.discountPct > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rarity swatch.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rarity.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              switch (item.type) {
                CosmeticType.plane => Icons.flight,
                CosmeticType.contrail => Icons.gesture,
                CosmeticType.coPilot => Icons.pets,
                _ => Icons.card_giftcard,
              },
              color: rarity,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _rarityLabel(item.rarity),
                      style: TextStyle(
                        color: rarity,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (offer.discountPct > 0) ...[
                      Text(
                        '${item.price}',
                        style: const TextStyle(
                          color: _SaleColors.strikethroughText,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: _SaleColors.strikethroughLine,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Icon(
                      Icons.monetization_on,
                      color: FlitColors.gold,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${offer.price}',
                      style: TextStyle(
                        color: offer.discountPct > 0
                            ? FlitColors.success
                            : FlitColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (offer.discountPct > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '-${offer.discountPct}%',
                        style: const TextStyle(
                          color: FlitColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                if (offer.requiredTier != null) ...[
                  const SizedBox(height: 5),
                  RatingTierChip(
                    rating: offer.requiredTier!.minRating,
                    showRating: false,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (owned)
            const Text(
              'OWNED',
              style: TextStyle(
                color: FlitColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            )
          else
            ElevatedButton(
              onPressed: buyable ? onPurchase : (_tierMet ? null : onPurchase),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    buyable ? FlitColors.accent : FlitColors.backgroundLight,
                foregroundColor: FlitColors.textPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                !_tierMet
                    ? 'LOCKED'
                    : affordable
                        ? 'BUY'
                        : 'TOO PRICY',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
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
            // Companion perks in purchase dialog
            if (item.type == CosmeticType.coPilot &&
                item.id != 'companion_none') ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Perks',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.local_gas_station,
                      size: 14, color: FlitColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Auto fuel fetch when tank drops below 20%',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.flight, size: 14, color: FlitColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Flies alongside your plane',
                      style: TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                  // Companion perks (only for non-none companions)
                  if (item.type == CosmeticType.coPilot &&
                      item.id != 'companion_none')
                    const _CompanionPerks(),
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
// Companion Perks  (compact perk list for companion cards)
// =============================================================================

class _CompanionPerks extends StatelessWidget {
  const _CompanionPerks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PerkRow(
            icon: Icons.local_gas_station,
            label: 'Auto fuel fetch',
            color: FlitColors.warning,
          ),
          _PerkRow(
            icon: Icons.flight,
            label: 'Flies with you',
            color: FlitColors.accent,
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
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

class _CompanionPreview extends StatefulWidget {
  const _CompanionPreview({required this.companionId});

  final String companionId;

  @override
  State<_CompanionPreview> createState() => _CompanionPreviewState();
}

class _CompanionPreviewState extends State<_CompanionPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.companionId == 'companion_none') {
      return const Icon(Icons.block, size: 48, color: FlitColors.textMuted);
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _CompanionPreviewPainter(
          companionId: widget.companionId,
          flapPhase: _anim.value * 2 * math.pi * 2,
          breathPhase: _anim.value * 2 * math.pi * 1.4,
        ),
      ),
    );
  }
}

/// Thin wrapper around the shared [CompanionArt] painter — the exact same
/// code path the in-game CompanionRenderer uses, so shop previews are
/// always faithful to gameplay (single source of truth per CLAUDE.md).
class _CompanionPreviewPainter extends CustomPainter {
  _CompanionPreviewPainter({
    required this.companionId,
    this.flapPhase = 0.0,
    this.breathPhase = 0.0,
  });

  final String companionId;
  final double flapPhase;
  final double breathPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final companion = AvatarCompanion.values.firstWhere(
      (c) => 'companion_${c.name}' == companionId,
      orElse: () => AvatarCompanion.none,
    );
    if (companion == AvatarCompanion.none) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.shortestSide / CompanionArt.footprintOf(companion);
    canvas.scale(scale);
    CompanionArt.paint(
      canvas,
      companion,
      flapPhase: flapPhase,
      breathPhase: breathPhase,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompanionPreviewPainter old) =>
      companionId != old.companionId ||
      flapPhase != old.flapPhase ||
      breathPhase != old.breathPhase;
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
