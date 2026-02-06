import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import '../../data/providers/account_provider.dart';
import '../shop/shop_screen.dart';
import 'avatar_widget.dart';

// =============================================================================
// Avatar part definition
// =============================================================================

/// A single selectable avatar part option within a category.
class _AvatarPart {
  const _AvatarPart({
    required this.id,
    required this.name,
    required this.icon,
    this.price = 0,
    this.requiredLevel = 0,
    this.goldPrice = 0,
  });

  final String id;
  final String name;
  final IconData icon;
  final int price;

  /// Minimum player level to unlock this part via XP progression.
  /// 0 means no level requirement.
  final int requiredLevel;

  /// Gold cost to bypass the [requiredLevel] requirement.
  /// 0 means no gold alternative (or no level gate).
  final int goldPrice;

  bool get isFree => price == 0 && requiredLevel == 0;

  /// Whether this part has a level gate (XP-based unlock).
  bool get hasLevelGate => requiredLevel > 0;
}

// =============================================================================
// Category definitions with available parts
// =============================================================================

/// Category metadata and its available parts.
class _AvatarCategory {
  const _AvatarCategory({
    required this.label,
    required this.icon,
    required this.configKey,
    required this.parts,
  });

  final String label;
  final IconData icon;
  final String configKey;
  final List<_AvatarPart> parts;
}

