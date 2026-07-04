import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/models/daily_result.dart';
import '../../game/triangulation/daily_triangulation.dart';
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

  @override
  void initState() {
    super.initState();
    _daily = DailyTriangulation.forToday();
    _loadResult();
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
            const SizedBox(height: 10),
            const Text(
              'Same puzzle for every pilot.\n'
              'Your guesses make it yours.',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildRules() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleRow(
              icon: Icons.explore,
              text: 'Each arrow points from the hidden capital toward a '
                  'known place — cross-reference them to close in.',
            ),
            _RuleRow(
              icon: Icons.replay,
              text: '3 hidden capitals, 5 guesses each. Wrong guesses join '
                  'the compass in red.',
            ),
            _RuleRow(
              icon: Icons.timer_outlined,
              text: 'Full marks inside 10 seconds, decaying to 60s. Wild '
                  'guesses cost more than near misses.',
            ),
            _RuleRow(
              icon: Icons.star_outline,
              text: 'Name the capital for full points — the country alone '
                  'scores ×0.7.',
            ),
          ],
        ),
      );

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
