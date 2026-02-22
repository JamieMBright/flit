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
    required this.label,
    this.price = 0,
    this.colorHex,
  });

  final String id;
  final String label;
  final int price;

  /// Optional color hex for color-swatch categories (hair color, skin color).
  final String? colorHex;

  bool get isFree => price == 0;
  bool get isColorSwatch => colorHex != null;
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

// =============================================================================
// Part list generators — truncated to each style's actual visual variant count.
// Variant counts are derived from the DiceBear part source files.
// =============================================================================

List<_AvatarPart> _eyesParts(int n) => AvatarEyes.values
    .take(n)
    .map(
      (e) => _AvatarPart(
        id: 'eyes_${e.name}',
        label: '#${e.index + 1}',
        price: AvatarConfig.eyesPrice(e),
      ),
    )
    .toList();

List<_AvatarPart> _browsParts(int n) => AvatarEyebrows.values
    .take(n)
    .map(
      (e) => _AvatarPart(
        id: 'eyebrows_${e.name}',
        label: '#${e.index + 1}',
        price: AvatarConfig.eyebrowsPrice(e),
      ),
    )
    .toList();

List<_AvatarPart> _mouthParts(int n) => AvatarMouth.values
    .take(n)
    .map(
      (e) => _AvatarPart(
        id: 'mouth_${e.name}',
        label: '#${e.index + 1}',
        price: AvatarConfig.mouthPrice(e),
      ),
    )
    .toList();

/// Build hair parts with an optional leading 'None'.
/// [nNonNone] is the number of non-none variants the style supports.
List<_AvatarPart> _hairParts(int nNonNone, {bool includeNone = true}) => [
  if (includeNone) const _AvatarPart(id: 'hair_none', label: 'None'),
  ...AvatarHair.values
      .skip(1)
      .take(nNonNone)
      .map(
        (e) => _AvatarPart(
          id: 'hair_${e.name}',
          label: e.label,
          price: AvatarConfig.hairPrice(e),
        ),
      ),
];

List<_AvatarPart> _glassesParts(int nNonNone) => [
  const _AvatarPart(id: 'glasses_none', label: 'None'),
  ...AvatarGlasses.values
      .skip(1)
      .take(nNonNone)
      .map(
        (g) => _AvatarPart(
          id: 'glasses_${g.name}',
          label: '#${g.index}',
          price: AvatarConfig.glassesPrice(g),
        ),
      ),
];

List<_AvatarPart> _earringsParts(int nNonNone) => [
  const _AvatarPart(id: 'earrings_none', label: 'None'),
  ...AvatarEarrings.values
      .skip(1)
      .take(nNonNone)
      .map(
        (e) => _AvatarPart(
          id: 'earrings_${e.name}',
          label: '#${e.index}',
          price: AvatarConfig.earringsPrice(e),
        ),
      ),
];

List<_AvatarPart> _featureParts(int nNonNone, {String label = 'Features'}) => [
  _AvatarPart(id: 'feature_${AvatarFeature.none.name}', label: 'None'),
  ...AvatarFeature.values
      .skip(1)
      .take(nNonNone)
      .map((f) => _AvatarPart(id: 'feature_${f.name}', label: f.label)),
];

List<_AvatarPart> _hairColorParts() => AvatarHairColor.values
    .map(
      (c) => _AvatarPart(
        id: 'hairColor_${c.name}',
        label: c.label,
        price: AvatarConfig.hairColorPrice(c),
        colorHex: c.hex,
      ),
    )
    .toList();

List<_AvatarPart> _skinParts() => AvatarSkinColor.values
    .map(
      (c) => _AvatarPart(
        id: 'skinColor_${c.name}',
        label: c.label,
        colorHex: c.hex,
      ),
    )
    .toList();

/// Generate parts for a style-specific extras category.
/// If [hasNone] is true, index 0 means 'None' (off).
List<_AvatarPart> _extrasParts(String key, int n, {bool hasNone = false}) {
  if (hasNone) {
    return [
      _AvatarPart(id: 'extras_${key}_0', label: 'None'),
      for (var i = 1; i <= n; i++)
        _AvatarPart(id: 'extras_${key}_$i', label: '#$i'),
    ];
  }
  return [
    for (var i = 0; i < n; i++)
      _AvatarPart(id: 'extras_${key}_$i', label: '#${i + 1}'),
  ];
}

