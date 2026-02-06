/// Avatar body type. Affects build proportions and facial features.
/// All options are free.
enum AvatarBodyType {
  masculine,
  feminine,
}

/// Avatar face shapes. All free.
enum AvatarFace {
  round,
  oval,
  square,
  heart,
  diamond,
}

/// Avatar skin tones. All free.
enum AvatarSkin {
  light,
  fair,
  medium,
  tan,
  brown,
  dark,
}

/// Avatar eye styles. All free.
enum AvatarEyes {
  round,
  almond,
  wide,
  narrow,
  wink,
}

/// Avatar hair styles.
/// [none], [short], [medium], and [long] are free.
/// Remaining styles cost coins.
enum AvatarHair {
  none,
  short,
  medium,
  long,
  mohawk,
  curly,
  afro,
  ponytail,
}

/// Avatar outfit styles.
/// [tshirt] is free. Remaining styles cost coins.
enum AvatarOutfit {
  tshirt,
  pilot,
  suit,
  leather,
  spacesuit,
  captain,
}

/// Avatar hat styles.
/// [none] and [cap] are free. Remaining styles cost coins.
enum AvatarHat {
  none,
  cap,
  aviator,
  tophat,
  crown,
  helmet,
}

/// Avatar glasses styles.
/// [none] and [round] are free. Remaining styles cost coins.
enum AvatarGlasses {
  none,
  round,
  aviator,
  monocle,
  futuristic,
}

/// Avatar accessory styles.
/// [none] is free. Remaining styles cost coins.
enum AvatarAccessory {
  none,
  scarf,
  medal,
  earring,
  goldChain,
  parrot,
}

/// Avatar companion creatures.
/// [none] is free. Remaining companions cost coins and require high level.
enum AvatarCompanion {
  none,
  sparrow,
  eagle,
  parrot,
  phoenix,
  dragon,
}

/// Configuration that fully describes a player avatar.
///
/// Each field corresponds to a visual part of the avatar. Free defaults are
/// chosen so every new player has a complete look out of the box.
class AvatarConfig {
  const AvatarConfig({
    this.bodyType = AvatarBodyType.masculine,
    this.face = AvatarFace.round,
    this.skin = AvatarSkin.medium,
    this.eyes = AvatarEyes.round,
    this.hair = AvatarHair.short,
    this.outfit = AvatarOutfit.tshirt,
    this.hat = AvatarHat.none,
    this.glasses = AvatarGlasses.none,
    this.accessory = AvatarAccessory.none,
    this.companion = AvatarCompanion.none,
  });

  final AvatarBodyType bodyType;
  final AvatarFace face;
  final AvatarSkin skin;
  final AvatarEyes eyes;
  final AvatarHair hair;
  final AvatarOutfit outfit;
  final AvatarHat hat;
  final AvatarGlasses glasses;
  final AvatarAccessory accessory;
  final AvatarCompanion companion;

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  AvatarConfig copyWith({
    AvatarBodyType? bodyType,
    AvatarFace? face,
    AvatarSkin? skin,
    AvatarEyes? eyes,
    AvatarHair? hair,
    AvatarOutfit? outfit,
    AvatarHat? hat,
    AvatarGlasses? glasses,
    AvatarAccessory? accessory,
    AvatarCompanion? companion,
  }) =>
      AvatarConfig(
        bodyType: bodyType ?? this.bodyType,
        face: face ?? this.face,
        skin: skin ?? this.skin,
        eyes: eyes ?? this.eyes,
        hair: hair ?? this.hair,
        outfit: outfit ?? this.outfit,
        hat: hat ?? this.hat,
        glasses: glasses ?? this.glasses,
        accessory: accessory ?? this.accessory,
        companion: companion ?? this.companion,
      );

  // ---------------------------------------------------------------------------
  // Pricing helpers — returns 0 for free items
  // ---------------------------------------------------------------------------

  /// Coin cost for the given [hair] style.
  static int hairPrice(AvatarHair hair) => switch (hair) {
        AvatarHair.none => 0,
        AvatarHair.short => 0,
        AvatarHair.medium => 0,
        AvatarHair.long => 0,
        AvatarHair.mohawk => 200,
        AvatarHair.curly => 300,
        AvatarHair.afro => 400,
        AvatarHair.ponytail => 500,
      };

  /// Coin cost for the given [outfit] style.
  static int outfitPrice(AvatarOutfit outfit) => switch (outfit) {
        AvatarOutfit.tshirt => 0,
        AvatarOutfit.pilot => 300,
        AvatarOutfit.suit => 600,
        AvatarOutfit.leather => 1000,
        AvatarOutfit.spacesuit => 1500,
        AvatarOutfit.captain => 2000,
      };

  /// Coin cost for the given [hat] style.
  static int hatPrice(AvatarHat hat) => switch (hat) {
        AvatarHat.none => 0,
        AvatarHat.cap => 0,
        AvatarHat.aviator => 400,
        AvatarHat.tophat => 800,
        AvatarHat.crown => 2000,
        AvatarHat.helmet => 3000,
      };

