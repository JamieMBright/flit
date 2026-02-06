import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';

/// Shop screen for purchasing cosmetics.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Placeholder coin balance
  int _coins = 1250;
  int _level = 5;

  // Track owned and equipped items
  final Set<String> _ownedIds = {'plane_default', 'contrail_default'};
  String _equippedPlane = 'plane_default';
  String _equippedContrail = 'contrail_default';

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
  Widget build(BuildContext context) => Scaffold(
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
            ],
          ),
          actions: [
            // Coin balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: FlitColors.warning.withValues(alpha: 0.2),
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
                    _coins.toString(),
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
              coins: _coins,
              level: _level,
              onPurchase: _purchaseItem,
              onEquip: _equipPlane,
            ),
            _CosmeticGrid(
              items: CosmeticCatalog.contrails,
              ownedIds: _ownedIds,
              equippedId: _equippedContrail,
              coins: _coins,
              level: _level,
              onPurchase: _purchaseItem,
              onEquip: _equipContrail,
            ),
          ],
        ),
      );

  void _purchaseItem(Cosmetic item) {
    if (_coins >= item.price) {
      setState(() {
        _coins -= item.price;
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
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isOwned = ownedIds.contains(item.id);
          final isEquipped = equippedId == item.id;
          final canAfford = coins >= item.price;
          final meetsLevel = item.requiredLevel == null ||
              level >= item.requiredLevel!;

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
        content: Row(
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
        ],
      ),
    );
  }
}

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
                  // Preview placeholder
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlitColors.backgroundMid,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          item.type == CosmeticType.plane
                              ? Icons.flight
                              : Icons.blur_on,
                          size: 48,
                          color: isLocked
                              ? FlitColors.textMuted
                              : FlitColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isLocked
                          ? FlitColors.textMuted
                          : FlitColors.textPrimary,
                      fontSize: 14,
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
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 14,
                          color: canAfford
                              ? FlitColors.warning
                              : FlitColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.price.toString(),
                          style: TextStyle(
                            color: canAfford
                                ? FlitColors.warning
                                : FlitColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Lock overlay
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundDark.withValues(alpha: 0.7),
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
                    '✓',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 12,
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
