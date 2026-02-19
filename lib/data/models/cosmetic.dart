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
enum CosmeticRarity { common, rare, epic, legendary }

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
    this.handling = 1.0,
    this.speed = 1.0,
    this.fuelEfficiency = 1.0,
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

  /// Handling multiplier (planes only). Higher = tighter turning circle.
  /// 1.0 = baseline. Range: 0.6 (sluggish) to 1.4 (nimble).
  final double handling;

  /// Speed multiplier (planes only). Higher = faster movement.
  /// 1.0 = baseline. Range: 0.7 (slow) to 1.5 (very fast).
  final double speed;

  /// Fuel efficiency multiplier (planes only). Higher = less fuel consumed.
  /// 1.0 = baseline. Range: 0.6 (gas guzzler) to 1.4 (economical).
  final double fuelEfficiency;

  Cosmetic copyWith({bool? isOwned, bool? isEquipped}) => Cosmetic(
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
    handling: handling,
    speed: speed,
    fuelEfficiency: fuelEfficiency,
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
    'handling': handling,
    'speed': speed,
    'fuel_efficiency': fuelEfficiency,
  };

  factory Cosmetic.fromJson(Map<String, dynamic> json) => Cosmetic(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CosmeticType.values.firstWhere((t) => t.name == json['type']),
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
    handling: (json['handling'] as num?)?.toDouble() ?? 1.0,
    speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    fuelEfficiency: (json['fuel_efficiency'] as num?)?.toDouble() ?? 1.0,
  );
}