const List<_AvatarCategory> _categories = [
  // -- Face --
  _AvatarCategory(
    label: 'Face',
    icon: Icons.face,
    configKey: 'face',
    parts: [
      _AvatarPart(id: 'face_round', name: 'Round', icon: Icons.circle_outlined),
      _AvatarPart(id: 'face_square', name: 'Square', icon: Icons.square_outlined),
      _AvatarPart(id: 'face_oval', name: 'Oval', icon: Icons.egg_outlined),
      _AvatarPart(
        id: 'face_diamond',
        name: 'Diamond',
        icon: Icons.diamond_outlined,
        price: 200,
      ),
      _AvatarPart(
        id: 'face_heart',
        name: 'Heart',
        icon: Icons.favorite_outline,
        price: 350,
      ),
    ],
  ),

  // -- Skin --
  _AvatarCategory(
    label: 'Skin',
    icon: Icons.palette,
    configKey: 'skin',
    parts: [
      _AvatarPart(id: 'skin_light', name: 'Light', icon: Icons.light_mode),
      _AvatarPart(id: 'skin_fair', name: 'Fair', icon: Icons.wb_sunny_outlined),
      _AvatarPart(id: 'skin_medium', name: 'Medium', icon: Icons.contrast),
      _AvatarPart(id: 'skin_tan', name: 'Tan', icon: Icons.wb_twilight),
      _AvatarPart(id: 'skin_brown', name: 'Brown', icon: Icons.dark_mode_outlined),
      _AvatarPart(id: 'skin_dark', name: 'Dark', icon: Icons.nights_stay_outlined),
    ],
  ),

  // -- Eyes --
  _AvatarCategory(
    label: 'Eyes',
    icon: Icons.visibility,
    configKey: 'eyes',
    parts: [
      _AvatarPart(id: 'eyes_round', name: 'Round', icon: Icons.remove_red_eye_outlined),
      _AvatarPart(id: 'eyes_almond', name: 'Almond', icon: Icons.visibility_outlined),
      _AvatarPart(id: 'eyes_wide', name: 'Wide', icon: Icons.sentiment_satisfied),
      _AvatarPart(id: 'eyes_narrow', name: 'Narrow', icon: Icons.bedtime_outlined),
      _AvatarPart(
        id: 'eyes_wink',
        name: 'Wink',
        icon: Icons.mood,
        price: 150,
      ),
    ],
  ),

  // -- Hair --
  _AvatarCategory(
    label: 'Hair',
    icon: Icons.content_cut,
    configKey: 'hair',
    parts: [
      _AvatarPart(id: 'hair_none', name: 'None', icon: Icons.block),
      _AvatarPart(id: 'hair_short', name: 'Short', icon: Icons.person),
      _AvatarPart(id: 'hair_medium', name: 'Medium', icon: Icons.person_outline),
      _AvatarPart(id: 'hair_long', name: 'Long', icon: Icons.face_retouching_natural),
      _AvatarPart(
        id: 'hair_mohawk',
        name: 'Mohawk',
        icon: Icons.whatshot,
        price: 400,
      ),
      _AvatarPart(
        id: 'hair_curly',
        name: 'Curly',
        icon: Icons.bubble_chart,
        price: 400,
      ),
      _AvatarPart(
        id: 'hair_afro',
        name: 'Afro',
        icon: Icons.circle,
        price: 500,
      ),
      _AvatarPart(
        id: 'hair_ponytail',
        name: 'Ponytail',
        icon: Icons.bolt,
        price: 600,
      ),
    ],
  ),

  // -- Outfit --
  _AvatarCategory(
    label: 'Outfit',
    icon: Icons.checkroom,
    configKey: 'outfit',
    parts: [
      _AvatarPart(id: 'outfit_tshirt', name: 'T-Shirt', icon: Icons.dry_cleaning),
      _AvatarPart(
        id: 'outfit_pilot',
        name: 'Pilot',
        icon: Icons.flight,
        price: 300,
      ),
      _AvatarPart(
        id: 'outfit_suit',
        name: 'Suit',
        icon: Icons.business_center,
        price: 600,
      ),
      _AvatarPart(
        id: 'outfit_leather',
        name: 'Leather',
        icon: Icons.layers,
        price: 1000,
      ),
      _AvatarPart(
        id: 'outfit_spacesuit',
        name: 'Spacesuit',
        icon: Icons.rocket_launch,
        price: 1500,
        requiredLevel: 15,
        goldPrice: 3500,
      ),
      _AvatarPart(
        id: 'outfit_captain',
        name: 'Captain',
        icon: Icons.anchor,
        price: 2000,
        requiredLevel: 20,
        goldPrice: 5000,
      ),
    ],
  ),

  // -- Hat --
  _AvatarCategory(
    label: 'Hat',
    icon: Icons.hdr_strong,
    configKey: 'hat',
    parts: [
      _AvatarPart(id: 'hat_none', name: 'None', icon: Icons.block),
      _AvatarPart(id: 'hat_cap', name: 'Cap', icon: Icons.sports_baseball),
      _AvatarPart(
        id: 'hat_aviator',
        name: 'Aviator',
        icon: Icons.flight_takeoff,
        price: 400,
      ),
      _AvatarPart(
        id: 'hat_tophat',
        name: 'Top Hat',
        icon: Icons.vertical_align_top,
        price: 800,
      ),
      _AvatarPart(
        id: 'hat_crown',
        name: 'Crown',
        icon: Icons.workspace_premium,
        price: 2000,
        requiredLevel: 15,
        goldPrice: 5000,
      ),
      _AvatarPart(
        id: 'hat_helmet',
        name: 'Helmet',
        icon: Icons.shield,
        price: 3000,
        requiredLevel: 25,
        goldPrice: 7000,
      ),
    ],
  ),

  // -- Glasses --
  _AvatarCategory(
    label: 'Glasses',
    icon: Icons.remove_red_eye,
    configKey: 'glasses',
    parts: [
      _AvatarPart(id: 'glasses_none', name: 'None', icon: Icons.block),
      _AvatarPart(id: 'glasses_round', name: 'Round', icon: Icons.lens_outlined),
      _AvatarPart(
        id: 'glasses_aviator',
        name: 'Aviator',
        icon: Icons.airplanemode_active,
        price: 300,
      ),
      _AvatarPart(
        id: 'glasses_monocle',
        name: 'Monocle',
        icon: Icons.search,
        price: 800,
      ),
      _AvatarPart(
        id: 'glasses_futuristic',
        name: 'Visor',
        icon: Icons.vrpano,
        price: 1500,
      ),
    ],
  ),

  // -- Accessories --
  _AvatarCategory(
    label: 'Accessories',
    icon: Icons.auto_awesome,
    configKey: 'accessory',
    parts: [
      _AvatarPart(id: 'acc_none', name: 'None', icon: Icons.block),
      _AvatarPart(
        id: 'acc_scarf',
        name: 'Scarf',
        icon: Icons.waves,
        price: 500,
      ),
      _AvatarPart(
        id: 'acc_medal',
        name: 'Medal',
        icon: Icons.military_tech,
        price: 1000,
      ),
      _AvatarPart(
        id: 'acc_earring',
        name: 'Earring',
        icon: Icons.radio_button_unchecked,
        price: 1500,
      ),
      _AvatarPart(
        id: 'acc_goldChain',
        name: 'Gold Chain',
        icon: Icons.all_inclusive,
        price: 3000,
      ),
      _AvatarPart(
        id: 'acc_parrot',
        name: 'Parrot',
        icon: Icons.pets,
        price: 5000,
      ),
    ],
  ),

  // -- Companion --
  _AvatarCategory(
    label: 'Companion',
    icon: Icons.pets,
    configKey: 'companion',
    parts: [
      _AvatarPart(id: 'companion_none', name: 'None', icon: Icons.block),
      _AvatarPart(
        id: 'companion_sparrow',
        name: 'Sparrow',
        icon: Icons.flutter_dash,
        price: 2000,
        requiredLevel: 10,
        goldPrice: 5000,
      ),
      _AvatarPart(
        id: 'companion_eagle',
        name: 'Eagle',
        icon: Icons.flight,
        price: 5000,
        requiredLevel: 20,
        goldPrice: 12000,
      ),
      _AvatarPart(
        id: 'companion_parrot',
        name: 'Parrot',
        icon: Icons.pets,
        price: 8000,
        requiredLevel: 25,
        goldPrice: 18000,
      ),
      _AvatarPart(
        id: 'companion_phoenix',
        name: 'Phoenix',
        icon: Icons.local_fire_department,
        price: 15000,
        requiredLevel: 35,
        goldPrice: 35000,
      ),
      _AvatarPart(
        id: 'companion_dragon',
        name: 'Dragon',
        icon: Icons.whatshot,
        price: 30000,
        requiredLevel: 45,
        goldPrice: 60000,
      ),
    ],
  ),
];