  /// Coin cost for the given [glasses] style.
  static int glassesPrice(AvatarGlasses glasses) => switch (glasses) {
        AvatarGlasses.none => 0,
        AvatarGlasses.round => 0,
        AvatarGlasses.aviator => 300,
        AvatarGlasses.monocle => 800,
        AvatarGlasses.futuristic => 1500,
      };

  /// Coin cost for the given [accessory] style.
  static int accessoryPrice(AvatarAccessory accessory) => switch (accessory) {
        AvatarAccessory.none => 0,
        AvatarAccessory.scarf => 500,
        AvatarAccessory.medal => 1000,
        AvatarAccessory.earring => 1500,
        AvatarAccessory.goldChain => 3000,
        AvatarAccessory.parrot => 5000,
      };

  /// Coin cost for the given [companion].
  static int companionPrice(AvatarCompanion companion) => switch (companion) {
        AvatarCompanion.none => 0,
        AvatarCompanion.sparrow => 2000,
        AvatarCompanion.eagle => 5000,
        AvatarCompanion.parrot => 8000,
        AvatarCompanion.phoenix => 15000,
        AvatarCompanion.dragon => 30000,
      };

  /// Total coin cost of every non-free item in this configuration.
  int get totalCost =>
      hairPrice(hair) +
      outfitPrice(outfit) +
      hatPrice(hat) +
      glassesPrice(glasses) +
      accessoryPrice(accessory) +
      companionPrice(companion);

  /// Rarity tier based on [totalCost].
  ///
  ///   0         → Common   (luck bonus 0)
  ///   1-999     → Uncommon (luck bonus 1)
  ///   1000-4999 → Rare     (luck bonus 2)
  ///   5000-14999→ Epic     (luck bonus 3)
  ///   15000+    → Legendary(luck bonus 5)
  String get rarityTier {
    final cost = totalCost;
    if (cost >= 15000) return 'Legendary';
    if (cost >= 5000) return 'Epic';
    if (cost >= 1000) return 'Rare';
    if (cost >= 1) return 'Uncommon';
    return 'Common';
  }

  /// Luck bonus for licence rerolls based on avatar rarity.
  /// Higher values give better odds when rolling licence stats.
  int get luckBonus {
    final cost = totalCost;
    if (cost >= 15000) return 5;
    if (cost >= 5000) return 3;
    if (cost >= 1000) return 2;
    if (cost >= 1) return 1;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'body_type': bodyType.name,
        'face': face.name,
        'skin': skin.name,
        'eyes': eyes.name,
        'hair': hair.name,
        'outfit': outfit.name,
        'hat': hat.name,
        'glasses': glasses.name,
        'accessory': accessory.name,
        'companion': companion.name,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        bodyType: AvatarBodyType.values.firstWhere(
          (v) => v.name == json['body_type'],
          orElse: () => AvatarBodyType.masculine,
        ),
        face: AvatarFace.values.firstWhere(
          (v) => v.name == json['face'],
          orElse: () => AvatarFace.round,
        ),
        skin: AvatarSkin.values.firstWhere(
          (v) => v.name == json['skin'],
          orElse: () => AvatarSkin.medium,
        ),
        eyes: AvatarEyes.values.firstWhere(
          (v) => v.name == json['eyes'],
          orElse: () => AvatarEyes.round,
        ),
        hair: AvatarHair.values.firstWhere(
          (v) => v.name == json['hair'],
          orElse: () => AvatarHair.short,
        ),
        outfit: AvatarOutfit.values.firstWhere(
          (v) => v.name == json['outfit'],
          orElse: () => AvatarOutfit.tshirt,
        ),
        hat: AvatarHat.values.firstWhere(
          (v) => v.name == json['hat'],
          orElse: () => AvatarHat.none,
        ),
        glasses: AvatarGlasses.values.firstWhere(
          (v) => v.name == json['glasses'],
          orElse: () => AvatarGlasses.none,
        ),
        accessory: AvatarAccessory.values.firstWhere(
          (v) => v.name == json['accessory'],
          orElse: () => AvatarAccessory.none,
        ),
        companion: AvatarCompanion.values.firstWhere(
          (v) => v.name == json['companion'],
          orElse: () => AvatarCompanion.none,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarConfig &&
          bodyType == other.bodyType &&
          face == other.face &&
          skin == other.skin &&
          eyes == other.eyes &&
          hair == other.hair &&
          outfit == other.outfit &&
          hat == other.hat &&
          glasses == other.glasses &&
          accessory == other.accessory &&
          companion == other.companion;

  @override
  int get hashCode => Object.hash(
        bodyType,
        face,
        skin,
        eyes,
        hair,
        outfit,
        hat,
        glasses,
        accessory,
        companion,
      );
}
