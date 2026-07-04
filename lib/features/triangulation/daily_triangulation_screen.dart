import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/models/daily_result.dart';
import '../../data/models/economy_config.dart';
import '../../data/services/economy_config_service.dart';
import '../../game/clues/clue_types.dart';
import '../../game/data/country_difficulty.dart';
import '../../game/triangulation/daily_triangulation.dart';
import '../../game/triangulation/triangulation_target.dart';
import 'triangulation_game_screen.dart';

/// Lobby for the Daily Triangulation: shows today's theme and rules, and
/// either the play button or (once played) the result with share.
class DailyTriangulationScreen extends StatefulWidget {
  const DailyTriangulationScreen({super.key});

  @override
  State<DailyTriangulationScreen> createState() =>
      _DailyTriangulationScreenState();
}

class _DailyTriangulationScreenState extends State<DailyTriangulationScreen> {
  late final DailyTriangulation _daily;
  String? _completedShareText;
  int? _completedScore;
  bool _loading = true;
  EconomyConfig? _economyConfig;

  @override
  void initState() {
    super.initState();
    _daily = DailyTriangulation.forToday();
    _loadResult();
    _loadEconomyConfig();
  }

  Future<void> _loadEconomyConfig() async {
    try {
      final config = await EconomyConfigService.instance.getConfig();
      if (!mounted) return;
      setState(() => _economyConfig = config);
    } catch (_) {
      // Defaults apply — the reward pill just shows the default value.
    }
  }

  /// Today's completion reward (base x promo multiplier).
  int get _coinReward {
    final config = _economyConfig ?? EconomyConfig.defaults();
    return (config.earnings.dailyTriangulationBaseReward *
            config.earningsMultiplier)
        .round();
  }