// =============================================================================
// Per-style category builder
// =============================================================================

/// Build the category list for the given [style].
///
/// Each style defines its own tree of customisation categories, derived from
/// the actual parts/variant files that exist for that DiceBear collection.
/// The first category is always "Style" (the DiceBear collection picker).
List<_AvatarCategory> _buildCategoriesForStyle(AvatarStyle style) {
  // Style picker — always first.
  final styleCategory = _AvatarCategory(
    label: 'Style',
    icon: Icons.style,
    configKey: 'style',
    parts: AvatarStyle.values
        .map(
          (s) => _AvatarPart(
            id: 'style_${s.name}',
            label: s.label,
            price: AvatarConfig.stylePrice(s),
          ),
        )
        .toList(),
  );

  return [
    styleCategory,
    ...switch (style) {
      // -----------------------------------------------------------------------
      // Adventurer — full per-feature control (26 eyes, 15 brows, 30 mouth,
      //   45 hair, 5 glasses, 6 earrings, 4 features, 14 hair colors, 4 skin)
      // -----------------------------------------------------------------------
      AvatarStyle.adventurer => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(26),
        ),
        _AvatarCategory(
          label: 'Brows',
          icon: Icons.remove,
          configKey: 'eyebrows',
          parts: _browsParts(15),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(30),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(45),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
        _AvatarCategory(
          label: 'Glasses',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(5),
        ),
        _AvatarCategory(
          label: 'Earrings',
          icon: Icons.radio_button_unchecked,
          configKey: 'earrings',
          parts: _earringsParts(6),
        ),
        _AvatarCategory(
          label: 'Features',
          icon: Icons.auto_awesome,
          configKey: 'feature',
          parts: _featureParts(4),
        ),
      ],

      // -----------------------------------------------------------------------
      // Avataaars — 12 eyes, 13 brows, 12 mouth, 33 top/hair
      // -----------------------------------------------------------------------
      AvatarStyle.avataaars => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(12),
        ),
        _AvatarCategory(
          label: 'Brows',
          icon: Icons.remove,
          configKey: 'eyebrows',
          parts: _browsParts(13),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(12),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(33),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
      ],

      // -----------------------------------------------------------------------
      // Big Ears — 32 eyes, 38 mouth, 12 front hair, 6 cheek (brows key)
      // -----------------------------------------------------------------------
      AvatarStyle.bigEars => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(26),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(30),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(12),
        ),
        _AvatarCategory(
          label: 'Cheek',
          icon: Icons.blur_on,
          configKey: 'eyebrows',
          parts: _browsParts(6),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
      ],

      // -----------------------------------------------------------------------
      // Lorelei — 24 eyes, 13 brows, 27 mouth, 48 hair, 5 glasses,
      //   3 earrings, freckles/beard via features
      // -----------------------------------------------------------------------
      AvatarStyle.lorelei => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(24),
        ),
        _AvatarCategory(
          label: 'Brows',
          icon: Icons.remove,
          configKey: 'eyebrows',
          parts: _browsParts(13),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(27),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(46),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
        _AvatarCategory(
          label: 'Glasses',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(5),
        ),
        _AvatarCategory(
          label: 'Earrings',
          icon: Icons.radio_button_unchecked,
          configKey: 'earrings',
          parts: _earringsParts(3),
        ),
        _AvatarCategory(
          label: 'Features',
          icon: Icons.auto_awesome,
          configKey: 'feature',
          parts: _featureParts(4),
        ),
      ],

      // -----------------------------------------------------------------------
      // Micah — 5 eyes, 4 brows, 8 mouth, 27 hair, 2 glasses, 2 earrings,
      //   3 facial hair (feature key)
      // -----------------------------------------------------------------------
      AvatarStyle.micah => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(5),
        ),
        _AvatarCategory(
          label: 'Brows',
          icon: Icons.remove,
          configKey: 'eyebrows',
          parts: _browsParts(4),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(8),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(27),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
        _AvatarCategory(
          label: 'Glasses',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(2),
        ),
        _AvatarCategory(
          label: 'Earrings',
          icon: Icons.radio_button_unchecked,
          configKey: 'earrings',
          parts: _earringsParts(2),
        ),
        _AvatarCategory(
          label: 'Facial Hair',
          icon: Icons.auto_awesome,
          configKey: 'feature',
          parts: _featureParts(3),
        ),
      ],

      // -----------------------------------------------------------------------
      // Pixel Art — 12 eyes, 23 mouth, 45 hair, 14 glasses (enum capped
      //   at 5), 4 accessories (earrings key), beard via features
      // -----------------------------------------------------------------------
      AvatarStyle.pixelArt => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(12),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(23),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(45),
        ),
        _AvatarCategory(
          label: 'Hair Color',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
        _AvatarCategory(
          label: 'Glasses',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(5),
        ),
        _AvatarCategory(
          label: 'Accessories',
          icon: Icons.radio_button_unchecked,
          configKey: 'earrings',
          parts: _earringsParts(4),
        ),
        _AvatarCategory(
          label: 'Features',
          icon: Icons.auto_awesome,
          configKey: 'feature',
          parts: _featureParts(4),
        ),
      ],

      // -----------------------------------------------------------------------
      // Bottts — robot: 13 eyes, 9 mouth, 9 top (brows key), 7 sides
      //   (hair key, no 'none'), body colour (skin key). No hair/skin colours.
      // -----------------------------------------------------------------------
      AvatarStyle.bottts => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(13),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(9),
        ),
        _AvatarCategory(
          label: 'Top',
          icon: Icons.arrow_upward,
          configKey: 'eyebrows',
          parts: _browsParts(9),
        ),
        _AvatarCategory(
          label: 'Sides',
          icon: Icons.pan_tool,
          configKey: 'hair',
          parts: _hairParts(7, includeNone: false),
        ),
        _AvatarCategory(
          label: 'Color',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
      ],

      // -----------------------------------------------------------------------
      // Notionists — line-art style: no skin/hair colours. 5 eyes, 13 brows,
      //   30 lips (mouth key), 63 hair, 11 glasses (enum 6), plus extras for
      //   body (25), gesture (10), nose (20), beard (12+none).
      // -----------------------------------------------------------------------
      AvatarStyle.notionists => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(5),
        ),
        _AvatarCategory(
          label: 'Brows',
          icon: Icons.remove,
          configKey: 'eyebrows',
          parts: _browsParts(13),
        ),
        _AvatarCategory(
          label: 'Lips',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(30),
        ),
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(46),
        ),
        _AvatarCategory(
          label: 'Glasses',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(5),
        ),
        _AvatarCategory(
          label: 'Body',
          icon: Icons.checkroom,
          configKey: 'extras_body',
          parts: _extrasParts('body', 25),
        ),
        _AvatarCategory(
          label: 'Gesture',
          icon: Icons.waving_hand,
          configKey: 'extras_gesture',
          parts: _extrasParts('gesture', 10),
        ),
        _AvatarCategory(
          label: 'Nose',
          icon: Icons.face,
          configKey: 'extras_nose',
          parts: _extrasParts('nose', 20),
        ),
        _AvatarCategory(
          label: 'Beard',
          icon: Icons.auto_awesome,
          configKey: 'extras_beard',
          parts: _extrasParts('beard', 12, hasNone: true),
        ),
      ],

      // -----------------------------------------------------------------------
      // Open Peeps — 48 head (hair key), 30 face expressions (eyes key),
      //   8 accessories (glasses key), 16 facial hair (feature key)
      // -----------------------------------------------------------------------
      AvatarStyle.openPeeps => [
        _AvatarCategory(
          label: 'Hair',
          icon: Icons.content_cut,
          configKey: 'hair',
          parts: _hairParts(46),
        ),
        _AvatarCategory(
          label: 'Expression',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(26),
        ),
        _AvatarCategory(
          label: 'Accessories',
          icon: Icons.remove_red_eye,
          configKey: 'glasses',
          parts: _glassesParts(5),
        ),
        _AvatarCategory(
          label: 'Facial Hair',
          icon: Icons.auto_awesome,
          configKey: 'feature',
          parts: _featureParts(4),
        ),
        _AvatarCategory(
          label: 'Skin',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
      ],

      // -----------------------------------------------------------------------
      // Thumbs — 36 eyes (26 enum), 5 mouth, 5 face (hair key, no none),
      //   body colour (skin key), accent colour (hair colour key)
      // -----------------------------------------------------------------------
      AvatarStyle.thumbs => [
        _AvatarCategory(
          label: 'Eyes',
          icon: Icons.visibility,
          configKey: 'eyes',
          parts: _eyesParts(26),
        ),
        _AvatarCategory(
          label: 'Mouth',
          icon: Icons.mood,
          configKey: 'mouth',
          parts: _mouthParts(5),
        ),
        _AvatarCategory(
          label: 'Face',
          icon: Icons.face,
          configKey: 'hair',
          parts: _hairParts(5, includeNone: false),
        ),
        _AvatarCategory(
          label: 'Color',
          icon: Icons.palette,
          configKey: 'skinColor',
          parts: _skinParts(),
        ),
        _AvatarCategory(
          label: 'Accent',
          icon: Icons.color_lens,
          configKey: 'hairColor',
          parts: _hairColorParts(),
        ),
      ],
    },
  ];
}

