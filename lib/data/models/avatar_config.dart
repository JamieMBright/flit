/// Base avatar art style. Maps to a DiceBear style collection.
///
/// Adventurer has full per-feature customisation (eyes, mouth, hair, etc.).
/// Other styles also receive explicit per-feature params; DiceBear applies
/// the ones it recognises and uses a fixed seed for everything else.
enum AvatarStyle {
  adventurer('adventurer', 'Adventurer'),
  avataaars('avataaars', 'Avataaars'),
  bigEars('big-ears', 'Big Ears'),
  lorelei('lorelei', 'Lorelei'),
  micah('micah', 'Micah'),
  pixelArt('pixel-art', 'Pixel Art'),
  bottts('bottts', 'Bottts'),
  notionists('notionists', 'Notionists'),
  openPeeps('open-peeps', 'Open Peeps'),
  thumbs('thumbs', 'Thumbs');

  const AvatarStyle(this.slug, this.label);

  /// URL path segment used by the DiceBear API.
  final String slug;

  /// Human-readable label for the avatar editor.
  final String label;
}

/// Avatar eyes variant. Maps to DiceBear Adventurer 'eyes' option.
/// 26 variants available. First 13 are free, rest cost coins.
enum AvatarEyes {
  variant01,
  variant02,
  variant03,
  variant04,
  variant05,
  variant06,
  variant07,
  variant08,
  variant09,
  variant10,
  variant11,
  variant12,
  variant13,
  variant14,
  variant15,
  variant16,
  variant17,
  variant18,
  variant19,
  variant20,
  variant21,
  variant22,
  variant23,
  variant24,
  variant25,
  variant26;

  String get apiValue => name;
}

/// Avatar eyebrows variant. Maps to DiceBear Adventurer 'eyebrows' option.
/// 15 variants available. First 8 are free, rest cost coins.
enum AvatarEyebrows {
  variant01,
  variant02,
  variant03,
  variant04,
  variant05,
  variant06,
  variant07,
  variant08,
  variant09,
  variant10,
  variant11,
  variant12,
  variant13,
  variant14,
  variant15;

  String get apiValue => name;
}

/// Avatar mouth variant. Maps to DiceBear Adventurer 'mouth' option.
/// 30 variants available. First 15 are free, rest cost coins.
enum AvatarMouth {
  variant01,
  variant02,
  variant03,
  variant04,
  variant05,
  variant06,
  variant07,
  variant08,
  variant09,
  variant10,
  variant11,
  variant12,
  variant13,
  variant14,
  variant15,
  variant16,
  variant17,
  variant18,
  variant19,
  variant20,
  variant21,
  variant22,
  variant23,
  variant24,
  variant25,
  variant26,
  variant27,
  variant28,
  variant29,
  variant30;

  String get apiValue => name;
}

/// Avatar hair style. Maps to DiceBear Adventurer 'hair' option.
/// 45 variants (19 short + 26 long) plus none.
/// [none] + first 5 short + first 5 long are free.
enum AvatarHair {
  none,
  short01,
  short02,
  short03,
  short04,
  short05,
  short06,
  short07,
  short08,
  short09,
  short10,
  short11,
  short12,
  short13,
  short14,
  short15,
  short16,
  short17,
  short18,
  short19,
  long01,
  long02,
  long03,
  long04,
  long05,
  long06,
  long07,
  long08,
  long09,
  long10,
  long11,
  long12,
  long13,
  long14,
  long15,
  long16,
  long17,
  long18,
  long19,
  long20,
  long21,
  long22,
  long23,
  long24,
  long25,
  long26;

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
  variant01,
  variant02,
  variant03,
  variant04,
  variant05;

  String get apiValue => name;
}

/// Avatar earrings variant. Maps to DiceBear Adventurer 'earrings' option.
/// [none] is free. All earring styles cost coins.
enum AvatarEarrings {
  none,
  variant01,
  variant02,
  variant03,
  variant04,
  variant05,
  variant06;

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
  pidgey,
  sparrow,
  eagle,
  parrot,
  phoenix,
  dragon,
  charizard,
}

