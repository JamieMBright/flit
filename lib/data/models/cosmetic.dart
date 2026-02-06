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
      );
}

/// Catalog of all available cosmetics.
abstract class CosmeticCatalog {
  // ---------------------------------------------------------------
  // Planes
  // ---------------------------------------------------------------
  static const List<Cosmetic> planes = [
    // --- Free / Common ---
    Cosmetic(
      id: 'plane_default',
      name: 'Classic Bi-Plane',
      type: CosmeticType.plane,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'The original flit plane.',
      colorScheme: {
        'primary': 0xFFF5F0E0,   // cream body
        'secondary': 0xFFC0392B, // red accents
        'detail': 0xFF8B4513,    // brown struts
      },
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'plane_prop',
      name: 'Prop Plane',
      type: CosmeticType.plane,
      price: 800,
      rarity: CosmeticRarity.common,
      description: 'Classic propeller aircraft.',
      colorScheme: {
        'primary': 0xFF556B2F,   // olive green body
        'secondary': 0xFF3B4A1F, // dark olive
        'detail': 0xFF8B8B6E,   // khaki accents
      },
    ),
    Cosmetic(
      id: 'plane_paper',
      name: 'Paper Plane',
      type: CosmeticType.plane,
      price: 600,
      rarity: CosmeticRarity.common,
      description: 'Simple and elegant.',
      colorScheme: {
        'primary': 0xFFF5F5F5,   // white
        'secondary': 0xFFE0E0E0, // light gray folds
        'detail': 0xFFCCCCCC,    // shadow lines
      },
    ),

    // --- Rare ---
    Cosmetic(
      id: 'plane_jet',
      name: 'Sleek Jet',
      type: CosmeticType.plane,
      price: 2500,
      rarity: CosmeticRarity.rare,
      description: 'A modern jet fighter look.',
      requiredLevel: 3,
      colorScheme: {
        'primary': 0xFFC0C0C0,   // silver body
        'secondary': 0xFF4A90B8, // blue accents
        'detail': 0xFF808080,    // gunmetal
      },
    ),
    Cosmetic(
      id: 'plane_rocket',
      name: 'Rocket Ship',
      type: CosmeticType.plane,
      price: 3500,
      rarity: CosmeticRarity.rare,
      description: 'Blast off to new heights!',
      requiredLevel: 5,
      colorScheme: {
        'primary': 0xFFCC3333,   // red body
        'secondary': 0xFFF5F5F5, // white trim
        'detail': 0xFFFF6600,    // orange flame
      },
    ),

    // --- Epic ---
    Cosmetic(
      id: 'plane_stealth',
      name: 'Stealth Bomber',
      type: CosmeticType.plane,
      price: 8000,
      rarity: CosmeticRarity.epic,
      description: 'Dark and mysterious.',
      requiredLevel: 10,
      colorScheme: {
        'primary': 0xFF2A2A2A,   // dark gray body
        'secondary': 0xFF1A1A1A, // near-black
        'detail': 0xFF444444,    // subtle edges
      },
    ),

    // --- Legendary / Premium ---
    Cosmetic(
      id: 'plane_golden_jet',
      name: 'Golden Private Jet',
      type: CosmeticType.plane,
      price: 25000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      realMoneyPrice: 9.99,
      description: 'The ultimate status symbol. Pure gold luxury.',
      colorScheme: {
        'primary': 0xFFD4A944,   // gold body
        'secondary': 0xFF1A1A1A, // black trim
        'detail': 0xFFF0D060,    // bright gold highlights
      },
    ),
    Cosmetic(
      id: 'plane_diamond_concorde',
      name: 'Diamond Concorde',
      type: CosmeticType.plane,
      price: 50000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      realMoneyPrice: 19.99,
      description: 'Supersonic elegance. Diamond-encrusted speed.',
      colorScheme: {
        'primary': 0xFFB0D4F1,   // diamond blue body
        'secondary': 0xFFC0C0C0, // silver trim
        'detail': 0xFFE0F0FF,    // ice-white sparkle
      },
    ),
    Cosmetic(
      id: 'plane_platinum_eagle',
      name: 'Platinum Eagle',
      type: CosmeticType.plane,
      price: 100000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      realMoneyPrice: 49.99,
      description: 'Ultra-rare. The sky bows to the eagle.',
      colorScheme: {
        'primary': 0xFFE5E4E2,   // platinum body
        'secondary': 0xFF6A0DAD, // royal purple
        'detail': 0xFFC0C0D0,    // platinum shimmer
      },
    ),

    // --- Aviation Enthusiast ---
    Cosmetic(
      id: 'plane_spitfire',
      name: 'Spitfire',
      type: CosmeticType.plane,
      price: 4000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 5,
      description: 'The legendary Battle of Britain fighter.',
      colorScheme: {
        'primary': 0xFF556B2F,   // RAF green
        'secondary': 0xFF8B7355, // brown camo
        'detail': 0xFFC0C0C0,    // silver roundels
      },
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
        'primary': 0xFF2F2F2F,   // night black
        'secondary': 0xFF3B3B3B, // dark gray
        'detail': 0xFFCC3333,    // red roundel
      },
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
        'primary': 0xFFF5F5F5,   // white fuselage
        'secondary': 0xFF1A3A5C, // navy blue
        'detail': 0xFFD4A944,    // gold trim
      },
    ),
    Cosmetic(
      id: 'plane_bryanair',
      name: 'Bryanair',
      type: CosmeticType.plane,
      price: 1500,
      rarity: CosmeticRarity.common,
      description: 'No frills, no legroom, but it gets you there. Eventually.',
      colorScheme: {
        'primary': 0xFFF5F5F5,   // white body
        'secondary': 0xFF003580, // budget blue
        'detail': 0xFFFFCC00,    // yellow trim
      },
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
        'primary': 0xFFF5F5F5,   // white body
        'secondary': 0xFF1A3A5C, // BA blue tail
        'detail': 0xFFCC3333,    // red accent stripe
      },
    ),
    Cosmetic(
      id: 'plane_red_baron',
      name: 'Red Baron Triplane',
      type: CosmeticType.plane,
      price: 3500,
      rarity: CosmeticRarity.rare,
      description: 'The most feared ace of WWI. Triple the wings, triple the style.',
      colorScheme: {
        'primary': 0xFFCC3333,   // iconic red
        'secondary': 0xFF8B0000, // dark red
        'detail': 0xFF1A1A1A,    // black iron crosses
      },
    ),
    Cosmetic(
      id: 'plane_seaplane',
      name: 'Island Hopper',
      type: CosmeticType.plane,
      price: 2000,
      rarity: CosmeticRarity.common,
      description: 'Float pontoons for water landings. Perfect for the Caribbean.',
      colorScheme: {
        'primary': 0xFFF0E68C,   // sandy yellow
        'secondary': 0xFF2E8B57, // sea green
        'detail': 0xFFF5F5F5,    // white pontoons
      },
    ),
  ];

  // ---------------------------------------------------------------
  // Contrails
  // ---------------------------------------------------------------
  static const List<Cosmetic> contrails = [
    // --- Free / Common ---
    Cosmetic(
      id: 'contrail_default',
      name: 'White Smoke',
      type: CosmeticType.contrail,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'Classic white contrails.',
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
      realMoneyPrice: 4.99,
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
      realMoneyPrice: 7.99,
      description: 'The northern lights follow you across the sky.',
      colorScheme: {
        'primary': 0xFF00FF7F,
        'secondary': 0xFF9B30FF,
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
