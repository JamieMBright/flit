import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';

/// Shop screen for purchasing cosmetics and gold.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Track owned and equipped items
  final Set<String> _ownedIds = {'plane_default', 'contrail_default'};
  String _equippedPlane = 'plane_default';
  String _equippedContrail = 'contrail_default';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(currentCoinsProvider);
    final level = ref.watch(currentLevelProvider);
    return Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Shop'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: FlitColors.accent,
            labelColor: FlitColors.textPrimary,
            unselectedLabelColor: FlitColors.textMuted,
            tabs: const [
              Tab(text: 'Planes'),
              Tab(text: 'Contrails'),
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
        body: TabBarView(
          controller: _tabController,
          children: [
            _CosmeticGrid(
              items: CosmeticCatalog.planes,
              ownedIds: _ownedIds,
              equippedId: _equippedPlane,
              coins: coins,
              level: level,
              onPurchase: _purchaseItem,
              onEquip: _equipPlane,
            ),
            _CosmeticGrid(
              items: CosmeticCatalog.contrails,
              ownedIds: _ownedIds,
              equippedId: _equippedContrail,
              coins: coins,
              level: level,
              onPurchase: _purchaseItem,
              onEquip: _equipContrail,
            ),
            const _GoldShopTab(),
          ],
        ),
      );
  }

  void _purchaseItem(Cosmetic item) {
    if (ref.read(currentCoinsProvider) >= item.price) {
      ref.read(accountProvider.notifier).spendCoins(item.price);
      setState(() {
        _ownedIds.add(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchased ${item.name}!'),
          backgroundColor: FlitColors.success,
        ),
      );
    }
  }

  void _equipPlane(String id) {
    setState(() {
      _equippedPlane = id;
    });
  }

  void _equipContrail(String id) {
    setState(() {
      _equippedContrail = id;
    });
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
// Gold Shop Tab  (IAP placeholder)
// =============================================================================

class _GoldPackage {
  const _GoldPackage({
    required this.coins,
    required this.price,
    this.isBestValue = false,
  });

  final int coins;
  final double price;
  final bool isBestValue;
}

const List<_GoldPackage> _goldPackages = [
  _GoldPackage(coins: 500, price: 0.99),
  _GoldPackage(coins: 2000, price: 3.99),
  _GoldPackage(coins: 5000, price: 8.99),
  _GoldPackage(coins: 15000, price: 19.99, isBestValue: true),
];

class _GoldShopTab extends StatelessWidget {
  const _GoldShopTab();

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _goldPackages.length + 1, // +1 for header
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

          final pkg = _goldPackages[index - 1];
          return _GoldPackageCard(package: pkg);
        },
      );
}

class _GoldPackageCard extends StatelessWidget {
  const _GoldPackageCard({required this.package});

