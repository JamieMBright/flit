import 'package:flutter/material.dart';

import '../services/audio_manager.dart';
import '../services/game_settings.dart';
import '../theme/flit_colors.dart';

/// Reusable settings bottom-sheet content.
///
/// Used from both the profile screen and the in-game HUD so that all
/// settings are accessible from either place without code duplication.
///
/// Call [showSettingsSheet] to present it as a modal bottom sheet.
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: FlitColors.cardBackground,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) =>
          _SettingsSheetContent(scrollController: scrollController),
    ),
  );
}

class _SettingsSheetContent extends StatefulWidget {
  const _SettingsSheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_SettingsSheetContent> createState() => _SettingsSheetContentState();
}

class _SettingsSheetContentState extends State<_SettingsSheetContent> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = AudioManager.instance.enabled;
  bool _hapticEnabled = true;

  @override
  Widget build(BuildContext context) => ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Title
          const Center(
            child: Text(
              'Settings',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Audio ──────────────────────────────────────────
          const _SectionHeader(title: 'Audio'),
          _SettingsToggle(
            label: 'Sound',
            icon: Icons.volume_up_outlined,
            value: _soundEnabled,
            onChanged: (value) {
              AudioManager.instance.enabled = value;
              setState(() => _soundEnabled = value);
            },
          ),
          const Divider(color: FlitColors.cardBorder, height: 1),
          _SettingsToggle(
            label: 'Notifications',
            icon: Icons.notifications_outlined,
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),
          const Divider(color: FlitColors.cardBorder, height: 1),
          _SettingsToggle(
            label: 'Haptic Feedback',
            icon: Icons.vibration,
            value: _hapticEnabled,
            onChanged: (value) => setState(() => _hapticEnabled = value),
          ),
          const SizedBox(height: 20),

          // ── Controls ───────────────────────────────────────
          const _SectionHeader(title: 'Controls'),
          _SettingsToggle(
            label: 'Invert Controls',
            icon: Icons.swap_horiz,
            value: GameSettings.instance.invertControls,
            onChanged: (value) {
              GameSettings.instance.invertControls = value;
              setState(() {});
            },
          ),
          const Divider(color: FlitColors.cardBorder, height: 1),
          _SettingsSlider(
            label: 'Turn Sensitivity',
            icon: Icons.speed,
            value: GameSettings.instance.turnSensitivity,
            min: 0.2,
            max: 1.5,
            valueLabel: GameSettings.instance.sensitivityLabel,
            onChanged: (value) {
              GameSettings.instance.turnSensitivity = value;
              setState(() {});
            },
          ),
          const SizedBox(height: 20),

          // ── Display ────────────────────────────────────────
          const _SectionHeader(title: 'Display'),
          _SettingsToggle(
            label: 'Night / Day Cycle',
            icon: Icons.nightlight_outlined,
            value: GameSettings.instance.enableNight,
            onChanged: (value) {
              GameSettings.instance.enableNight = value;
              setState(() {});
            },
          ),
          const Divider(color: FlitColors.cardBorder, height: 1),
          _SettingsToggle(
            label: 'English Labels',
            icon: Icons.translate,
            value: GameSettings.instance.englishLabels,
            onChanged: (value) {
              GameSettings.instance.englishLabels = value;
              setState(() {});
            },
          ),
          const Divider(color: FlitColors.cardBorder, height: 1),
          _MapStyleSelector(
            value: GameSettings.instance.mapStyle,
            onChanged: (value) {
              GameSettings.instance.mapStyle = value;
              setState(() {});
            },
          ),
          const SizedBox(height: 20),

          // ── Gameplay ───────────────────────────────────────
          const _SectionHeader(title: 'Gameplay'),
          _DifficultySelector(
            value: GameSettings.instance.difficulty,
            onChanged: (value) {
              GameSettings.instance.difficulty = value;
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
        ],
      );
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Settings toggle row
// ---------------------------------------------------------------------------

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: onChanged != null
                  ? FlitColors.textSecondary
                  : FlitColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onChanged != null
                      ? FlitColors.textPrimary
                      : FlitColors.textMuted,
                  fontSize: 16,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: FlitColors.accent,
              inactiveTrackColor: FlitColors.backgroundMid,
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Settings slider row
// ---------------------------------------------------------------------------

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: FlitColors.textSecondary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: FlitColors.accent,
                inactiveTrackColor: FlitColors.backgroundMid,
                thumbColor: FlitColors.accent,
                overlayColor: FlitColors.accent.withOpacity(0.15),
                trackHeight: 4,
              ),
              child: Slider(
                  value: value, min: min, max: max, onChanged: onChanged),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Difficulty selector (3-way toggle: Easy / Normal / Hard)
// ---------------------------------------------------------------------------

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.value, required this.onChanged});

  final GameDifficulty value;
  final ValueChanged<GameDifficulty> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: FlitColors.textSecondary, size: 22),
                SizedBox(width: 12),
                Text(
                  'Difficulty',
                  style: TextStyle(color: FlitColors.textPrimary, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle(value),
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: GameDifficulty.values.map((d) {
                final isActive = d == value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onChanged(d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _activeColor(d).withOpacity(0.2)
                              : FlitColors.backgroundMid,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? _activeColor(d)
                                : FlitColors.cardBorder,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _label(d),
                            style: TextStyle(
                              color: isActive
                                  ? _activeColor(d)
                                  : FlitColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  static String _label(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:
        return 'EASY';
      case GameDifficulty.normal:
        return 'NORMAL';
      case GameDifficulty.hard:
        return 'HARD';
    }
  }

  static String _subtitle(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:
        return 'Well-known countries, extra hints, skip option';
      case GameDifficulty.normal:
        return 'Balanced countries and standard hints';
      case GameDifficulty.hard:
        return 'Obscure countries, fewer hints';
    }
  }

  static Color _activeColor(GameDifficulty d) {
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

// ---------------------------------------------------------------------------
// Map style selector (4-way toggle: Standard / Dark / Voyager / Topo)
// ---------------------------------------------------------------------------

class _MapStyleSelector extends StatelessWidget {
  const _MapStyleSelector({required this.value, required this.onChanged});

  final MapStyle value;
  final ValueChanged<MapStyle> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.map_outlined,
                    color: FlitColors.textSecondary, size: 22),
                SizedBox(width: 12),
                Text(
                  'Map Style',
                  style: TextStyle(color: FlitColors.textPrimary, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle(value),
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: MapStyle.values.map((s) {
                final isActive = s == value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => onChanged(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? FlitColors.accent.withOpacity(0.2)
                              : FlitColors.backgroundMid,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? FlitColors.accent
                                : FlitColors.cardBorder,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _icon(s),
                                size: 18,
                                color: isActive
                                    ? FlitColors.accent
                                    : FlitColors.textMuted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _label(s),
                                style: TextStyle(
                                  color: isActive
                                      ? FlitColors.accent
                                      : FlitColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  static String _label(MapStyle s) {
    switch (s) {
      case MapStyle.standard:
        return 'STD';
      case MapStyle.dark:
        return 'DARK';
      case MapStyle.voyager:
        return 'COLOR';
      case MapStyle.topo:
        return 'TOPO';
    }
  }

  static String _subtitle(MapStyle s) {
    switch (s) {
      case MapStyle.standard:
        return 'Classic OpenStreetMap — light, detailed';
      case MapStyle.dark:
        return 'Dark mode — subtle labels, easy on eyes';
      case MapStyle.voyager:
        return 'Colorful modern style — easy to read';
      case MapStyle.topo:
        return 'Topographic — elevation contour lines';
    }
  }

  static IconData _icon(MapStyle s) {
    switch (s) {
      case MapStyle.standard:
        return Icons.wb_sunny_outlined;
      case MapStyle.dark:
        return Icons.dark_mode_outlined;
      case MapStyle.voyager:
        return Icons.palette_outlined;
      case MapStyle.topo:
        return Icons.terrain_outlined;
    }
  }
}
