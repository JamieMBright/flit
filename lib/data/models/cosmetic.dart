/// Type of cosmetic item.
enum CosmeticType {
  plane,
  contrail,
  coPilot,
  landingEffect,
  mapSkin,
  title,
  badge,
}

/// Rarity tier for cosmetic items.
enum CosmeticRarity {
  common,
  rare,
  epic,
  legendary,
}

/// A purchasable cosmetic item.
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.rarity = CosmeticRarity.common,
    this.isPremium = false,
    this.realMoneyPrice,
    this.colorScheme,
    this.description,
    this.previewAsset,
    this.isOwned = false,
    this.isEquipped = false,
    this.requiredLevel,
    this.wingSpan,
  });

  final String id;
  final String name;
  final CosmeticType type;
  final int price;
  final CosmeticRarity rarity;
  final bool isPremium;
  final double? realMoneyPrice;
  final Map<String, int>? colorScheme;
  final String? description;
  final String? previewAsset;
  final bool isOwned;
  final bool isEquipped;
  final int? requiredLevel;
  
  /// Wing span in pixels (for plane cosmetics only).
  /// Determines both visual rendering and contrail positioning.
  final double? wingSpan;

  Cosmetic copyWith({
    bool? isOwned,
    bool? isEquipped,
  }) =>
      Cosmetic(
        id: id,
        name: name,
        type: type,
        price: price,
        rarity: rarity,
        isPremium: isPremium,
        realMoneyPrice: realMoneyPrice,
        colorScheme: colorScheme,
        description: description,
        previewAsset: previewAsset,
        isOwned: isOwned ?? this.isOwned,
        isEquipped: isEquipped ?? this.isEquipped,
        requiredLevel: requiredLevel,
        wingSpan: wingSpan,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'price': price,
        'rarity': rarity.name,
        'is_premium': isPremium,
        'real_money_price': realMoneyPrice,
        'color_scheme': colorScheme,
        'description': description,
        'preview_asset': previewAsset,
        'is_owned': isOwned,
        'is_equipped': isEquipped,
        'required_level': requiredLevel,
        'wing_span': wingSpan,
      };

  factory Cosmetic.fromJson(Map<String, dynamic> json) => Cosmetic(
        id: json['id'] as String,
        name: json['name'] as String,
        type: CosmeticType.values.firstWhere(
          (t) => t.name == json['type'],
        ),
        price: json['price'] as int,
        rarity: CosmeticRarity.values.firstWhere(
          (r) => r.name == json['rarity'],
          orElse: () => CosmeticRarity.common,
        ),
        isPremium: json['is_premium'] as bool? ?? false,
        realMoneyPrice: (json['real_money_price'] as num?)?.toDouble(),
        colorScheme: (json['color_scheme'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ),
        description: json['description'] as String?,
        previewAsset: json['preview_asset'] as String?,
        isOwned: json['is_owned'] as bool? ?? false,
        isEquipped: json['is_equipped'] as bool? ?? false,
        requiredLevel: json['required_level'] as int?,
        wingSpan: (json['wing_span'] as num?)?.toDouble(),
      );
}

