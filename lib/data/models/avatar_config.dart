/// Avatar eyes variant. Maps to DiceBear Adventurer 'eyes' option.
/// 26 variants available. First 13 are free, rest cost coins.
enum AvatarEyes {
  variant01, variant02, variant03, variant04, variant05,
  variant06, variant07, variant08, variant09, variant10,
  variant11, variant12, variant13, variant14, variant15,
  variant16, variant17, variant18, variant19, variant20,
  variant21, variant22, variant23, variant24, variant25,
  variant26;

  String get apiValue => name;
}

/// Avatar eyebrows variant. Maps to DiceBear Adventurer 'eyebrows' option.
/// 15 variants available. First 8 are free, rest cost coins.
enum AvatarEyebrows {
  variant01, variant02, variant03, variant04, variant05,
  variant06, variant07, variant08, variant09, variant10,
  variant11, variant12, variant13, variant14, variant15;

  String get apiValue => name;
}

/// Avatar mouth variant. Maps to DiceBear Adventurer 'mouth' option.
/// 30 variants available. First 15 are free, rest cost coins.
enum AvatarMouth {
  variant01, variant02, variant03, variant04, variant05,
  variant06, variant07, variant08, variant09, variant10,
  variant11, variant12, variant13, variant14, variant15,
  variant16, variant17, variant18, variant19, variant20,
  variant21, variant22, variant23, variant24, variant25,
  variant26, variant27, variant28, variant29, variant30;

  String get apiValue => name;
}

/// Avatar hair style. Maps to DiceBear Adventurer 'hair' option.
/// 45 variants (19 short + 26 long) plus none.
/// [none] + first 5 short + first 5 long are free.
enum AvatarHair {
  none,
  short01, short02, short03, short04, short05,
  short06, short07, short08, short09, short10,
  short11, short12, short13, short14, short15,
  short16, short17, short18, short19,
  long01, long02, long03, long04, long05,
  long06, long07, long08, long09, long10,
  long11, long12, long13, long14, long15,
  long16, long17, long18, long19, long20,
  long21, long22, long23, long24, long25, long26;

  String get apiValue => name;

  /// Display-friendly label for the hair option.
  String get label {
    if (this == none) return 'None';
    final raw = name;
    if (raw.startsWith('short')) return 'Short ${raw.substring(5)}';
    return 'Long ${raw.substring(4)}';
  }
}

/// Avatar hair color. Maps to DiceBear Adventurer 'hairColor' option.
/// Natural colors are free, fantasy colors cost coins.
enum AvatarHairColor {
  brown('ac6511', 'Brown'),
  auburn('cb6820', 'Auburn'),
  darkRed('ab2a18', 'Dark Red'),
  blonde('e5d7a3', 'Blonde'),
  sandy('b9a05f', 'Sandy'),
  chestnut('796a45', 'Chestnut'),
  darkBrown('6a4e35', 'Dark Brown'),
  veryDark('562306', 'Very Dark'),
  black('0e0e0e', 'Black'),
  gray('afafaf', 'Gray'),
  green('3eac2c', 'Green'),
  teal('85c2c6', 'Teal'),
  pink('dba3be', 'Pink'),
  purple('592454', 'Purple');

  const AvatarHairColor(this.hex, this.label);
  final String hex;
  final String label;
}

/// Avatar skin color. Maps to DiceBear Adventurer 'skinColor' option.
/// All skin tones are free.
enum AvatarSkinColor {
  light('f2d3b1', 'Light'),
  mediumLight('ecad80', 'Medium Light'),
  medium('9e5622', 'Medium'),
  dark('763900', 'Dark');

  const AvatarSkinColor(this.hex, this.label);
  final String hex;
  final String label;
}

/// Avatar glasses variant. Maps to DiceBear Adventurer 'glasses' option.
/// [none] is free. All glasses styles cost coins.
enum AvatarGlasses {
  none,
  variant01, variant02, variant03, variant04, variant05;

  String get apiValue => name;
}

/// Avatar earrings variant. Maps to DiceBear Adventurer 'earrings' option.
/// [none] is free. All earring styles cost coins.
enum AvatarEarrings {
  none,
  variant01, variant02, variant03, variant04, variant05, variant06;

  String get apiValue => name;
}

/// Avatar feature overlay. Maps to DiceBear Adventurer 'features' option.
/// All features are free.
enum AvatarFeature {
  none('None'),
  mustache('Mustache'),
  blush('Blush'),
  birthmark('Birthmark'),
  freckles('Freckles');