  Future<void> _loadResult() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _completedShareText =
          prefs.getString('daily_triangulation_${_daily.dateKey}');
      _completedScore =
          prefs.getInt('daily_triangulation_score_${_daily.dateKey}');
      _loading = false;
    });
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TriangulationGameScreen(
          config: _daily.toConfig(),
          daily: _daily,
          coinReward: _coinReward,
        ),
      ),
    );
    // Refresh: the game screen records the result on completion.
    await _loadResult();
  }

  @override
  Widget build(BuildContext context) {
    final played = _completedShareText != null;
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Daily Triangulation',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: MenuContentWrapper(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: FlitColors.accent),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildBrief(),
                      const SizedBox(height: 16),
                      _buildRules(),
                      const SizedBox(height: 24),
                      if (played) _buildResult() else _buildPlayButton(),
                    ],
                  ),
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
          border: Border.all(color: FlitColors.error.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlitColors.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore,
                color: FlitColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'TRIANGULATION #${_daily.dayNumber}',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: FlitColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FlitColors.gold.withOpacity(0.35)),
              ),
              child: Text(
                "Today's theme: ${_daily.theme.title}",
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _daily.theme.description,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DifficultyIndicator(
                  percent: _daily.difficultyPercent,
                  label: _daily.difficultyLabelText,
                ),
                const SizedBox(width: 8),
                _BriefChip(
                  icon: Icons.monetization_on_rounded,
                  label: '$_coinReward coins',
                  color: FlitColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Same puzzle for every pilot. Your guesses make it yours.',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  /// Scramble-style brief: what you're hunting and exactly which clue
  /// visuals/labels today's markers carry.
  Widget _buildBrief() {
    final theme = _daily.theme;
    final isCapital = theme.targetType == TriTargetType.capital;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TARGET',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BriefChip(
                icon: isCapital ? Icons.location_city_rounded : Icons.public,
                label: theme.targetType.displayName,
                color: FlitColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCapital
                      ? 'Capital = full pts, country = ×0.7'
                      : 'Answer with the country name',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'ACTIVE CLUES',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in theme.clueTypes)
                _BriefChip(
                  icon: _clueIcon(type),
                  label: _clueLabel(type),
                  color: FlitColors.accent,
                ),
              if (theme.labelTypes.isEmpty)
                const _BriefChip(
                  icon: Icons.visibility_off_rounded,
                  label: 'No labels — expert!',
                  color: FlitColors.warning,
                )
              else
                for (final label in theme.labelTypes)
                  _BriefChip(
                    icon: _labelIcon(label),
                    label: '${label.displayName} label',
                    color: FlitColors.gold,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _clueIcon(ClueType type) {
    switch (type) {
      case ClueType.flag:
        return Icons.flag_rounded;
      case ClueType.outline:
        return Icons.crop_square_rounded;
      case ClueType.borders:
        return Icons.border_all_rounded;
      case ClueType.capital:
        return Icons.location_city_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  static String _clueLabel(ClueType type) {
    switch (type) {
      case ClueType.flag:
        return 'Flags';
      case ClueType.outline:
        return 'Outlines';
      case ClueType.borders:
        return 'Borders';
      case ClueType.capital:
        return 'Capitals';
      default:
        return type.name;
    }
  }

  static IconData _labelIcon(TriLabel label) {
    switch (label) {
      case TriLabel.country:
        return Icons.public;
      case TriLabel.capital:
        return Icons.location_city_rounded;
      case TriLabel.leader:
        return Icons.person_rounded;
      case TriLabel.language:
        return Icons.translate_rounded;
    }
  }

  Widget _buildRules() {
    final isCapital = _daily.theme.targetType == TriTargetType.capital;
    final what = isCapital ? 'capitals' : 'countries';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RuleRow(
            icon: Icons.explore,
            text: 'Each arrow points from the hidden target toward a '
                'known place — cross-reference them to close in.',
          ),
          _RuleRow(
            icon: Icons.replay,
            text: '3 hidden $what, 5 guesses each. Wrong guesses join '
                'the compass in red.',
          ),
          const _RuleRow(
            icon: Icons.timer_outlined,
            text: 'Full marks inside 10 seconds, decaying to 60s. Wild '
                'guesses cost more than near misses.',
          ),
          _RuleRow(
            icon: Icons.star_outline,
            text: isCapital
                ? 'Name the capital for full points — the country alone '
                    'scores ×0.7.'
                : 'Only country names count today — capitals are not '
                    'accepted.',
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _play,
          icon: const Icon(Icons.flight_takeoff, size: 22),
          label: const Text(
            'START TRIANGULATION',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.error,
            foregroundColor: FlitColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
        ),
      );

  Widget _buildResult() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            const Text(
              'FLOWN FOR TODAY',
              style: TextStyle(
                color: FlitColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            if (_completedScore != null)
              Text(
                '${DailyResult.formatScore(_completedScore!)} pts',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              _completedShareText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _completedShareText!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Result copied — paste to share!'),
                    ),
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text(
                  'SHARE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.gold,
                  foregroundColor: FlitColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Come back tomorrow for a new puzzle',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
}

/// Small icon+label pill used in the daily brief (same visual language as
/// the Daily Scramble's clue chips).
class _BriefChip extends StatelessWidget {
  const _BriefChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// Difficulty pill matching the Daily Scramble's (label + percent on the
/// shared green→red band scale).
class _DifficultyIndicator extends StatelessWidget {
  const _DifficultyIndicator({required this.percent, required this.label});

  final int percent;
  final String label;

  static const List<Color> _gradientColors = [
    Color(0xFF4CAF50), // green — Clear Skies
    Color(0xFF8BC34A), // light green — Tailwind
    Color(0xFFFFEB3B), // yellow — Fair Weather
    Color(0xFFFFC107), // amber — Crosswinds
    Color(0xFFFF9800), // orange — Turbulence
    Color(0xFFFF5722), // deep orange — Storm Front
    Color(0xFFF44336), // red — Cat-5 Headwind
  ];

  @override
  Widget build(BuildContext context) {
    final index = difficultyBandIndex(percent / 100.0);
    final color = _gradientColors[index.clamp(0, _gradientColors.length - 1)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label  $percent%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FlitColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