/// Catalog of all available cosmetics.
abstract class CosmeticCatalog {
  // ---------------------------------------------------------------
  // Planes
  //
  // Attributes — handling / speed / fuelEfficiency — are multipliers
  // around 1.0. Each plane has a distinct feel: some are nimble but
  // thirsty, others are fast but sluggish in turns. Better planes are
  // more expensive and tend to have higher overall stats.
  //
  // Pricing follows gacha progression: early planes are ~4 games apart,
  // mid-tier stretches to ~20-40 games, and legendaries are aspirational
  // long-term goals (hundreds of games).
  // ---------------------------------------------------------------
  static const List<Cosmetic> planes = [
    // --- Common (sorted by price) ---
    Cosmetic(
      id: 'plane_default',
      name: 'Classic Bi-Plane',
      type: CosmeticType.plane,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'The original flit plane. Balanced and reliable.',
      colorScheme: {
        'primary': 0xFFF5F0E0,
        'secondary': 0xFFC0392B,
        'detail': 0xFF8B4513,
      },
      wingSpan: 26.0,
      handling: 1.0,
      speed: 1.0,
      fuelEfficiency: 1.0,
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'plane_paper',
      name: 'Paper Plane',
      type: CosmeticType.plane,
      price: 200,
      rarity: CosmeticRarity.common,
      description: 'Light and nimble. Glides on the wind.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFFE0E0E0,
        'detail': 0xFFCCCCCC,
      },
      wingSpan: 22.0,
      handling: 1.2,
      speed: 0.85,
      fuelEfficiency: 1.15,
    ),
    Cosmetic(
      id: 'plane_prop',
      name: 'Prop Plane',
      type: CosmeticType.plane,
      price: 400,
      rarity: CosmeticRarity.common,
      description: 'Classic propeller aircraft. Solid all-rounder.',
      colorScheme: {
        'primary': 0xFF556B2F,
        'secondary': 0xFF3B4A1F,
        'detail': 0xFF8B8B6E,
      },
      wingSpan: 28.0,
      handling: 1.1,
      speed: 0.95,
      fuelEfficiency: 1.1,
    ),
    Cosmetic(
      id: 'plane_bryanair',
      name: 'Bryanair',
      type: CosmeticType.plane,
      price: 750,
      rarity: CosmeticRarity.common,
      description: 'No frills, no legroom, but it gets you there. Eventually.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF003580,
        'detail': 0xFFFFCC00,
      },
      wingSpan: 32.0,
      handling: 0.75,
      speed: 1.0,
      fuelEfficiency: 1.3,
    ),
    Cosmetic(
      id: 'plane_seaplane',
      name: 'Island Hopper',
      type: CosmeticType.plane,
      price: 750,
      rarity: CosmeticRarity.common,
      description:
          'Float pontoons for water landings. Perfect for the Caribbean.',
      colorScheme: {
        'primary': 0xFFF0E68C,
        'secondary': 0xFF2E8B57,
        'detail': 0xFFF5F5F5,
      },
      wingSpan: 30.0,
      handling: 0.9,
      speed: 0.85,
      fuelEfficiency: 1.15,
    ),

    // --- Rare (sorted by price) ---
    Cosmetic(
      id: 'plane_jet',
      name: 'Sleek Jet',
      type: CosmeticType.plane,
      price: 1200,
      rarity: CosmeticRarity.rare,
      requiredLevel: 3,
      description: 'Fast and sharp. Burns fuel like water.',
      colorScheme: {
        'primary': 0xFFC0C0C0,
        'secondary': 0xFF4A90B8,
        'detail': 0xFF808080,
      },
      wingSpan: 23.0,
      handling: 0.9,
      speed: 1.3,
      fuelEfficiency: 0.7,
    ),
    Cosmetic(
      id: 'plane_red_baron',
      name: 'Red Baron Triplane',
      type: CosmeticType.plane,
      price: 1800,
      rarity: CosmeticRarity.rare,
      description:
          'The most feared ace of WWI. Triple the wings, triple the style.',
      colorScheme: {
        'primary': 0xFFCC3333,
        'secondary': 0xFF8B0000,
        'detail': 0xFF1A1A1A,
      },
      wingSpan: 24.0,
      handling: 1.3,
      speed: 0.8,
      fuelEfficiency: 0.9,
    ),
    Cosmetic(
      id: 'plane_rocket',
      name: 'Rocket Ship',
      type: CosmeticType.plane,
      price: 1800,
      rarity: CosmeticRarity.rare,
      requiredLevel: 5,
      description:
          'Blazing speed. Turns like a bus. Drinks fuel for breakfast.',
      colorScheme: {
        'primary': 0xFFCC3333,
        'secondary': 0xFFF5F5F5,
        'detail': 0xFFFF6600,
      },
      wingSpan: 18.0,
      handling: 0.65,
      speed: 1.4,
      fuelEfficiency: 0.6,
    ),
    Cosmetic(
      id: 'plane_spitfire',
      name: 'Spitfire',
      type: CosmeticType.plane,
      price: 2500,
      rarity: CosmeticRarity.rare,
      requiredLevel: 5,
      description: 'The legendary Battle of Britain fighter. Agile and fast.',
      colorScheme: {
        'primary': 0xFF556B2F,
        'secondary': 0xFF8B7355,
        'detail': 0xFFC0C0C0,
      },
      wingSpan: 27.0,
      handling: 1.2,
      speed: 1.15,
      fuelEfficiency: 0.9,
    ),
    Cosmetic(
      id: 'plane_lancaster',
      name: 'Lancaster Bomber',
      type: CosmeticType.plane,
      price: 3500,
      rarity: CosmeticRarity.rare,
      requiredLevel: 7,
      description: 'The mighty heavy bomber. Low and slow, but goes forever.',
      colorScheme: {
        'primary': 0xFF2F2F2F,
        'secondary': 0xFF3B3B3B,
        'detail': 0xFFCC3333,
      },
      wingSpan: 36.0,
      handling: 0.7,
      speed: 0.75,
      fuelEfficiency: 1.4,
    ),
    Cosmetic(
      id: 'plane_concorde_classic',
      name: 'Concorde Classic',
      type: CosmeticType.plane,
      price: 5000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 8,
      description: 'Supersonic nostalgia. Mach 2 in style.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF1A3A5C,
        'detail': 0xFFCC3333,
      },
      wingSpan: 20.0,
      handling: 0.8,
      speed: 1.35,
      fuelEfficiency: 0.7,
    ),

    // --- Epic (sorted by price) ---
    Cosmetic(
      id: 'plane_stealth',
      name: 'Stealth Bomber',
      type: CosmeticType.plane,
      price: 8000,
      rarity: CosmeticRarity.epic,
      requiredLevel: 10,
      description: 'Dark and mysterious. Silent but deadly efficient.',
      colorScheme: {
        'primary': 0xFF2A2A2A,
        'secondary': 0xFF1A1A1A,
        'detail': 0xFF444444,
      },
      wingSpan: 38.0,
      handling: 1.05,
      speed: 1.15,
      fuelEfficiency: 1.2,
    ),
    Cosmetic(
      id: 'plane_air_force_one',
      name: 'Air Force One',
      type: CosmeticType.plane,
      price: 12000,
      rarity: CosmeticRarity.epic,
      requiredLevel: 10,
      description: 'Presidential luxury. Smooth, fast, and fuel-efficient.',
      colorScheme: {
        'primary': 0xFFF5F5F5,
        'secondary': 0xFF1A3A5C,
        'detail': 0xFFD4A944,
      },
      wingSpan: 34.0,
      handling: 0.85,
      speed: 1.2,
      fuelEfficiency: 1.25,
    ),

    // --- Legendary (sorted by price) ---
    Cosmetic(
      id: 'plane_golden_jet',
      name: 'Golden Private Jet',
      type: CosmeticType.plane,
      price: 25000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Pure gold luxury. Handles like a dream.',
      colorScheme: {
        'primary': 0xFFD4A944,
        'secondary': 0xFF1A1A1A,
        'detail': 0xFFF0D060,
      },
      wingSpan: 29.0,
      handling: 1.15,
      speed: 1.25,
      fuelEfficiency: 1.1,
    ),
    Cosmetic(
      id: 'plane_diamond_concorde',
      name: 'Diamond Concorde',
      type: CosmeticType.plane,
      price: 50000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Supersonic elegance. Fastest plane in the game.',
      colorScheme: {
        'primary': 0xFFB0D4F1,
        'secondary': 0xFFC0C0C0,
        'detail': 0xFFE0F0FF,
      },
      wingSpan: 20.0,
      handling: 0.95,
      speed: 1.5,
      fuelEfficiency: 0.85,
    ),
    Cosmetic(
      id: 'plane_platinum_eagle',
      name: 'Platinum Eagle',
      type: CosmeticType.plane,
      price: 100000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description: 'Ultra-rare. The sky bows to the eagle. Best all-rounder.',
      colorScheme: {
        'primary': 0xFFE5E4E2,
        'secondary': 0xFF6A0DAD,
        'detail': 0xFFC0C0D0,
      },
      wingSpan: 30.0,
      handling: 1.3,
      speed: 1.3,
      fuelEfficiency: 1.25,
    ),
  ];

  // ---------------------------------------------------------------
  // Companions
  // ---------------------------------------------------------------
  static const List<Cosmetic> companions = [
    Cosmetic(
      id: 'companion_none',
      name: 'No Companion',
      type: CosmeticType.coPilot,
      price: 0,
      rarity: CosmeticRarity.common,
      description: 'Fly solo.',
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'companion_sparrow',
      name: 'Sparrow',
      type: CosmeticType.coPilot,
      price: 2000,
      rarity: CosmeticRarity.common,
      requiredLevel: 10,
      description: 'A small, nimble companion for your journey.',
    ),
    Cosmetic(
      id: 'companion_eagle',
      name: 'Eagle',
      type: CosmeticType.coPilot,
      price: 5000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 20,
      description: 'A majestic bird of prey with keen eyes.',
    ),
    Cosmetic(
      id: 'companion_parrot',
      name: 'Parrot',
      type: CosmeticType.coPilot,
      price: 8000,
      rarity: CosmeticRarity.rare,
      requiredLevel: 25,
      description: 'A colorful tropical companion.',
    ),
    Cosmetic(
      id: 'companion_phoenix',
      name: 'Phoenix',
      type: CosmeticType.coPilot,
      price: 15000,
      rarity: CosmeticRarity.epic,
      requiredLevel: 35,
      description: 'A legendary firebird risen from the ashes.',
    ),
    Cosmetic(
      id: 'companion_dragon',
      name: 'Dragon',
      type: CosmeticType.coPilot,
      price: 30000,
      rarity: CosmeticRarity.legendary,
      requiredLevel: 45,
      description: 'The ultimate companion. A mythical dragon.',
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
      colorScheme: {'primary': 0xFFF0E8DC, 'secondary': 0xFFFFFFFF},
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
      colorScheme: {'primary': 0xFFFF0000, 'secondary': 0xFF00FF00},
    ),
    Cosmetic(
      id: 'contrail_fire',
      name: 'Fire Trail',
      type: CosmeticType.contrail,
      price: 650,
      rarity: CosmeticRarity.common,
      description: 'Blazing hot contrails.',
      colorScheme: {'primary': 0xFFFF4500, 'secondary': 0xFFFFD700},
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
      colorScheme: {'primary': 0xFFFFD700, 'secondary': 0xFFFFF8DC},
    ),
    Cosmetic(
      id: 'contrail_neon',
      name: 'Neon Glow',
      type: CosmeticType.contrail,
      price: 3000,
      rarity: CosmeticRarity.rare,
      description: 'Bright neon colors.',
      requiredLevel: 7,
      colorScheme: {'primary': 0xFF00FF7F, 'secondary': 0xFF00CED1},
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
      colorScheme: {'primary': 0xFFD4A944, 'secondary': 0xFFF0D060},
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
      colorScheme: {'primary': 0xFF00FF7F, 'secondary': 0xFF9B30FF},
    ),
    Cosmetic(
      id: 'contrail_chemtrails',
      name: 'Chemtrails',
      type: CosmeticType.contrail,
      price: 50000,
      rarity: CosmeticRarity.legendary,
      isPremium: true,
      description:
          'Toxic green poison gas contrails. For the conspiracy-minded pilot.',
      colorScheme: {'primary': 0xFF00FF00, 'secondary': 0xFF7FFF00},
    ),
  ];

  static List<Cosmetic> get all => [...planes, ...contrails, ...companions];

  static Cosmetic? getById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