/// Catalog of all available cosmetics.
abstract class CosmeticCatalog {
  // ---------------------------------------------------------------
  // Planes
  // ---------------------------------------------------------------
  static const List<Cosmetic> planes = [
    // --- Common (sorted by price) ---
    Cosmetic(
      id: 'plane_default',
      name: 'Classic Bi-Plane',
      type: CosmeticType.plane,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'The original flit plane.',
      colorScheme: {
        'primary': 0xFFF5F0E0,
        'secondary': 0xFFC0392B,
        'detail': 0xFF8B4513,
      },
      wingSpan: 26.0, // Default/baseline wing span
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'plane_paper',
      name: 'Paper Plane',
      type: CosmeticType.plane,
      price: 500,
      rarity: CosmeticRarity.common,
      description: 'Simple and elegant.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFFE0E0E0,
        'detail': 0xFFCCCCCC,
      },
      wingSpan: 22.0, // Smaller, narrower wings
    ),
    Cosmetic(
      id: 'plane_prop',
      name: 'Prop Plane',
      type: CosmeticType.plane,
      price: 800,
      rarity: CosmeticRarity.common,
      description: 'Classic propeller aircraft.',
      colorScheme: {
        'primary': 0xFF556B2F,
        'secondary': 0xFF3B4A1F,
        'detail': 0xFF8B8B6E,
      },
      wingSpan: 28.0, // Slightly wider than default
    ),
    Cosmetic(
      id: 'plane_bryanair',
      name: 'Bryanair',
      type: CosmeticType.plane,
      price: 1500,
      rarity: CosmeticRarity.common,
      description: 'No frills, no legroom, but it gets you there. Eventually.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF003580,
        'detail': 0xFFFFCC00,
      },
      wingSpan: 32.0, // Commercial airliner - wide wings
    ),
    Cosmetic(
      id: 'plane_seaplane',
      name: 'Island Hopper',
      type: CosmeticType.plane,
      price: 2000,
      rarity: CosmeticRarity.common,
      description: 'Float pontoons for water landings. Perfect for the Caribbean.',
      colorScheme: {
        'primary': 0xFFF0E68C,
        'secondary': 0xFF2E8B57,
        'detail': 0xFFF5F5F5,
      },
      wingSpan: 30.0, // Seaplane - wide for stability
    ),

    // --- Rare (sorted by price) ---
    Cosmetic(
      id: 'plane_jet',
      name: 'Sleek Jet',
      type: CosmeticType.plane,
      price: 2500,
      rarity: CosmeticRarity.rare,
      requiredLevel: 3,
      description: 'A modern jet fighter look.',
      colorScheme: {
        'primary': 0xFFC0C0C0,
        'secondary': 0xFF4A90B8,
        'detail': 0xFF808080,
      },
      wingSpan: 23.0, // Fighter jet - shorter, swept wings
    ),
    Cosmetic(
      id: 'plane_red_baron',
      name: 'Red Baron Triplane',
      type: CosmeticType.plane,
      price: 3500,
      rarity: CosmeticRarity.rare,
      description: 'The most feared ace of WWI. Triple the wings, triple the style.',
      colorScheme: {
        'primary': 0xFFCC3333,
        'secondary': 0xFF8B0000,
        'detail': 0xFF1A1A1A,
      },
      wingSpan: 24.0, // Triplane - shorter individual wings
    ),
    Cosmetic(
      id: 'plane_rocket',
      name: 'Rocket Ship',
      type: CosmeticType.plane,
      price: 3500,
      rarity: CosmeticRarity.rare,
      requiredLevel: 5,
      description: 'Blast off to new heights!',
      colorScheme: {
        'primary': 0xFFCC3333,
        'secondary': 0xFFF5F5F5,
        'detail': 0xFFFF6600,
      },
      wingSpan: 18.0, // Rocket - very narrow fins
    ),
    Cosmetic(
      id: 'plane_spitfire',
      name: 'Spitfire',
      type: CosmeticType.plane,
      price: 4000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 5,
      description: 'The legendary Battle of Britain fighter.',
      colorScheme: {
        'primary': 0xFF556B2F,
        'secondary': 0xFF8B7355,
        'detail': 0xFFC0C0C0,
      },
      wingSpan: 27.0, // Spitfire - iconic elliptical wings
    ),
    Cosmetic(
      id: 'plane_lancaster',
      name: 'Lancaster Bomber',
      type: CosmeticType.plane,
      price: 5000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 7,
      description: 'The mighty heavy bomber. Low and slow, full of character.',
      colorScheme: {
        'primary': 0xFF2F2F2F,
        'secondary': 0xFF3B3B3B,
        'detail': 0xFFCC3333,
      },
      wingSpan: 36.0, // Heavy bomber - very wide wings
    ),
    Cosmetic(
      id: 'plane_concorde_classic',
      name: 'Concorde Classic',
      type: CosmeticType.plane,
      price: 6000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 8,
      description: 'Supersonic nostalgia. Mach 2 in style.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF1A3A5C,
        'detail': 0xFFCC3333,
      },
      wingSpan: 20.0, // Concorde - delta wing, narrow
    ),

    // --- Epic (sorted by price) ---
    Cosmetic(
      id: 'plane_stealth',
      name: 'Stealth Bomber',
      type: CosmeticType.plane,
      price: 8000,
      rarity: CosmeticRarity.epic,
      requiredLevel: 10,
      description: 'Dark and mysterious.',
      colorScheme: {
        'primary': 0xFF2A2A2A,
        'secondary': 0xFF1A1A1A,
        'detail': 0xFF444444,
      },
      wingSpan: 38.0, // Stealth bomber - very wide flying wing
    ),
    Cosmetic(
      id: 'plane_air_force_one',
      name: 'Air Force One',
      type: CosmeticType.plane,
      price: 15000,
      rarity: CosmeticRarity.epic,
      requiredLevel: 10,
      description: 'Presidential luxury at 35,000 feet.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF1A3A5C,
        'detail': 0xFFD4A944,
      },
      wingSpan: 34.0, // Large airliner - wide wings
    ),

    // --- Legendary (sorted by price) ---
    Cosmetic(
      id: 'plane_golden_jet',
      name: 'Golden Private Jet',
      type: CosmeticType.plane,
      price: 25000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'The ultimate status symbol. Pure gold luxury.',
      colorScheme: {
        'primary': 0xFFD4A944,
        'secondary': 0xFF1A1A1A,
        'detail': 0xFFF0D060,
      },
      wingSpan: 29.0, // Private jet - sleek swept wings
    ),
    Cosmetic(
      id: 'plane_diamond_concorde',
      name: 'Diamond Concorde',
      type: CosmeticType.plane,
      price: 50000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Supersonic elegance. Diamond-encrusted speed.',
      colorScheme: {
        'primary': 0xFFB0D4F1,
        'secondary': 0xFFC0C0C0,
        'detail': 0xFFE0F0FF,
      },
      wingSpan: 20.0, // Concorde variant - delta wing
    ),
    Cosmetic(
      id: 'plane_platinum_eagle',
      name: 'Platinum Eagle',
      type: CosmeticType.plane,
      price: 100000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Ultra-rare. The sky bows to the eagle.',
      colorScheme: {
        'primary': 0xFFE5E4E2,
        'secondary': 0xFF6A0DAD,
        'detail': 0xFFC0C0D0,
      },
      wingSpan: 30.0, // Eagle - wide majestic wings
    ),
  ];

  // ---------------------------------------------------------------
  // Contrails
  // ---------------------------------------------------------------
  static const List<Cosmetic> contrails = [
    // --- Free / Common ---
    Cosmetic(
      id: 'contrail_default',
      name: 'Water Vapour',
      type: CosmeticType.contrail,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'Classic water vapour contrails.',
      colorScheme: {
        'primary': 0xFFF0E8DC,
        'secondary': 0xFFFFFFFF,
      },
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'contrail_rainbow',
      name: 'Rainbow Trail',
      type: CosmeticType.contrail,
      price: 750,
      rarity: CosmeticRarity.common,
      description: 'Leave a colorful streak!',
      colorScheme: {
        'primary': 0xFFFF0000,
        'secondary': 0xFF00FF00,
      },
    ),
    Cosmetic(
      id: 'contrail_fire',
      name: 'Fire Trail',
      type: CosmeticType.contrail,
      price: 650,
      rarity: CosmeticRarity.common,
      description: 'Blazing hot contrails.',
      colorScheme: {
        'primary': 0xFFFF4500,
        'secondary': 0xFFFFD700,
      },
    ),

    // --- Rare ---
    Cosmetic(
      id: 'contrail_sparkle',
      name: 'Sparkle',
      type: CosmeticType.contrail,
      price: 2000,
      rarity: CosmeticRarity.rare,
      description: 'Glittering magical dust.',
      requiredLevel: 3,
      colorScheme: {
        'primary': 0xFFFFD700,
        'secondary': 0xFFFFF8DC,
      },
    ),
    Cosmetic(
      id: 'contrail_neon',
      name: 'Neon Glow',
      type: CosmeticType.contrail,
      price: 3000,
      rarity: CosmeticRarity.rare,
      description: 'Bright neon colors.',
      requiredLevel: 7,
      colorScheme: {
        'primary': 0xFF00FF7F,
        'secondary': 0xFF00CED1,
      },
    ),

    // --- Epic / Premium ---
    Cosmetic(
      id: 'contrail_gold_dust',
      name: 'Gold Dust',
      type: CosmeticType.contrail,
      price: 12000,
      rarity: CosmeticRarity.epic,
      isPremium: true,
      description: 'A trail of golden particles in your wake.',
      colorScheme: {
        'primary': 0xFFD4A944,
        'secondary': 0xFFF0D060,
      },
    ),

    // --- Legendary / Premium ---
    Cosmetic(
      id: 'contrail_aurora',
      name: 'Aurora Trail',
      type: CosmeticType.contrail,
      price: 20000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'The northern lights follow you across the sky.',
      colorScheme: {
        'primary': 0xFF00FF7F,
        'secondary': 0xFF9B30FF,
      },
    ),
    Cosmetic(
      id: 'contrail_chemtrails',
      name: 'Chemtrails',
      type: CosmeticType.contrail,
      price: 50000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Toxic green poison gas contrails. For the conspiracy-minded pilot.',
      colorScheme: {
        'primary': 0xFF00FF00,
        'secondary': 0xFF7FFF00,
      },
    ),
  ];

  static List<Cosmetic> get all => [...planes, ...contrails];

  static Cosmetic? getById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