/// Configuration that fully describes a player avatar.
///
/// Each field corresponds to a DiceBear customisation option.
/// The [style] determines which DiceBear collection is used.
/// All per-feature fields (eyes, mouth, hair, etc.) are passed as explicit
/// API params for every style. For [AvatarStyle.adventurer] this gives full
/// 1:1 control. For other styles DiceBear uses params it recognises and
/// ignores the rest; the seed encodes all selected features so changing any
/// option produces a visually distinct avatar.
/// Free defaults are chosen so every new player has a complete look.
class AvatarConfig {
  const AvatarConfig({
    this.style = AvatarStyle.adventurer,
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
    this.extras = const {},
    this.customColors = const {},
    this.equippedCustomColors = const {},
  });

  final AvatarStyle style;
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

  /// Style-specific customisation options stored as key→index pairs.
  ///
  /// Used for categories that only exist for certain styles (e.g. Notionists
  /// 'body' or 'gesture') and have no dedicated enum field.
  final Map<String, int> extras;

  /// Purchased custom colors keyed by feature (for example: `eyesColor`).
  final Map<String, String> customColors;

  /// Currently equipped color overrides keyed by feature.
  final Map<String, String> equippedCustomColors;

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  /// Read a style-specific extra option, defaulting to 0 if not set.
  int extra(String key) => extras[key] ?? 0;

  AvatarConfig copyWith({
    AvatarStyle? style,
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
    Map<String, int>? extras,
    Map<String, String>? customColors,
    Map<String, String>? equippedCustomColors,
  }) => AvatarConfig(
    style: style ?? this.style,
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
    extras: extras ?? this.extras,
    customColors: customColors ?? this.customColors,
    equippedCustomColors: equippedCustomColors ?? this.equippedCustomColors,
  );

  String colorOverride(String key, String fallbackHex) {
    final raw = equippedCustomColors[key];
    if (raw == null) return fallbackHex;
    final cleaned = raw.toLowerCase().replaceAll('#', '');
    if (cleaned.length != 6) return fallbackHex;
    final isHex = RegExp(r'^[0-9a-f]{6}$').hasMatch(cleaned);
    return isHex ? '#$cleaned' : fallbackHex;
  }

  // ---------------------------------------------------------------------------
  // DiceBear URL builder
  // ---------------------------------------------------------------------------

  /// Builds the DiceBear SVG URL for this avatar configuration.
  ///
  /// For [AvatarStyle.adventurer], the seed encodes all options for cache
  /// uniqueness and every feature is pinned via explicit API params.
  /// For other styles a **fixed** seed keeps the base avatar stable (face
  /// shape, etc.) while explicit per-feature params override individual
  /// features where the style supports them. DiceBear silently ignores
  /// params that don't apply to a given style.
  Uri get svgUri {
    final params = <String, String>{'backgroundColor': 'transparent'};

    // All styles: config-derived seed so that changing any feature produces
    // a visually distinct avatar. The explicit per-feature params give 1:1
    // control for Adventurer; for other styles DiceBear uses what it
    // recognises, and the seed variation ensures the base shape also changes
    // when features are swapped.
    params['seed'] =
        'flit-${style.slug}-${eyes.name}-${eyebrows.name}-'
        '${mouth.name}-${hair.name}-${hairColor.name}-${skinColor.name}-'
        '${glasses.name}-${earrings.name}-${feature.name}';

    // Pass explicit per-feature params for every style. For Adventurer each
    // value maps 1:1. For other DiceBear styles the API uses values it
    // recognises and ignores the rest, keeping the base seed-determined look
    // stable while still allowing per-feature control where supported.
    params['eyes[]'] = eyes.apiValue;
    params['eyebrows[]'] = eyebrows.apiValue;
    params['mouth[]'] = mouth.apiValue;
    params['skinColor[]'] = skinColor.hex;
    params['hairColor[]'] = hairColor.hex;

    if (hair == AvatarHair.none) {
      params['hairProbability'] = '0';
    } else {
      params['hair[]'] = hair.apiValue;
      params['hairProbability'] = '100';
    }

    if (glasses == AvatarGlasses.none) {
      params['glassesProbability'] = '0';
    } else {
      params['glasses[]'] = glasses.apiValue;
      params['glassesProbability'] = '100';
    }

    if (earrings == AvatarEarrings.none) {
      params['earringsProbability'] = '0';
    } else {
      params['earrings[]'] = earrings.apiValue;
      params['earringsProbability'] = '100';
    }

    if (feature == AvatarFeature.none) {
      params['featuresProbability'] = '0';
    } else {
      params['features[]'] = feature.name;
      params['featuresProbability'] = '100';
    }

    return Uri.https('api.dicebear.com', '/7.x/${style.slug}/svg', params);
  }