  const AvatarFeature(this.label);
  final String label;
}

/// Avatar companion creatures.
/// [none] is free. Remaining companions cost coins and require high level.
/// Companions fly behind the plane in-game (rendered separately).
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
/// Each field corresponds to a DiceBear Adventurer customisation option.
/// Free defaults are chosen so every new player has a complete look.
class AvatarConfig {
  const AvatarConfig({
    this.eyes = AvatarEyes.variant01,
    this.eyebrows = AvatarEyebrows.variant01,
    this.mouth = AvatarMouth.variant01,
    this.hair = AvatarHair.short01,
    this.hairColor = AvatarHairColor.brown,
    this.skinColor = AvatarSkinColor.mediumLight,
    this.glasses = AvatarGlasses.none,
    this.earrings = AvatarEarrings.none,
    this.feature = AvatarFeature.none,
    this.companion = AvatarCompanion.none,
  });

  final AvatarEyes eyes;
  final AvatarEyebrows eyebrows;
  final AvatarMouth mouth;
  final AvatarHair hair;
  final AvatarHairColor hairColor;
  final AvatarSkinColor skinColor;
  final AvatarGlasses glasses;
  final AvatarEarrings earrings;
  final AvatarFeature feature;
  final AvatarCompanion companion;

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  AvatarConfig copyWith({
    AvatarEyes? eyes,
    AvatarEyebrows? eyebrows,
    AvatarMouth? mouth,
    AvatarHair? hair,
    AvatarHairColor? hairColor,
    AvatarSkinColor? skinColor,
    AvatarGlasses? glasses,
    AvatarEarrings? earrings,
    AvatarFeature? feature,
    AvatarCompanion? companion,
  }) =>
      AvatarConfig(
        eyes: eyes ?? this.eyes,
        eyebrows: eyebrows ?? this.eyebrows,
        mouth: mouth ?? this.mouth,
        hair: hair ?? this.hair,
        hairColor: hairColor ?? this.hairColor,
        skinColor: skinColor ?? this.skinColor,
        glasses: glasses ?? this.glasses,
        earrings: earrings ?? this.earrings,
        feature: feature ?? this.feature,
        companion: companion ?? this.companion,
      );

  // ---------------------------------------------------------------------------
  // DiceBear URL builder
  // ---------------------------------------------------------------------------

  /// Builds the DiceBear Adventurer SVG URL for this avatar configuration.
  ///
  /// Uses the v7 API with all customisation parameters specified so the
  /// result is fully deterministic (seed is irrelevant when all options are set).
  Uri get svgUri {
    final params = <String, String>{
      'seed': 'flit',
      'eyes[]': eyes.apiValue,
      'eyebrows[]': eyebrows.apiValue,
      'mouth[]': mouth.apiValue,
      'skinColor[]': skinColor.hex,
      'hairColor[]': hairColor.hex,
    };

    // Hair: omit if none, set probability to 0
    if (hair == AvatarHair.none) {
      params['hairProbability'] = '0';
    } else {
      params['hair[]'] = hair.apiValue;
      params['hairProbability'] = '100';
    }

    // Glasses: probability-based visibility
    if (glasses == AvatarGlasses.none) {
      params['glassesProbability'] = '0';
    } else {
      params['glasses[]'] = glasses.apiValue;
      params['glassesProbability'] = '100';
    }

    // Earrings: probability-based visibility
    if (earrings == AvatarEarrings.none) {
      params['earringsProbability'] = '0';
    } else {
      params['earrings[]'] = earrings.apiValue;
      params['earringsProbability'] = '100';
    }

    // Features: probability-based visibility
    if (feature == AvatarFeature.none) {
      params['featuresProbability'] = '0';
    } else {
      params['features[]'] = feature.name;
      params['featuresProbability'] = '100';
    }

    // Transparent background so it blends with app theme
    params['backgroundColor'] = 'transparent';

    return Uri.https('api.dicebear.com', '/7.x/adventurer/svg', params);
  }

  // ---------------------------------------------------------------------------
  // Pricing helpers — returns 0 for free items
  // ---------------------------------------------------------------------------

  /// Coin cost for the given [eyes] variant.
  /// First 13 variants are free.
  static int eyesPrice(AvatarEyes eyes) =>
      eyes.index < 13 ? 0 : 200;

  /// Coin cost for the given [eyebrows] variant.
  /// First 8 variants are free.
  static int eyebrowsPrice(AvatarEyebrows eyebrows) =>
      eyebrows.index < 8 ? 0 : 200;