  final _GoldPackage package;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: package.isBestValue
                      ? FlitColors.warning
                      : FlitColors.cardBorder,
                  width: package.isBestValue ? 2 : 1,
                ),
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
                        Text(
                          '\$${package.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(package.coins / package.price).toStringAsFixed(0)} coins/\$',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  });

  final List<Cosmetic> items;
  final Set<String> ownedIds;
  final String equippedId;
  final int coins;
  final int level;
  final void Function(Cosmetic) onPurchase;
  final void Function(String) onEquip;

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
          final canAfford = coins >= item.price;
          final meetsLevel =
              item.requiredLevel == null || level >= item.requiredLevel!;

          return _CosmeticCard(
            item: item,
            isOwned: isOwned,
            isEquipped: isEquipped,
            canAfford: canAfford,
            meetsLevel: meetsLevel,
            onTap: () {
              if (isOwned) {
                onEquip(item.id);
              } else if (canAfford && meetsLevel) {
                _showPurchaseDialog(context, item);
              }
            },
          );
        },
      );

  void _showPurchaseDialog(BuildContext context, Cosmetic item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
                const Icon(Icons.monetization_on, color: FlitColors.warning),
                const SizedBox(width: 8),
                Text(
                  '${item.price} coins',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            // Real money alternative for premium items
            if (item.isPremium && item.realMoneyPrice != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money, color: FlitColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'or \$${item.realMoneyPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPurchase(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
            ),
            child: const Text('Buy'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
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

  void _showGiftDialog(BuildContext context, Cosmetic item) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: Text('Gift ${item.name}', style: const TextStyle(color: FlitColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send this item to a friend!', style: TextStyle(color: FlitColors.textSecondary)),
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
            child: const Text('Cancel', style: TextStyle(color: FlitColors.textMuted)),
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
  });

  final Cosmetic item;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final bool meetsLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLocked = !meetsLevel;
    final rarityCol = _rarityColor(item.rarity);

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped
                ? FlitColors.success
                : isLocked
                    ? FlitColors.textMuted
                    : FlitColors.cardBorder,
            width: isEquipped ? 2 : 1,
          ),
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
                                painter: _PlanePainter(planeId: item.id,
                                    colorScheme: item.colorScheme),
                              )
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
                      color:
                          isLocked ? FlitColors.textMuted : FlitColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                    _PriceRow(item: item, canAfford: canAfford),
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Price Row  (coin price + optional real-money price)
// =============================================================================

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.canAfford});

  final Cosmetic item;
  final bool canAfford;

  @override
  Widget build(BuildContext context) => Column(
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
              Text(
                item.price.toString(),
                style: TextStyle(
                  color: canAfford ? FlitColors.warning : FlitColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (item.isPremium && item.realMoneyPrice != null) ...[
            const SizedBox(height: 2),
            Text(
              'or \$${item.realMoneyPrice!.toStringAsFixed(2)}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ],
      );
}

// =============================================================================
// Contrail Preview  (simple colored gradient bar)
// =============================================================================

class _ContrailPreview extends StatelessWidget {
  const _ContrailPreview({
    required this.colorScheme,
    required this.isLocked,
  });

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
      final color =
          Color.lerp(primary, secondary, t)!.withOpacity(1.0 - t * 0.7);
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
  bool shouldRepaint(covariant _ContrailPainter old) =>
      primary != old.primary || secondary != old.secondary;
}

// =============================================================================
// Plane Preview Painter  (CustomPaint for distinct plane silhouettes)
// =============================================================================

class _PlanePainter extends CustomPainter {
  _PlanePainter({required this.planeId, this.colorScheme});

  final String planeId;
  final Map<String, int>? colorScheme;

  Color get _primary =>
      Color(colorScheme?['primary'] ?? 0xFFF0E8DC);
  Color get _secondary =>
      Color(colorScheme?['secondary'] ?? 0xFFD4654A);
  Color get _detail =>
      Color(colorScheme?['detail'] ?? 0xFF8B4513);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (planeId) {
      case 'plane_default':
        _drawBiPlane(canvas, cx, cy);
      case 'plane_prop':
        _drawPropPlane(canvas, cx, cy);
      case 'plane_paper':
        _drawPaperPlane(canvas, cx, cy);
      case 'plane_jet':
        _drawJet(canvas, cx, cy);
      case 'plane_rocket':
        _drawRocket(canvas, cx, cy);
      case 'plane_stealth':
        _drawStealth(canvas, cx, cy);
      case 'plane_golden_jet':
        _drawGoldenJet(canvas, cx, cy);
      case 'plane_diamond_concorde':
        _drawConcorde(canvas, cx, cy);
      case 'plane_platinum_eagle':
        _drawEagle(canvas, cx, cy);
      default:
        _drawBiPlane(canvas, cx, cy);
    }
  }

  // --- Classic Bi-Plane: two stacked wings, struts, round nose ---
  void _drawBiPlane(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final wing = Paint()..color = _secondary;
    final strut = Paint()
      ..color = _detail
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Fuselage
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 40, height: 10),
        const Radius.circular(5),
      ),
      body,
    );
    // Upper wing
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy - 12), width: 56, height: 7),
        const Radius.circular(3),
      ),
      wing,
    );
    // Lower wing
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 12), width: 56, height: 7),
        const Radius.circular(3),
      ),
      wing,
    );
    // Struts
    canvas.drawLine(
        Offset(cx - 14, cy - 8), Offset(cx - 14, cy + 8), strut);
    canvas.drawLine(
        Offset(cx + 14, cy - 8), Offset(cx + 14, cy + 8), strut);
    // Propeller
    canvas.drawCircle(Offset(cx + 22, cy), 3, Paint()..color = _detail);
  }

  // --- Prop Plane: single low wing, big propeller disc ---
  void _drawPropPlane(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final wing = Paint()..color = _secondary;
    final detail = Paint()..color = _detail;

    // Fuselage
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 44, height: 11),
        const Radius.circular(5),
      ),
      body,
    );
    // Wing (single, lower)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 2, cy + 2), width: 60, height: 8),
        const Radius.circular(3),
      ),
      wing,
    );
    // Tail fin
    final tail = Path()
      ..moveTo(cx - 22, cy)
      ..lineTo(cx - 28, cy - 12)
      ..lineTo(cx - 18, cy)
      ..close();
    canvas.drawPath(tail, detail);
    // Propeller disc
    canvas.drawCircle(Offset(cx + 24, cy), 8, detail..color = _detail.withOpacity(0.5));
    canvas.drawLine(
      Offset(cx + 24, cy - 8),
      Offset(cx + 24, cy + 8),
      Paint()
        ..color = _detail
        ..strokeWidth = 2,
    );
  }

  // --- Paper Plane: minimal, angular, folded paper look ---
  void _drawPaperPlane(Canvas canvas, double cx, double cy) {
    final fill = Paint()..color = _primary;
    final fold = Paint()
      ..color = _detail
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final shape = Path()
      ..moveTo(cx + 28, cy)         // nose
      ..lineTo(cx - 20, cy - 18)    // top-left wing
      ..lineTo(cx - 10, cy)         // center notch
      ..lineTo(cx - 20, cy + 18)    // bottom-left wing
      ..close();
    canvas.drawPath(shape, fill);

    // Fold line
    canvas.drawLine(
        Offset(cx + 28, cy), Offset(cx - 10, cy), fold);
    // Shadow fold
    final shadow = Path()
      ..moveTo(cx + 28, cy)
      ..lineTo(cx - 20, cy + 18)
      ..lineTo(cx - 10, cy)
      ..close();
    canvas.drawPath(
        shadow, Paint()..color = _secondary.withOpacity(0.5));
  }

  // --- Sleek Jet: delta wings, sharp nose ---
  void _drawJet(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final accent = Paint()..color = _secondary;
    final edge = Paint()..color = _detail;

    // Fuselage (narrow, long)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 9),
        const Radius.circular(4),
      ),
      body,
    );
    // Delta wings
    final wing = Path()
      ..moveTo(cx + 6, cy)
      ..lineTo(cx - 14, cy - 22)
      ..lineTo(cx - 18, cy)
      ..close();
    canvas.drawPath(wing, accent);
    final wing2 = Path()
      ..moveTo(cx + 6, cy)
      ..lineTo(cx - 14, cy + 22)
      ..lineTo(cx - 18, cy)
      ..close();
    canvas.drawPath(wing2, accent);
    // Nose cone
    final nose = Path()
      ..moveTo(cx + 26, cy)
      ..lineTo(cx + 18, cy - 4)
      ..lineTo(cx + 18, cy + 4)
      ..close();
    canvas.drawPath(nose, edge);
    // Canopy
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 8, cy), width: 6, height: 4),
      Paint()..color = const Color(0xFF87CEEB),
    );
  }

  // --- Rocket Ship: tall, cylindrical, fins, flame ---
  void _drawRocket(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final trim = Paint()..color = _secondary;
    final flame = Paint()..color = _detail;

    // Body (drawn horizontal: nose right, tail left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 36, height: 14),
        const Radius.circular(7),
      ),
      body,
    );
    // Nose cone
    final nose = Path()
      ..moveTo(cx + 26, cy)
      ..lineTo(cx + 16, cy - 7)
      ..lineTo(cx + 16, cy + 7)
      ..close();
    canvas.drawPath(nose, trim);
    // Window
    canvas.drawCircle(
        Offset(cx + 6, cy), 3, Paint()..color = const Color(0xFF87CEEB));
    // Fins
    final finTop = Path()
      ..moveTo(cx - 14, cy - 7)
      ..lineTo(cx - 22, cy - 18)
      ..lineTo(cx - 8, cy - 7)
      ..close();
    canvas.drawPath(finTop, body);
    final finBot = Path()
      ..moveTo(cx - 14, cy + 7)
      ..lineTo(cx - 22, cy + 18)
      ..lineTo(cx - 8, cy + 7)
      ..close();
    canvas.drawPath(finBot, body);
    // Flame
    final flamePath = Path()
      ..moveTo(cx - 18, cy - 5)
      ..lineTo(cx - 30, cy)
      ..lineTo(cx - 18, cy + 5)
      ..close();
    canvas.drawPath(flamePath, flame);
    // Trim stripe
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx - 4, cy), width: 3, height: 14),
      trim,
    );
  }

  // --- Stealth Bomber: flying wing, flat, angular ---
  void _drawStealth(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final dark = Paint()..color = _secondary;

    // Main body (wide chevron)
    final shape = Path()
      ..moveTo(cx + 20, cy)          // nose
      ..lineTo(cx - 6, cy - 28)      // left wing tip
      ..lineTo(cx - 14, cy - 12)     // left notch
      ..lineTo(cx - 18, cy)          // tail center
      ..lineTo(cx - 14, cy + 12)     // right notch
      ..lineTo(cx - 6, cy + 28)      // right wing tip
      ..close();
    canvas.drawPath(shape, body);

    // Edge highlights
    canvas.drawLine(
      Offset(cx + 20, cy),
      Offset(cx - 6, cy - 28),
      Paint()
        ..color = _detail
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(cx + 20, cy),
      Offset(cx - 6, cy + 28),
      Paint()
        ..color = _detail
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Center ridge
    canvas.drawLine(
      Offset(cx + 20, cy),
      Offset(cx - 18, cy),
      Paint()
        ..color = _detail
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Cockpit slit
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 6, cy), width: 8, height: 3),
        const Radius.circular(1.5),
      ),
      dark,
    );
  }

  // --- Golden Private Jet: business jet silhouette, luxurious ---
  void _drawGoldenJet(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final trim = Paint()..color = _secondary;
    final highlight = Paint()..color = _detail;

    // Fuselage (sleek, rounded)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 11),
        const Radius.circular(5),
      ),
      body,
    );
    // Swept wings
    final wTop = Path()
      ..moveTo(cx + 2, cy - 5)
      ..lineTo(cx - 10, cy - 22)
      ..lineTo(cx - 16, cy - 5)
      ..close();
    canvas.drawPath(wTop, body);
    final wBot = Path()
      ..moveTo(cx + 2, cy + 5)
      ..lineTo(cx - 10, cy + 22)
      ..lineTo(cx - 16, cy + 5)
      ..close();
    canvas.drawPath(wBot, body);
    // Tail
    final tail = Path()
      ..moveTo(cx - 22, cy)
      ..lineTo(cx - 28, cy - 14)
      ..lineTo(cx - 20, cy)
      ..close();
    canvas.drawPath(tail, trim);
    // Windows (gold highlight dots)
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(cx + 8 - i * 6.0, cy - 1),
        1.5,
        highlight,
      );
    }
    // Nose shine
    canvas.drawCircle(Offset(cx + 24, cy), 2, highlight);
    // Engine pods
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 18, cy - 8), width: 8, height: 4),
      trim,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 18, cy + 8), width: 8, height: 4),
      trim,
    );
  }

  // --- Diamond Concorde: elongated, drooped nose, delta wings ---
  void _drawConcorde(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final trim = Paint()..color = _secondary;
    final sparkle = Paint()..color = _detail;

    // Long narrow fuselage
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 8),
        const Radius.circular(4),
      ),
      body,
    );
    // Drooped nose extension
    final nose = Path()
      ..moveTo(cx + 32, cy + 1)
      ..lineTo(cx + 24, cy - 3)
      ..lineTo(cx + 24, cy + 4)
      ..close();
    canvas.drawPath(nose, trim);
    // Delta wings (wide, low)
    final wingL = Path()
      ..moveTo(cx + 4, cy - 4)
      ..lineTo(cx - 16, cy - 24)
      ..lineTo(cx - 20, cy - 4)
      ..close();
    canvas.drawPath(wingL, body);
    final wingR = Path()
      ..moveTo(cx + 4, cy + 4)
      ..lineTo(cx - 16, cy + 24)
      ..lineTo(cx - 20, cy + 4)
      ..close();
    canvas.drawPath(wingR, body);
    // Sparkle dots (diamond effect)
    final sparklePositions = [
      Offset(cx + 10, cy - 2),
      Offset(cx - 2, cy - 10),
      Offset(cx - 8, cy + 8),
      Offset(cx + 16, cy + 1),
      Offset(cx - 12, cy - 14),
    ];
    for (final pos in sparklePositions) {
      canvas.drawCircle(pos, 1.5, sparkle);
    }
    // Tail
    final tail = Path()
      ..moveTo(cx - 26, cy)
      ..lineTo(cx - 30, cy - 10)
      ..lineTo(cx - 24, cy)
      ..close();
    canvas.drawPath(tail, trim);
  }

  // --- Platinum Eagle: swept-back wings like a bird of prey ---
  void _drawEagle(Canvas canvas, double cx, double cy) {
    final body = Paint()..color = _primary;
    final accent = Paint()..color = _secondary;
    final shimmer = Paint()..color = _detail;

    // Body (tapered, raptor-like)
    final fuselage = Path()
      ..moveTo(cx + 24, cy)           // beak tip
      ..lineTo(cx + 10, cy - 5)
      ..lineTo(cx - 20, cy - 3)
      ..lineTo(cx - 24, cy)           // tail
      ..lineTo(cx - 20, cy + 3)
      ..lineTo(cx + 10, cy + 5)
      ..close();
    canvas.drawPath(fuselage, body);

    // Swept wings (eagle spread)
    final wingTop = Path()
      ..moveTo(cx + 4, cy - 5)
      ..quadraticBezierTo(cx - 10, cy - 32, cx - 22, cy - 26)
      ..lineTo(cx - 14, cy - 3)
      ..close();
    canvas.drawPath(wingTop, accent);
    final wingBot = Path()
      ..moveTo(cx + 4, cy + 5)
      ..quadraticBezierTo(cx - 10, cy + 32, cx - 22, cy + 26)
      ..lineTo(cx - 14, cy + 3)
      ..close();
    canvas.drawPath(wingBot, accent);

    // Tail feathers
    final tailF = Path()
      ..moveTo(cx - 24, cy)
      ..lineTo(cx - 32, cy - 8)
      ..lineTo(cx - 28, cy)
      ..lineTo(cx - 32, cy + 8)
      ..close();
    canvas.drawPath(tailF, accent);

    // Eye
    canvas.drawCircle(Offset(cx + 16, cy - 1), 2, Paint()..color = _secondary);
    canvas.drawCircle(Offset(cx + 16, cy - 1), 1, Paint()..color = FlitColors.textPrimary);

    // Shimmer highlights
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(cx - 4 + i * 8.0, cy - 14 + i * 6.0),
        1.2,
        shimmer,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlanePainter old) =>
      planeId != old.planeId || colorScheme != old.colorScheme;
}