  // ---------------------------------------------------------------------------
  // Pricing helpers — returns 0 for free items
  // ---------------------------------------------------------------------------

  /// Coin cost for the given [style].
  /// Adventurer, Avataaars, and Big Ears are free starter styles.
  static int stylePrice(AvatarStyle style) => switch (style) {
    AvatarStyle.adventurer => 0,
    AvatarStyle.avataaars => 0,
    AvatarStyle.bigEars => 0,
    AvatarStyle.lorelei => 500,
    AvatarStyle.micah => 500,
    AvatarStyle.pixelArt => 500,
    AvatarStyle.bottts => 800,
    AvatarStyle.notionists => 800,
    AvatarStyle.openPeeps => 1000,
    AvatarStyle.thumbs => 1000,
  };

  /// Coin cost for the given [eyes] variant.
  /// First 13 variants are free.
  static int eyesPrice(AvatarEyes eyes) => eyes.index < 13 ? 0 : 200;

  /// Coin cost for the given [eyebrows] variant.
  /// First 8 variants are free.
  static int eyebrowsPrice(AvatarEyebrows eyebrows) =>
      eyebrows.index < 8 ? 0 : 200;

  /// Coin cost for the given [mouth] variant.
  /// First 15 variants are free.
  static int mouthPrice(AvatarMouth mouth) => mouth.index < 15 ? 0 : 200;

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
  static int hairColorPrice(AvatarHairColor color) => color.index < 9 ? 0 : 400;

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
    AvatarCompanion.pidgey => 500,
    AvatarCompanion.sparrow => 2000,
    AvatarCompanion.eagle => 5000,
    AvatarCompanion.parrot => 8000,
    AvatarCompanion.phoenix => 15000,
    AvatarCompanion.dragon => 30000,
    AvatarCompanion.charizard => 75000,
  };

  /// Total coin cost of every non-free item in this configuration.
  int get totalCost =>
      stylePrice(style) +
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
    'style': style.name,
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
    if (extras.isNotEmpty) 'extras': extras,
    if (customColors.isNotEmpty) 'custom_colors': customColors,
    if (equippedCustomColors.isNotEmpty)
      'equipped_custom_colors': equippedCustomColors,
  };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
    style: AvatarStyle.values.firstWhere(
      (v) => v.name == json['style'],
      orElse: () => AvatarStyle.adventurer,
    ),
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
    extras:
        (json['extras'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ??
        const {},
    customColors:
        (json['custom_colors'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
    equippedCustomColors:
        (json['equipped_custom_colors'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ) ??
        const {},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarConfig &&
          style == other.style &&
          eyes == other.eyes &&
          eyebrows == other.eyebrows &&
          mouth == other.mouth &&
          hair == other.hair &&
          hairColor == other.hairColor &&
          skinColor == other.skinColor &&
          glasses == other.glasses &&
          earrings == other.earrings &&
          feature == other.feature &&
          companion == other.companion &&
          _mapEquals(extras, other.extras) &&
          _stringMapEquals(customColors, other.customColors) &&
          _stringMapEquals(equippedCustomColors, other.equippedCustomColors);

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _stringMapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    style,
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
    Object.hashAll(extras.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(customColors.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(
      equippedCustomColors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
