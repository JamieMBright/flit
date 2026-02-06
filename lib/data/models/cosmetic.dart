/// Type of cosmetic item.
enum CosmeticType {
  plane,
  contrail,
  badge,
}

/// A purchasable cosmetic item.
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
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
        description: json['description'] as String?,
        previewAsset: json['preview_asset'] as String?,
        isOwned: json['is_owned'] as bool? ?? false,
        isEquipped: json['is_equipped'] as bool? ?? false,
        requiredLevel: json['required_level'] as int?,
      );
}

/// Catalog of all available cosmetics.
abstract class CosmeticCatalog {
  static const List<Cosmetic> planes = [
    Cosmetic(
      id: 'plane_default',
      name: 'Classic Bi-Plane',
      type: CosmeticType.plane,
      price: 0,
      description: 'The original flit plane.',
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'plane_jet',
      name: 'Sleek Jet',
      type: CosmeticType.plane,
      price: 500,
      description: 'A modern jet fighter look.',
    ),
    Cosmetic(
      id: 'plane_prop',
      name: 'Prop Plane',
      type: CosmeticType.plane,
      price: 300,
      description: 'Classic propeller aircraft.',
    ),
    Cosmetic(
      id: 'plane_stealth',
      name: 'Stealth Bomber',
      type: CosmeticType.plane,
      price: 1000,
      description: 'Dark and mysterious.',
      requiredLevel: 10,
    ),
    Cosmetic(
      id: 'plane_paper',
      name: 'Paper Plane',
      type: CosmeticType.plane,
      price: 200,
      description: 'Simple and elegant.',
    ),
    Cosmetic(
      id: 'plane_rocket',
      name: 'Rocket Ship',
      type: CosmeticType.plane,
      price: 750,
      description: 'Blast off to new heights!',
      requiredLevel: 5,
    ),
  ];

  static const List<Cosmetic> contrails = [
    Cosmetic(
      id: 'contrail_default',
      name: 'White Smoke',
      type: CosmeticType.contrail,
      price: 0,
      description: 'Classic white contrails.',
      isOwned: true,
      isEquipped: true,
    ),
    Cosmetic(
      id: 'contrail_rainbow',
      name: 'Rainbow Trail',
      type: CosmeticType.contrail,
      price: 400,
      description: 'Leave a colorful streak!',
    ),
    Cosmetic(
      id: 'contrail_fire',
      name: 'Fire Trail',
      type: CosmeticType.contrail,
      price: 350,
      description: 'Blazing hot contrails.',
    ),
    Cosmetic(
      id: 'contrail_sparkle',
      name: 'Sparkle',
      type: CosmeticType.contrail,
      price: 450,
      description: 'Glittering magical dust.',
      requiredLevel: 3,
    ),
    Cosmetic(
      id: 'contrail_neon',
      name: 'Neon Glow',
      type: CosmeticType.contrail,
      price: 600,
      description: 'Bright neon colors.',
      requiredLevel: 7,
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