// =============================================================================
// Avatar Editor Screen
// =============================================================================

/// Full-screen avatar customisation editor.
///
/// Players can browse categories, preview different avatar parts, purchase
/// locked items with coins, and save their chosen configuration.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  /// Current avatar configuration being edited.
  AvatarConfig _config = const AvatarConfig();

  /// Index of the active category tab.
  int _selectedCategory = 0;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the currently selected part id for the given [categoryKey].
  String _selectedPartForCategory(String categoryKey) {
    switch (categoryKey) {
      case 'face':
        return 'face_${_config.face.name}';
      case 'skin':
        return 'skin_${_config.skin.name}';
      case 'eyes':
        return 'eyes_${_config.eyes.name}';
      case 'hair':
        return 'hair_${_config.hair.name}';
      case 'outfit':
        return 'outfit_${_config.outfit.name}';
      case 'hat':
        return 'hat_${_config.hat.name}';
      case 'glasses':
        return 'glasses_${_config.glasses.name}';
      case 'accessory':
        return 'acc_${_config.accessory.name}';
      case 'companion':
        return 'companion_${_config.companion.name}';
      default:
        return '';
    }
  }

  /// Extracts the enum name suffix from a part ID.
  /// e.g. 'face_round' → 'round', 'acc_goldChain' → 'goldChain'
  static String _enumName(String prefix, String partId) {
    return partId.substring(prefix.length + 1);
  }

  /// Updates `_config` so that [categoryKey] now points to [partId].
  void _selectPart(String categoryKey, String partId) {
    setState(() {
      switch (categoryKey) {
        case 'face':
          final name = _enumName('face', partId);
          _config = _config.copyWith(
            face: AvatarFace.values.firstWhere((v) => v.name == name),
          );
        case 'skin':
          final name = _enumName('skin', partId);
          _config = _config.copyWith(
            skin: AvatarSkin.values.firstWhere((v) => v.name == name),
          );
        case 'eyes':
          final name = _enumName('eyes', partId);
          _config = _config.copyWith(
            eyes: AvatarEyes.values.firstWhere((v) => v.name == name),
          );
        case 'hair':
          final name = _enumName('hair', partId);
          _config = _config.copyWith(
            hair: AvatarHair.values.firstWhere((v) => v.name == name),
          );
        case 'outfit':
          final name = _enumName('outfit', partId);
          _config = _config.copyWith(
            outfit: AvatarOutfit.values.firstWhere((v) => v.name == name),
          );
        case 'hat':
          final name = _enumName('hat', partId);
          _config = _config.copyWith(
            hat: AvatarHat.values.firstWhere((v) => v.name == name),
          );
        case 'glasses':
          final name = _enumName('glasses', partId);
          _config = _config.copyWith(
            glasses: AvatarGlasses.values.firstWhere((v) => v.name == name),
          );
        case 'accessory':
          final name = _enumName('acc', partId);
          _config = _config.copyWith(
            accessory: AvatarAccessory.values.firstWhere((v) => v.name == name),
          );
        case 'companion':
          final name = _enumName('companion', partId);
          _config = _config.copyWith(
            companion: AvatarCompanion.values.firstWhere((v) => v.name == name),
          );
      }
    });
  }

  /// Whether the player can use [part] (either free or already owned).
  bool _canUsePart(_AvatarPart part) =>
      part.isFree || ref.read(accountProvider).ownedAvatarParts.contains(part.id);

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showPurchaseDialog(_AvatarPart part, String categoryKey) {
    final coins = ref.read(currentCoinsProvider);
    final level = ref.read(currentLevelProvider);
    final canAfford = coins >= part.price;
    final meetsLevel = !part.hasLevelGate || level >= part.requiredLevel;
    final canBuyWithGold = part.hasLevelGate && !meetsLevel && coins >= part.goldPrice;
    // Player can buy if: meets level + has coins, OR can pay gold bypass price
    final canBuy = (meetsLevel && canAfford) || canBuyWithGold;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Text(
          'Unlock ${part.name}?',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Part icon preview
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(part.icon, color: FlitColors.accent, size: 32),
            ),
            const SizedBox(height: 16),
            // Unlock conditions info box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // XP / Level unlock path
                  if (part.hasLevelGate) ...[
                    Row(
                      children: [
                        Icon(
                          meetsLevel ? Icons.check_circle : Icons.lock,
                          color: meetsLevel ? FlitColors.success : FlitColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            meetsLevel
                                ? 'Level ${part.requiredLevel} reached'
                                : 'Reach Level ${part.requiredLevel} (you are Lv.$level)',
                            style: TextStyle(
                              color: meetsLevel
                                  ? FlitColors.success
                                  : FlitColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Coin price row
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: canAfford ? FlitColors.warning : FlitColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        meetsLevel || !part.hasLevelGate
                            ? '${part.price} coins'
                            : '${part.price} coins (after reaching Lv.${part.requiredLevel})',
                        style: TextStyle(
                          color: canAfford
                              ? FlitColors.textSecondary
                              : FlitColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Gold bypass option
                  if (part.hasLevelGate && !meetsLevel) ...[
                    const Divider(color: FlitColors.cardBorder, height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.bolt,
                          color: canBuyWithGold ? FlitColors.gold : FlitColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Skip level: ${part.goldPrice} coins',
                            style: TextStyle(
                              color: canBuyWithGold
                                  ? FlitColors.gold
                                  : FlitColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: FlitColors.textMuted, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Play games to earn coins or buy from shop',
                          style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!canBuy) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
                  );
                },
                child: const Text(
                  'Not enough coins - tap to visit shop',
                  style: TextStyle(
                    color: FlitColors.error,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          if (part.hasLevelGate && !meetsLevel && canBuyWithGold)
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(accountProvider.notifier).purchaseAvatarPart(part.id, part.goldPrice);
                _selectPart(categoryKey, part.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unlocked ${part.name} with gold!'),
                    backgroundColor: FlitColors.gold,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.gold,
                foregroundColor: FlitColors.backgroundDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Buy with Gold'),
            ),
          if (meetsLevel || !part.hasLevelGate)
            ElevatedButton(
              onPressed: canAfford
                  ? () {
                      Navigator.of(dialogContext).pop();
                      ref.read(accountProvider.notifier).purchaseAvatarPart(part.id, part.price);
                      _selectPart(categoryKey, part.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Unlocked ${part.name}!'),
                          backgroundColor: FlitColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                disabledBackgroundColor: FlitColors.textMuted.withOpacity(0.3),
                disabledForegroundColor: FlitColors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Buy'),
            ),
        ],
      ),
    );
  }

  void _saveConfig() {
    // Persist logic goes here in a real implementation.
    Navigator.of(context).pop(_config);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Avatar saved!'),
        backgroundColor: FlitColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
    final ownedParts = ref.watch(accountProvider).ownedAvatarParts;

    return Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Edit Avatar'),
          centerTitle: true,
          actions: [
            // Coin balance pill
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
        body: Column(
          children: [
            // -- Avatar preview --
            _AvatarPreviewSection(config: _config),

            // -- Category tabs --
            _CategoryTabBar(
              categories: _categories,
              selectedIndex: _selectedCategory,
              onSelected: (index) {
                setState(() => _selectedCategory = index);
              },
            ),

            // -- Parts grid --
            Expanded(
              child: _PartsGrid(
                category: _categories[_selectedCategory],
                selectedPartId: _selectedPartForCategory(
                  _categories[_selectedCategory].configKey,
                ),
                ownedParts: ownedParts,
                coins: coins,
                onPartTapped: (part) {
                  final key = _categories[_selectedCategory].configKey;
                  if (_canUsePart(part)) {
                    _selectPart(key, part.id);
                  } else {
                    _showPurchaseDialog(part, key);
                  }
                },
              ),
            ),

            // -- Save button --
            _SaveBar(coins: coins, onSave: _saveConfig),
          ],
        ),
      );
  }
}

// =============================================================================
// Avatar Preview Section
// =============================================================================

class _AvatarPreviewSection extends StatelessWidget {
  const _AvatarPreviewSection({required this.config});

  final AvatarConfig config;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(
            bottom: BorderSide(color: FlitColors.cardBorder),
          ),
        ),
        child: Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: FlitColors.backgroundLight,
              shape: BoxShape.circle,
              border: Border.all(color: FlitColors.accent, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: FlitColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: AvatarWidget(config: config, size: 160),
            ),
          ),
        ),
      );
}

// =============================================================================
// Category Tab Bar
// =============================================================================

class _CategoryTabBar extends StatelessWidget {
  const _CategoryTabBar({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AvatarCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        color: FlitColors.backgroundDark,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FlitColors.accent.withOpacity(0.2)
                        : FlitColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? FlitColors.accent
                          : FlitColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected
                            ? FlitColors.accent
                            : FlitColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: isSelected
                              ? FlitColors.accent
                              : FlitColors.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

// =============================================================================
// Parts Grid
// =============================================================================

class _PartsGrid extends StatelessWidget {
  const _PartsGrid({
    required this.category,
    required this.selectedPartId,
    required this.ownedParts,
    required this.coins,
    required this.onPartTapped,
  });

  final _AvatarCategory category;
  final String selectedPartId;
  final Set<String> ownedParts;
  final int coins;
  final void Function(_AvatarPart) onPartTapped;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: category.parts.length,
        itemBuilder: (context, index) {
          final part = category.parts[index];
          final isSelected = selectedPartId == part.id;
          final isOwned = part.isFree || ownedParts.contains(part.id);
          final canAfford = coins >= part.price;
          final isLocked = !isOwned && !part.isFree;

          return _PartCard(
            part: part,
            isSelected: isSelected,
            isOwned: isOwned,
            isLocked: isLocked,
            canAfford: canAfford,
            onTap: () => onPartTapped(part),
          );
        },
      );
}

// =============================================================================
// Part Card
// =============================================================================

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.isSelected,
    required this.isOwned,
    required this.isLocked,
    required this.canAfford,
    required this.onTap,
  });

  final _AvatarPart part;
  final bool isSelected;
  final bool isOwned;
  final bool isLocked;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? FlitColors.accent.withOpacity(0.1)
                : FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? FlitColors.accent : FlitColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon preview
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: FlitColors.backgroundMid,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            part.icon,
                            size: 32,
                            color: isLocked && !canAfford
                                ? FlitColors.textMuted
                                : isSelected
                                    ? FlitColors.accent
                                    : FlitColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Name
                    Text(
                      part.name,
                      style: TextStyle(
                        color: isLocked && !canAfford
                            ? FlitColors.textMuted
                            : FlitColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price label
                    if (part.isFree)
                      const Text(
                        'FREE',
                        style: TextStyle(
                          color: FlitColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      )
                    else if (isOwned)
                      const Text(
                        'OWNED',
                        style: TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 13,
                            color: canAfford
                                ? FlitColors.warning
                                : FlitColors.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${part.price}',
                            style: TextStyle(
                              color: canAfford
                                  ? FlitColors.warning
                                  : FlitColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (part.hasLevelGate)
                        Text(
                          'Lv.${part.requiredLevel}',
                          style: const TextStyle(
                            color: FlitColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              // Selected check badge
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: FlitColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: FlitColors.textPrimary,
                    ),
                  ),
                ),

              // Lock overlay for unaffordable paid items
              if (isLocked && !canAfford)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlitColors.backgroundDark.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        color: FlitColors.textMuted,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

// =============================================================================
// Save Bar (bottom area)
// =============================================================================

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.coins,
    required this.onSave,
  });

  final int coins;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(
            top: BorderSide(color: FlitColors.cardBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coin balance display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: FlitColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$coins coins remaining',
                    style: const TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mystery plane button
              GestureDetector(
                onTap: () {
                  // Show mystery purchase dialog
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: FlitColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Mystery Plane', style: TextStyle(color: FlitColors.textPrimary)),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline, color: FlitColors.gold, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Get a random plane with one exclusive locked item!\nCost: 10,000 coins',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
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
                              const SnackBar(
                                content: Text('Mystery plane coming soon!'),
                                backgroundColor: FlitColors.gold,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlitColors.gold,
                            foregroundColor: FlitColors.backgroundDark,
                          ),
                          child: const Text('Buy'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: FlitColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FlitColors.gold.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline, color: FlitColors.gold, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'MYSTERY PLANE - 10,000 coins',
                        style: TextStyle(
                          color: FlitColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
      );
}