// =============================================================================
// Preview config builder
// =============================================================================

/// Creates an [AvatarConfig] with one category option swapped from [base].
///
/// Used to generate mini avatar previews for each selectable part card.
/// Supports both standard enum-based categories and extras-based categories.
AvatarConfig _previewConfig(
  AvatarConfig base,
  String categoryKey,
  String partId,
) {
  // Extras: configKey = 'extras_body', partId = 'extras_body_5'.
  if (categoryKey.startsWith('extras_')) {
    final extrasKey = categoryKey.substring(7);
    final idxStr = partId.substring(partId.lastIndexOf('_') + 1);
    final idx = int.parse(idxStr);
    return base.copyWith(extras: {...base.extras, extrasKey: idx});
  }

  final suffix = partId.substring(partId.indexOf('_') + 1);
  return switch (categoryKey) {
    'style' => base.copyWith(
      style: AvatarStyle.values.firstWhere((v) => v.name == suffix),
    ),
    'eyes' => base.copyWith(
      eyes: AvatarEyes.values.firstWhere((v) => v.name == suffix),
    ),
    'eyebrows' => base.copyWith(
      eyebrows: AvatarEyebrows.values.firstWhere((v) => v.name == suffix),
    ),
    'mouth' => base.copyWith(
      mouth: AvatarMouth.values.firstWhere((v) => v.name == suffix),
    ),
    'hair' => base.copyWith(
      hair: AvatarHair.values.firstWhere((v) => v.name == suffix),
    ),
    'hairColor' => base.copyWith(
      hairColor: AvatarHairColor.values.firstWhere((v) => v.name == suffix),
    ),
    'skinColor' => base.copyWith(
      skinColor: AvatarSkinColor.values.firstWhere((v) => v.name == suffix),
    ),
    'glasses' => base.copyWith(
      glasses: AvatarGlasses.values.firstWhere((v) => v.name == suffix),
    ),
    'earrings' => base.copyWith(
      earrings: AvatarEarrings.values.firstWhere((v) => v.name == suffix),
    ),
    'feature' => base.copyWith(
      feature: AvatarFeature.values.firstWhere((v) => v.name == suffix),
    ),
    _ => base,
  };
}

