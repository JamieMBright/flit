import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../game/clues/clue_types.dart';
import '../../game/triangulation/triangulation_session.dart';
import '../../game/triangulation/triangulation_target.dart';
import 'triangulation_game_screen.dart';

/// Free-play setup for Triangulation: pick clue visuals, marker labels,
/// rounds, marker count, and difficulty — then play with a random seed.
class TriangulationSetupScreen extends StatefulWidget {
  const TriangulationSetupScreen({super.key});

  @override
  State<TriangulationSetupScreen> createState() =>
      _TriangulationSetupScreenState();
}

class _ClueChipMeta {
  const _ClueChipMeta(this.type, this.name, this.icon);
  final ClueType type;
  final String name;
  final IconData icon;
}

class _LabelChipMeta {
  const _LabelChipMeta(this.label, this.name, this.icon);
  final TriLabel label;
  final String name;
  final IconData icon;
}

const List<_ClueChipMeta> _clueChips = [
  _ClueChipMeta(ClueType.flag, 'Flags', Icons.flag),
  _ClueChipMeta(ClueType.outline, 'Outlines', Icons.crop_square),
  _ClueChipMeta(ClueType.borders, 'Borders', Icons.border_all),
  _ClueChipMeta(ClueType.capital, 'Capitals', Icons.location_city),
];

const List<_LabelChipMeta> _labelChips = [
  _LabelChipMeta(TriLabel.country, 'Country name', Icons.public),
  _LabelChipMeta(TriLabel.capital, 'Capital', Icons.location_city),
  _LabelChipMeta(TriLabel.leader, 'World leader', Icons.person),
  _LabelChipMeta(TriLabel.language, 'Language', Icons.translate),
];

const List<int> _roundOptions = [1, 3, 5, 10];
const List<int> _markerOptions = [3, 4, 5, 6];

class _TriangulationSetupScreenState extends State<TriangulationSetupScreen> {
  final Set<ClueType> _clueTypes = {ClueType.flag};
  final Set<TriLabel> _labelTypes = {TriLabel.capital};
  TriTargetType _targetType = TriTargetType.capital;
  int _rounds = 3;
  int _markers = 5;

  void _toggleClue(ClueType type) {
    setState(() {
      if (_clueTypes.contains(type)) {
        // Keep at least one visual clue so markers aren't blank.
        if (_clueTypes.length > 1) _clueTypes.remove(type);
      } else {
        _clueTypes.add(type);
      }
    });
  }

  void _toggleLabel(TriLabel label) {
    setState(() {
      // Labels can all be off — flags-with-no-labels is a legit hard mode.
      if (!_labelTypes.remove(label)) _labelTypes.add(label);
    });
  }

  void _start() {
    final config = TriangulationConfig(
      seed: Random().nextInt(1 << 31),
      rounds: _rounds,
      markerCount: _markers,
      clueTypes: Set.unmodifiable(_clueTypes),
      labelTypes: Set.unmodifiable(_labelTypes),
      difficulty: GameSettings.instance.difficulty,
      targetType: _targetType,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TriangulationGameScreen(config: config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Recon',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: MenuContentWrapper(
          child: Column(
            children: [
              ListenableBuilder(
                listenable: GameSettings.instance,
                builder: (context, _) => _DifficultyBar(
                  difficulty: GameSettings.instance.difficulty,
                  onChanged: (d) => GameSettings.instance.difficulty = d,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _sectionLabel('TARGET', Icons.my_location),
                      const SizedBox(height: 10),
                      _buildTargetSelector(),
                      const SizedBox(height: 20),
                      _sectionLabel('ROUNDS', Icons.repeat),
                      const SizedBox(height: 10),
                      _numberSelector(
                        _roundOptions,
                        _rounds,
                        (v) => setState(() => _rounds = v),
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('COMPASS MARKERS', Icons.explore),
                      const SizedBox(height: 10),
                      _numberSelector(
                        _markerOptions,
                        _markers,
                        (v) => setState(() => _markers = v),
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('CLUE TYPES', Icons.tune),
                      const SizedBox(height: 10),
                      _chipWrap([
                        for (final meta in _clueChips)
                          _buildChip(
                            name: meta.name,
                            icon: meta.icon,
                            selected: _clueTypes.contains(meta.type),
                            onTap: () => _toggleClue(meta.type),
                          ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionLabel('MARKER LABELS', Icons.label_outline),
                      const SizedBox(height: 10),
                      _chipWrap([
                        for (final meta in _labelChips)
                          _buildChip(
                            name: meta.name,
                            icon: meta.icon,
                            selected: _labelTypes.contains(meta.label),
                            onTap: () => _toggleLabel(meta.label),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        'Stack as many clue types and labels as you like — '
                        'every marker box shows them all. No labels at all '
                        'is the expert run.',
                        style: TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlitColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore,
                color: FlitColors.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'RECON',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A hidden capital. A compass of bearings.\n'
              'Cross-reference the arrows and close in.',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _sectionLabel(String label, IconData icon) => Row(
        children: [
          Icon(icon, color: FlitColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  Widget _buildTargetSelector() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: TriTargetType.values.map((type) {
            final isSelected = _targetType == type;
            return GestureDetector(
              onTap: () => setState(() => _targetType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FlitColors.accent.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isSelected ? FlitColors.accent : FlitColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type == TriTargetType.capital
                          ? Icons.location_city_rounded
                          : Icons.public,
                      size: 16,
                      color:
                          isSelected ? FlitColors.accent : FlitColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? FlitColors.accent
                            : FlitColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _numberSelector(
    List<int> options,
    int selected,
    ValueChanged<int> onChanged,
  ) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: options.map((value) {
            final isSelected = selected == value;
            return GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FlitColors.accent.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isSelected ? FlitColors.accent : FlitColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color:
                        isSelected ? FlitColors.accent : FlitColors.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _chipWrap(List<Widget> chips) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );

  Widget _buildChip({
    required String name,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? FlitColors.accent.withOpacity(0.2)
                : FlitColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? FlitColors.accent : FlitColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? FlitColors.accent : FlitColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  color:
                      selected ? FlitColors.accent : FlitColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Text(
              'START RECON (×$_rounds)',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );
}

// Same difficulty bar as free_flight_setup_screen / region_select_screen.
class _DifficultyBar extends StatelessWidget {
  const _DifficultyBar({required this.difficulty, required this.onChanged});

  final GameDifficulty difficulty;
  final ValueChanged<GameDifficulty> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        color: FlitColors.backgroundMid,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.tune, color: FlitColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Difficulty',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            ...GameDifficulty.values.map((d) {
              final isActive = d == difficulty;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onChanged(d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _color(d).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? _color(d) : FlitColors.cardBorder,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      d.displayName.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? _color(d) : FlitColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );

  static Color _color(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:
        return FlitColors.success;
      case GameDifficulty.normal:
        return FlitColors.accent;
      case GameDifficulty.hard:
        return FlitColors.gold;
    }
  }
}
