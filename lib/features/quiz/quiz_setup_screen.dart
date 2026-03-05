import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_session.dart';
import '../../game/map/region.dart';
import 'quiz_game_screen.dart';
import 'type_in_game_screen.dart';

/// Setup/lobby screen for Flight School quiz mode.
///
/// Lets the player choose:
/// 1. Quiz category (filtered by region)
/// 2. Game mode (all areas, time trial, rapid fire)
///
/// The [level] parameter determines which region and categories are available.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key, required this.level});

  final FlightSchoolLevel level;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  QuizCategory _selectedCategory = QuizCategory.mixed;
  QuizMode _selectedMode = QuizMode.allStates;
  QuizDifficulty _selectedDifficulty = QuizDifficulty.medium;

  static const _iconMap = <String, IconData>{
    'map': Icons.map,
    'location_city': Icons.location_city,
    'label': Icons.label,
    'sports_football': Icons.sports_football,
    'landscape': Icons.landscape,
    'flag': Icons.flag,
    'flutter_dash': Icons.flutter_dash,
    'local_florist': Icons.local_florist,
    'format_quote': Icons.format_quote,
    'star': Icons.star,
    'movie': Icons.movie,
    'shuffle': Icons.shuffle,
  };

  List<QuizCategory> get _availableCategories =>
      _selectedDifficulty.filterCategories(widget.level.availableCategories);

  @override
  void initState() {
    super.initState();
    // Ensure default selection is valid for this level
    if (!_availableCategories.contains(_selectedCategory)) {
      _selectedCategory = _availableCategories.first;
    }
  }

  void _startQuiz() {
    final Widget screen;
    if (_selectedMode == QuizMode.typeIn) {
      screen = TypeInGameScreen(
        mode: _selectedMode,
        category: _selectedCategory,
        region: widget.level.region,
        difficulty: _selectedDifficulty,
        flightSchoolLevelId: widget.level.id,
      );
    } else {
      screen = QuizGameScreen(
        mode: _selectedMode,
        category: _selectedCategory,
        region: widget.level.region,
        difficulty: _selectedDifficulty,
        flightSchoolLevelId: widget.level.id,
      );
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: Text(
          widget.level.name,
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    const SizedBox(height: 24),

                    // Difficulty selector
                    _buildSectionLabel('DIFFICULTY', Icons.tune),
                    const SizedBox(height: 10),
                    _buildDifficultySelector(),
                    const SizedBox(height: 24),

                    _buildSectionLabel('GAME MODE', Icons.videogame_asset),
                    const SizedBox(height: 10),
                    ..._buildModeCards(),
                    const SizedBox(height: 24),

                    _buildSectionLabel('CATEGORY', Icons.category),
                    const SizedBox(height: 10),
                    _buildCategoryGrid(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlitColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school, color: FlitColors.gold, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              widget.level.name.toUpperCase(),
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test your knowledge of ${widget.level.name}!\n'
              'Tap the correct area on the map as fast as you can.',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FlitColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FlitColors.accent.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public, color: FlitColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.level.name} \u2014 ${widget.level.subtitle}',
                    style: const TextStyle(
                      color: FlitColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  List<Widget> _buildModeCards() {
    return QuizMode.values.map((mode) {
      final isSelected = _selectedMode == mode;
      final IconData icon;
      switch (mode) {
        case QuizMode.allStates:
          icon = Icons.check_circle_outline;
        case QuizMode.timeTrial:
          icon = Icons.timer;
        case QuizMode.rapidFire:
          icon = Icons.bolt;
        case QuizMode.typeIn:
          icon = Icons.keyboard;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedMode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? FlitColors.accent.withOpacity(0.1)
                  : FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? FlitColors.accent.withOpacity(0.6)
                    : FlitColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FlitColors.accent.withOpacity(0.2)
                        : FlitColors.backgroundDark.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isSelected ? FlitColors.accent : FlitColors.textMuted,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? FlitColors.textPrimary
                              : FlitColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        style: TextStyle(
                          color: isSelected
                              ? FlitColors.textSecondary
                              : FlitColors.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
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
    }).toList();
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableCategories.map((category) {
        final isSelected = _selectedCategory == category;
        final iconData = _iconMap[category.icon] ?? Icons.help;

        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 48) / 3,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? FlitColors.gold.withOpacity(0.15)
                  : FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? FlitColors.gold.withOpacity(0.6)
                    : FlitColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconData,
                  color: isSelected ? FlitColors.gold : FlitColors.textMuted,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  category.displayName,
                  style: TextStyle(
                    color: isSelected
                        ? FlitColors.textPrimary
                        : FlitColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      children: QuizDifficulty.values.map((diff) {
        final isSelected = _selectedDifficulty == diff;
        final color = _difficultyColor(diff);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: diff != QuizDifficulty.hard ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDifficulty = diff;
                  // Re-validate category selection
                  if (!_availableCategories.contains(_selectedCategory)) {
                    _selectedCategory = _availableCategories.first;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : FlitColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.7)
                        : FlitColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      diff.displayName.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? color : FlitColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diff.showLabels ? 'Labels on' : 'Labels off',
                      style: TextStyle(
                        color: isSelected
                            ? FlitColors.textSecondary
                            : FlitColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${diff.maxHints} hints',
                      style: TextStyle(
                        color: isSelected
                            ? FlitColors.textSecondary
                            : FlitColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${diff.scoreMultiplier}x pts',
                      style: TextStyle(
                        color: isSelected ? color : FlitColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _difficultyColor(QuizDifficulty diff) {
    switch (diff) {
      case QuizDifficulty.easy:
        return FlitColors.success;
      case QuizDifficulty.medium:
        return FlitColors.accent;
      case QuizDifficulty.hard:
        return FlitColors.gold;
    }
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
            onPressed: _startQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.play_arrow, size: 24),
                SizedBox(width: 10),
                Text(
                  'START QUIZ',
                  style: TextStyle(
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