  /// Coin cost for the given [mouth] variant.
  /// First 15 variants are free.
  static int mouthPrice(AvatarMouth mouth) =>
      mouth.index < 15 ? 0 : 200;

  /// Coin cost for the given [hair] style.
  /// [none] is free. First 5 short and first 5 long are free.
  static int hairPrice(AvatarHair hair) {
    if (hair == AvatarHair.none) return 0;
    // short01-short05 (index 1-5) and long01-long05 (index 20-24) are free
    if (hair.index >= 1 && hair.index <= 5) return 0;
    if (hair.index >= 20 && hair.index <= 24) return 0;
    // Premium short styles: 300 coins
    if (hair.index >= 6 && hair.index <= 19) return 300;
    // Premium long styles: 400 coins
    return 400;
  }

  /// Coin cost for the given [hairColor].
  /// Natural colors (first 9) are free. Fantasy colors cost coins.
  static int hairColorPrice(AvatarHairColor color) =>
      color.index < 9 ? 0 : 400;

  /// Coin cost for the given [glasses] variant.
  /// [none] is free.
  static int glassesPrice(AvatarGlasses glasses) => switch (glasses) {
        AvatarGlasses.none => 0,
        AvatarGlasses.variant01 => 300,
        AvatarGlasses.variant02 => 300,
        AvatarGlasses.variant03 => 500,
        AvatarGlasses.variant04 => 800,
        AvatarGlasses.variant05 => 1000,
      };

  /// Coin cost for the given [earrings] variant.
  /// [none] is free.
  static int earringsPrice(AvatarEarrings earrings) => switch (earrings) {
        AvatarEarrings.none => 0,
        AvatarEarrings.variant01 => 500,
        AvatarEarrings.variant02 => 500,
        AvatarEarrings.variant03 => 800,
        AvatarEarrings.variant04 => 1000,
        AvatarEarrings.variant05 => 1200,
        AvatarEarrings.variant06 => 1500,
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
      eyesPrice(eyes) +
      eyebrowsPrice(eyebrows) +
      mouthPrice(mouth) +
      hairPrice(hair) +
      hairColorPrice(hairColor) +
      glassesPrice(glasses) +
      earringsPrice(earrings) +
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
        'eyes': eyes.name,
        'eyebrows': eyebrows.name,
        'mouth': mouth.name,
        'hair': hair.name,
        'hair_color': hairColor.name,
        'skin_color': skinColor.name,
        'glasses': glasses.name,
        'earrings': earrings.name,
        'feature': feature.name,
        'companion': companion.name,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        eyes: AvatarEyes.values.firstWhere(
          (v) => v.name == json['eyes'],
          orElse: () => AvatarEyes.variant01,
        ),
        eyebrows: AvatarEyebrows.values.firstWhere(
          (v) => v.name == json['eyebrows'],
          orElse: () => AvatarEyebrows.variant01,
        ),
        mouth: AvatarMouth.values.firstWhere(
          (v) => v.name == json['mouth'],
          orElse: () => AvatarMouth.variant01,
        ),
        hair: AvatarHair.values.firstWhere(
          (v) => v.name == json['hair'],
          orElse: () => AvatarHair.short01,
        ),
        hairColor: AvatarHairColor.values.firstWhere(
          (v) => v.name == json['hair_color'],
          orElse: () => AvatarHairColor.brown,
        ),
        skinColor: AvatarSkinColor.values.firstWhere(
          (v) => v.name == json['skin_color'],
          orElse: () => AvatarSkinColor.mediumLight,
        ),
        glasses: AvatarGlasses.values.firstWhere(
          (v) => v.name == json['glasses'],
          orElse: () => AvatarGlasses.none,
        ),
        earrings: AvatarEarrings.values.firstWhere(
          (v) => v.name == json['earrings'],
          orElse: () => AvatarEarrings.none,
        ),
        feature: AvatarFeature.values.firstWhere(
          (v) => v.name == json['feature'],
          orElse: () => AvatarFeature.none,
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
          eyes == other.eyes &&
          eyebrows == other.eyebrows &&
          mouth == other.mouth &&
          hair == other.hair &&
          hairColor == other.hairColor &&
          skinColor == other.skinColor &&
          glasses == other.glasses &&
          earrings == other.earrings &&
          feature == other.feature &&
          companion == other.companion;

  @override
  int get hashCode => Object.hash(
        eyes,
        eyebrows,
        mouth,
        hair,
        hairColor,
        skinColor,
        glasses,
        earrings,
        feature,
        companion,
      );
}