// =============================================================================
// Avatar Editor Screen
// =============================================================================

/// Full-screen avatar customisation editor using DiceBear Adventurer style.
///
/// Players can browse categories, preview different avatar parts via the
/// live DiceBear preview, purchase locked items with coins, and save.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  /// Current avatar configuration being edited.
  late AvatarConfig _config;

  /// Index of the active category tab.
  int _selectedCategory = 0;

  /// Category list — rebuilt when the active style changes.
  late List<_AvatarCategory> _categories;

  @override
  void initState() {
    super.initState();
    _config = ref.read(accountProvider).avatar;
    _categories = _buildCategoriesForStyle(_config.style);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the currently selected part id for the given [categoryKey].
  String _selectedPartForCategory(String categoryKey) {
    // Extras categories: configKey = 'extras_body' → 'extras_body_<idx>'.
    if (categoryKey.startsWith('extras_')) {
      final extrasKey = categoryKey.substring(7);
      return 'extras_${extrasKey}_${_config.extra(extrasKey)}';
    }
    return switch (categoryKey) {
      'style' => 'style_${_config.style.name}',
      'eyes' => 'eyes_${_config.eyes.name}',
      'eyebrows' => 'eyebrows_${_config.eyebrows.name}',
      'mouth' => 'mouth_${_config.mouth.name}',
      'hair' => 'hair_${_config.hair.name}',
      'hairColor' => 'hairColor_${_config.hairColor.name}',
      'skinColor' => 'skinColor_${_config.skinColor.name}',
      'glasses' => 'glasses_${_config.glasses.name}',
      'earrings' => 'earrings_${_config.earrings.name}',
      'feature' => 'feature_${_config.feature.name}',
      _ => '',
    };
  }

  /// Updates `_config` so that [categoryKey] now points to [partId].
  void _selectPart(String categoryKey, String partId) {
    setState(() {
      // Extras categories: configKey = 'extras_body', partId = 'extras_body_5'.
      if (categoryKey.startsWith('extras_')) {
        final extrasKey = categoryKey.substring(7);
        final idxStr = partId.substring(partId.lastIndexOf('_') + 1);
        final idx = int.parse(idxStr);
        final newExtras = Map<String, int>.from(_config.extras);
        newExtras[extrasKey] = idx;
        _config = _config.copyWith(extras: newExtras);
        return;
      }

      final suffix = partId.substring(partId.indexOf('_') + 1);
      switch (categoryKey) {
        case 'style':
          final newStyle = AvatarStyle.values.firstWhere(
            (v) => v.name == suffix,
          );
          _config = _config.copyWith(style: newStyle);
          // Rebuild categories for the new style. Keep the tab on "Style" (0)
          // because the user just changed it and should see the new selection.
          _categories = _buildCategoriesForStyle(newStyle);
          if (_selectedCategory >= _categories.length) {
            _selectedCategory = 0;
          }
        case 'eyes':
          _config = _config.copyWith(
            eyes: AvatarEyes.values.firstWhere((v) => v.name == suffix),
          );
        case 'eyebrows':
          _config = _config.copyWith(
            eyebrows: AvatarEyebrows.values.firstWhere((v) => v.name == suffix),
          );
        case 'mouth':
          _config = _config.copyWith(
            mouth: AvatarMouth.values.firstWhere((v) => v.name == suffix),
          );
        case 'hair':
          _config = _config.copyWith(
            hair: AvatarHair.values.firstWhere((v) => v.name == suffix),
          );
        case 'hairColor':
          _config = _config.copyWith(
            hairColor: AvatarHairColor.values.firstWhere(
              (v) => v.name == suffix,
            ),
          );
        case 'skinColor':
          _config = _config.copyWith(
            skinColor: AvatarSkinColor.values.firstWhere(
              (v) => v.name == suffix,
            ),
          );
        case 'glasses':
          _config = _config.copyWith(
            glasses: AvatarGlasses.values.firstWhere((v) => v.name == suffix),
          );
        case 'earrings':
          _config = _config.copyWith(
            earrings: AvatarEarrings.values.firstWhere((v) => v.name == suffix),
          );
        case 'feature':
          _config = _config.copyWith(
            feature: AvatarFeature.values.firstWhere((v) => v.name == suffix),
          );
      }
    });
  }

  /// Whether the player can use [part] (either free or already owned).
  bool _canUsePart(_AvatarPart part) =>
      part.isFree ||
      ref.read(accountProvider).ownedAvatarParts.contains(part.id);

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showPurchaseDialog(_AvatarPart part, String categoryKey) {
    final coins = ref.read(currentCoinsProvider);
    final canAfford = coins >= part.price;
    final preview = _previewConfig(_config, categoryKey, part.id);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Text(
          'Unlock ${part.label}?',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar preview showing what this option looks like
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: FlitColors.backgroundLight,
                shape: BoxShape.circle,
                border: Border.all(color: FlitColors.accent, width: 2),
              ),
              child: AvatarWidget(config: preview, size: 100),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: canAfford
                            ? FlitColors.warning
                            : FlitColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${part.price} coins',
                        style: TextStyle(
                          color: canAfford
                              ? FlitColors.textSecondary
                              : FlitColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: FlitColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Play games to earn coins or ',
                                style: TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const ShopScreen(
                                          initialTabIndex: 3,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'buy',
                                    style: TextStyle(
                                      color: FlitColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: FlitColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!canAfford) ...[
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
          ElevatedButton(
            onPressed: canAfford
                ? () {
                    Navigator.of(dialogContext).pop();
                    ref
                        .read(accountProvider.notifier)
                        .purchaseAvatarPart(part.id, part.price);
                    _selectPart(categoryKey, part.id);
                    // Auto-save avatar config so the purchased part isn't
                    // lost if the user navigates away without tapping Save.
                    ref.read(accountProvider.notifier).updateAvatar(_config);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unlocked ${part.label}!'),
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
    ref.read(accountProvider.notifier).updateAvatar(_config);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Avatar saved!'),
        backgroundColor: FlitColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              MaterialPageRoute<void>(
                builder: (_) => const ShopScreen(initialTabIndex: 3),
              ),
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
              currentConfig: _config,
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
      border: Border(bottom: BorderSide(color: FlitColors.cardBorder)),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
            child: AvatarWidget(config: config, size: 160),
          ),
          const SizedBox(height: 8),
          Text(
            config.style.label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? FlitColors.accent.withOpacity(0.2)
                    : FlitColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? FlitColors.accent : FlitColors.cardBorder,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
    required this.currentConfig,
    required this.selectedPartId,
    required this.ownedParts,
    required this.coins,
    required this.onPartTapped,
  });

  final _AvatarCategory category;
  final AvatarConfig currentConfig;
  final String selectedPartId;
  final Set<String> ownedParts;
  final int coins;
  final void Function(_AvatarPart) onPartTapped;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.85,
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
        previewConfig: _previewConfig(
          currentConfig,
          category.configKey,
          part.id,
        ),
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
    required this.previewConfig,
    required this.isSelected,
    required this.isOwned,
    required this.isLocked,
    required this.canAfford,
    required this.onTap,
  });

  final _AvatarPart part;
  final AvatarConfig previewConfig;
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
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Visual preview area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlitColors.backgroundMid,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: part.isColorSwatch
                          ? _ColorSwatch(hex: part.colorHex!)
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final previewSize = constraints.maxWidth.clamp(
                                  32.0,
                                  56.0,
                                );
                                return AvatarWidget(
                                  config: previewConfig,
                                  size: previewSize,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Price label
                if (part.isFree)
                  const Text(
                    'FREE',
                    style: TextStyle(
                      color: FlitColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  )
                else if (isOwned)
                  const Text(
                    'OWNED',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        size: 11,
                        color: canAfford
                            ? FlitColors.warning
                            : FlitColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${part.price}',
                        style: TextStyle(
                          color: canAfford
                              ? FlitColors.warning
                              : FlitColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Selected check badge
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: FlitColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
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
                    size: 24,
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
// Color Swatch
// =============================================================================

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF$hex', radix: 16));
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: FlitColors.cardBorder, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)],
      ),
    );
  }
}

// =============================================================================
// Save Bar (bottom area)
// =============================================================================

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.coins, required this.onSave});

  final int coins;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: FlitColors.backgroundMid,
      border: Border(top: BorderSide(color: FlitColors.cardBorder)),
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
