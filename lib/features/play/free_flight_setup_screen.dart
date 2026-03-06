import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/region.dart';
import 'play_screen.dart';

// =============================================================================
// Clue type metadata (shared with practice_screen — consider extracting later)
// =============================================================================

class _ClueTypeMeta {
  const _ClueTypeMeta({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });

  final ClueType type;
  final String name;
  final String description;
  final IconData icon;
}

const List<_ClueTypeMeta> _clueTypeMetas = [
  _ClueTypeMeta(
    type: ClueType.flag,
    name: 'Flag',
    description: 'Identify countries by their national flag',
    icon: Icons.flag,
  ),
  _ClueTypeMeta(
    type: ClueType.outline,
    name: 'Outline',
    description: 'Recognise the country silhouette shape',
    icon: Icons.crop_square,
  ),
  _ClueTypeMeta(
    type: ClueType.borders,
    name: 'Borders',
    description: 'Guess from neighbouring countries',
    icon: Icons.border_all,
  ),
  _ClueTypeMeta(
    type: ClueType.capital,
    name: 'Capital',
    description: 'Name the country from its capital city',
    icon: Icons.location_city,
  ),
  _ClueTypeMeta(
    type: ClueType.stats,
    name: 'Stats',
    description: 'Deduce from population, language, and other facts',
    icon: Icons.bar_chart,
  ),
];

/// Round count options for free flight.
const List<({int value, String label})> _roundOptions = [
  (value: 1, label: '1'),
  (value: 5, label: '5'),
  (value: 10, label: '10'),
  (value: 0, label: '\u221E'), // ∞ = endless (0 means no limit)
];

// =============================================================================
// FreeFlightSetupScreen
// =============================================================================

/// Setup screen for Free Flight mode — configure clue types, round count,
/// and difficulty before launching. No fuel, no points, no pressure.
class FreeFlightSetupScreen extends ConsumerStatefulWidget {
  const FreeFlightSetupScreen({super.key, required this.region});

  final GameRegion region;

  @override
  ConsumerState<FreeFlightSetupScreen> createState() =>
      _FreeFlightSetupScreenState();
}

class _FreeFlightSetupScreenState extends ConsumerState<FreeFlightSetupScreen> {
  static const _worldClueTypes = [
    ClueType.flag,
    ClueType.outline,
    ClueType.borders,
    ClueType.capital,
    ClueType.stats,
  ];

  final Map<ClueType, bool> _enabledClues = {
    for (final type in _worldClueTypes) type: true,
  };

  /// Selected round count (0 = endless).
  int _selectedRounds = 5;

  int get _enabledCount => _enabledClues.values.where((v) => v).length;

  bool _isLastEnabled(ClueType type) =>
      _enabledCount == 1 && (_enabledClues[type] ?? false);

  void _toggleClue(ClueType type, bool value) {
    if (!value && _isLastEnabled(type)) return;
    setState(() => _enabledClues[type] = value);
  }

  void _startFreeFlight() {
    final planeId = ref.read(equippedPlaneIdProvider);
    final plane = CosmeticCatalog.getById(planeId);
    final account = ref.read(accountProvider);
    final companion = account.avatar.companion;
    final fuelBoost = ref.read(accountProvider.notifier).fuelBoostMultiplier;
    final license = account.license;
    final contrailId = ref.read(accountProvider).equippedContrailId;
    final contrail = CosmeticCatalog.getById(contrailId);
    final contrailPrimary = contrail?.colorScheme?['primary'];
    final contrailSecondary = contrail?.colorScheme?['secondary'];
    final enabledClueTypeNames = _enabledClues.entries
        .where((e) => e.value)
        .map((e) => e.key.name)
        .toSet();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          region: widget.region,
          totalRounds: _selectedRounds == 0 ? 1 : _selectedRounds,
          planeColorScheme: plane?.colorScheme,
          planeWingSpan: plane?.wingSpan,
          equippedPlaneId: planeId,
          companionType: companion,
          fuelBoostMultiplier: fuelBoost,
          clueChance: license.clueChance,
          preferredClueType: license.preferredClueType,
          enabledClueTypes: enabledClueTypeNames,
          enableFuel: false,
          isFreeFlight: true,
          planeHandling: plane?.handling ?? 1.0,
          planeSpeed: plane?.speed ?? 1.0,
          planeFuelEfficiency: plane?.fuelEfficiency ?? 1.0,
          contrailPrimaryColor:
              contrailPrimary != null ? Color(contrailPrimary) : null,
          contrailSecondaryColor:
              contrailSecondary != null ? Color(contrailSecondary) : null,
        ),
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
          'Free Flight',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Difficulty selector bar
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
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // Round count
                    _buildSectionLabel('ROUNDS', Icons.repeat),
                    const SizedBox(height: 10),
                    _buildRoundSelector(),
                    const SizedBox(height: 20),

