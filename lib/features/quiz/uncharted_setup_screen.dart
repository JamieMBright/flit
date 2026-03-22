import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/region.dart';
import '../../game/quiz/uncharted_progress.dart';
import '../../game/quiz/uncharted_session.dart';
import '../guide/gameplay_guide_screen.dart';
import 'uncharted_game_screen.dart';

/// Setup screen for the Uncharted game mode.
///
/// Lets the player pick a region and choose between Countries or Capitals
/// mode before starting the game.
class UnchartedSetupScreen extends ConsumerStatefulWidget {
  const UnchartedSetupScreen({super.key});

  @override
  ConsumerState<UnchartedSetupScreen> createState() =>
      _UnchartedSetupScreenState();
}

class _UnchartedSetupScreenState extends ConsumerState<UnchartedSetupScreen> {
  GameRegion _selectedRegion = GameRegion.world;
  UnchartedMode _selectedMode = UnchartedMode.countries;
  bool _showLabels = false;

  static const _regions = [
    GameRegion.world,
    GameRegion.europe,
    GameRegion.africa,
    GameRegion.asia,
    GameRegion.latinAmerica,
    GameRegion.oceania,
    GameRegion.caribbean,
    GameRegion.usStates,
    GameRegion.ukCounties,
    GameRegion.ireland,
    GameRegion.canadianProvinces,
    GameRegion.disputedTerritories,
  ];

  static const _regionIcons = <GameRegion, IconData>{
    GameRegion.world: Icons.public,
    GameRegion.europe: Icons.castle,
    GameRegion.africa: Icons.terrain,
    GameRegion.asia: Icons.temple_buddhist,
    GameRegion.latinAmerica: Icons.festival,
    GameRegion.oceania: Icons.beach_access,
    GameRegion.caribbean: Icons.sailing,
    GameRegion.usStates: Icons.flag,
    GameRegion.ukCounties: Icons.account_balance,
    GameRegion.ireland: Icons.grass,
    GameRegion.canadianProvinces: Icons.landscape,
    GameRegion.disputedTerritories: Icons.warning_amber,
  };

  void _startGame() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnchartedGameScreen(
          region: _selectedRegion,
          mode: _selectedMode,
          showLabels: _showLabels,
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
          'Uncharted',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to Play',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GameplayGuideScreen(
                  initialTab: GuideTab.uncharted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode toggle.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Countries',
                      subtitle: 'Name the countries',
                      icon: Icons.map_outlined,
                      selected: _selectedMode == UnchartedMode.countries,
                      onTap: () => setState(
                        () => _selectedMode = UnchartedMode.countries,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeChip(
                      label: 'Capitals',
                      subtitle: 'Name the capitals',
                      icon: Icons.location_city,
                      selected: _selectedMode == UnchartedMode.capitals,
                      onTap: () => setState(
                        () => _selectedMode = UnchartedMode.capitals,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Labels toggle.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: () => setState(() => _showLabels = !_showLabels),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _showLabels
                        ? FlitColors.gold.withValues(alpha: 0.12)
                        : FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showLabels
                          ? FlitColors.gold.withValues(alpha: 0.5)
                          : FlitColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showLabels
                            ? Icons.label_rounded
                            : Icons.label_off_rounded,
                        color: _showLabels
                            ? FlitColors.gold
                            : FlitColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Show Country Names',
                              style: TextStyle(
                                color: _showLabels
                                    ? FlitColors.gold
                                    : FlitColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Labels visible — score halved',
                              style: TextStyle(
                                color: FlitColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showLabels
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: _showLabels
                            ? FlitColors.gold
                            : FlitColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Section header.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SELECT REGION',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            // Region list.
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _regions.length,
                itemBuilder: (context, index) {
                  final region = _regions[index];
                  final areaCount = RegionalData.getAreas(region).length;
                  final isSelected = region == _selectedRegion;
                  final key = '${region.name}_${_selectedMode.name}';
                  final progress =
                      ref.watch(accountProvider).unchartedProgress[key];
                  return _RegionCard(
                    region: region,
                    areaCount: areaCount,
                    icon: _regionIcons[region] ?? Icons.public,
                    selected: isSelected,
                    progress: progress,
                    onTap: () => setState(() => _selectedRegion = region),
                  );
                },
              ),
            ),
            // Fixed bottom start button.
            Container(
              decoration: BoxDecoration(
                color: FlitColors.backgroundDark,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: FlitColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  child: const Text('START'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? FlitColors.accent.withOpacity(0.15)
              : FlitColors.backgroundMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FlitColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? FlitColors.accent : FlitColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? FlitColors.accent : FlitColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: FlitColors.textSecondary.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.areaCount,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.progress,
  });

  final GameRegion region;
  final int areaCount;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final UnchartedProgress? progress;

  @override
  Widget build(BuildContext context) {
    final hasPlayed = progress != null && progress!.hasPlayed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? FlitColors.accent.withOpacity(0.1)
                : FlitColors.backgroundMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FlitColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? FlitColors.accent : FlitColors.textSecondary,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region.displayName,
                      style: TextStyle(
                        color: selected
                            ? FlitColors.accent
                            : FlitColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$areaCount areas',
                      style: TextStyle(
                        color: FlitColors.textSecondary.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    if (hasPlayed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: FlitColors.gold, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              '${progress!.bestScore}',
                              style: const TextStyle(
                                color: FlitColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.timer,
                                color: FlitColors.accent, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              progress!.bestTimeFormatted,
                              style: const TextStyle(
                                color: FlitColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              progress!.grade,
                              style: TextStyle(
                                color: _gradeColor(progress!.grade),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: FlitColors.accent,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':
        return FlitColors.gold;
      case 'A':
        return FlitColors.success;
      case 'B':
        return FlitColors.accent;
      case 'C':
        return FlitColors.textSecondary;
      default:
        return FlitColors.error;
    }
  }
}