                    // Clue types
                    _buildSectionLabel('CLUE TYPES', Icons.tune),
                    const SizedBox(height: 10),
                    ..._buildClueToggleCards(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom bar
            _buildBottomBar(),
          ],
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
                color: FlitColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flight,
                color: FlitColors.success,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'FREE FLIGHT',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore at your own pace\nNo fuel, no points, no pressure',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(Icons.local_gas_station, 'No fuel'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.skip_next, 'Skip clues'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.attach_money, 'Free'),
              ],
            ),
          ],
        ),
      );

  Widget _buildInfoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: FlitColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FlitColors.success.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FlitColors.success, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: FlitColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildRoundSelector() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _roundOptions.map((opt) {
            final isSelected = _selectedRounds == opt.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedRounds = opt.value),
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
                  opt.label,
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

  Widget _buildSectionLabel(String label, IconData icon) => Row(
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

  List<Widget> _buildClueToggleCards() {
    final cards = <Widget>[];
    for (final meta in _clueTypeMetas) {
      final enabled = _enabledClues[meta.type] ?? true;
      final isLast = _isLastEnabled(meta.type);
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ClueToggleCard(
            meta: meta,
            enabled: enabled,
            isLastEnabled: isLast,
            onChanged: (value) => _toggleClue(meta.type, value),
          ),
        ),
      );
    }
    return cards;
  }

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
            onPressed: _startFreeFlight,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.success,
              foregroundColor: FlitColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flight_takeoff, size: 22),
                const SizedBox(width: 10),
                Text(
                  _selectedRounds == 0
                      ? 'START FREE FLIGHT'
                      : 'START FREE FLIGHT (\u00D7${_selectedRounds})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// =============================================================================
// Clue Toggle Card (same as practice_screen)
// =============================================================================

class _ClueToggleCard extends StatelessWidget {
  const _ClueToggleCard({
    required this.meta,
    required this.enabled,
    required this.isLastEnabled,
    required this.onChanged,
  });

  final _ClueTypeMeta meta;
  final bool enabled;
  final bool isLastEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          if (enabled && isLastEnabled) return;
          onChanged(!enabled);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled
                ? FlitColors.cardBackground
                : FlitColors.backgroundMid.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? FlitColors.accent.withOpacity(0.5)
                  : FlitColors.cardBorder.withOpacity(0.4),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? FlitColors.accent.withOpacity(0.15)
                      : FlitColors.backgroundDark.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  meta.icon,
                  color: enabled ? FlitColors.accent : FlitColors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.name,
                          style: TextStyle(
                            color: enabled
                                ? FlitColors.textPrimary
                                : FlitColors.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isLastEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REQUIRED',
                              style: TextStyle(
                                color: FlitColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.description,
                      style: TextStyle(
                        color: enabled
                            ? FlitColors.textSecondary
                            : FlitColors.textMuted.withOpacity(0.7),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: enabled,
                onChanged: (value) {
                  if (!value && isLastEnabled) return;
                  onChanged(value);
                },
                activeColor: FlitColors.accent,
                activeTrackColor: FlitColors.accent.withOpacity(0.35),
                inactiveThumbColor: FlitColors.textMuted,
                inactiveTrackColor: FlitColors.backgroundDark,
              ),
            ],
          ),
        ),
      );
}

// =============================================================================
// Difficulty Bar (same as region_select_screen)
// =============================================================================

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
