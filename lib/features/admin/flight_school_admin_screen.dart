import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';

/// Admin screen for managing Flight School configuration.
///
/// Allows editing per-level, per-category difficulty multipliers,
/// coin rewards, unlock costs, and required level overrides.
/// All overrides are persisted to a `flight_school_config` JSONB
/// in the Supabase `remote_config` table.
class FlightSchoolAdminScreen extends StatefulWidget {
  const FlightSchoolAdminScreen({super.key});

  @override
  State<FlightSchoolAdminScreen> createState() =>
      _FlightSchoolAdminScreenState();
}

class _FlightSchoolAdminScreenState extends State<FlightSchoolAdminScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  bool _loading = true;
  String? _error;
  int _selectedLevelIndex = 0;

  /// Remote overrides keyed by level id.
  /// Structure:
  /// ```json
  /// {
  ///   "europe": {
  ///     "categoryMultipliers": { "stateName": 1.1, ... },
  ///     "coinReward": 50,
  ///     "unlockCostOverride": 500,
  ///     "requiredLevelOverride": 3
  ///   },
  ///   ...
  /// }
  /// ```
  Map<String, dynamic> _config = {};

  /// Per-row controllers for editable multiplier fields.
  final Map<String, TextEditingController> _multiplierControllers = {};

  /// Level-specific setting controllers.
  final TextEditingController _coinRewardController = TextEditingController();
  final TextEditingController _unlockCostController = TextEditingController();
  final TextEditingController _requiredLevelController =
      TextEditingController();

  FlightSchoolLevel get _selectedLevel =>
      flightSchoolLevels[_selectedLevelIndex];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _multiplierControllers.values) {
      c.dispose();
    }
    _coinRewardController.dispose();
    _unlockCostController.dispose();
    _requiredLevelController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _client
          .from('remote_config')
          .select('value')
          .eq('key', 'flight_school_config')
          .maybeSingle();

      if (row != null && row['value'] != null) {
        final raw = row['value'];
        if (raw is Map<String, dynamic>) {
          _config = Map<String, dynamic>.from(raw);
        } else if (raw is String) {
          _config = jsonDecode(raw) as Map<String, dynamic>;
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _syncControllersForLevel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load config: $e';
      });
    }
  }

  void _syncControllersForLevel() {
    final levelId = _selectedLevel.id;
    final levelConfig =
        (_config[levelId] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final multipliers =
        (levelConfig['categoryMultipliers'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    // Dispose old controllers
    for (final c in _multiplierControllers.values) {
      c.dispose();
    }
    _multiplierControllers.clear();

    // Create controllers for each category
    for (final cat in QuizCategory.values) {
      final defaultVal = clueDifficultyMultiplier(cat);
      final overrideVal = multipliers[cat.name];
      final value = overrideVal != null
          ? (overrideVal as num).toDouble()
          : defaultVal;
      _multiplierControllers[cat.name] = TextEditingController(
        text: value.toStringAsFixed(2),
      );
    }

    // Level settings
    final coinReward = levelConfig['coinReward'] as int? ?? 50;
    final unlockCost =
        levelConfig['unlockCostOverride'] as int? ?? _selectedLevel.unlockCost;
    final reqLevel =
        levelConfig['requiredLevelOverride'] as int? ??
        _selectedLevel.requiredLevel;

    _coinRewardController.text = coinReward.toString();
    _unlockCostController.text = unlockCost.toString();
    _requiredLevelController.text = reqLevel.toString();

    if (mounted) setState(() {});
  }

  Future<void> _saveCategoryMultiplier(QuizCategory category) async {
    final controller = _multiplierControllers[category.name];
    if (controller == null) return;

    final value = double.tryParse(controller.text);
    if (value == null || value < 0.1 || value > 5.0) {
      _showSnackBar('Invalid multiplier (0.1 - 5.0)', isError: true);
      return;
    }

    final levelId = _selectedLevel.id;
    _config[levelId] ??= <String, dynamic>{};
    final levelConfig = _config[levelId] as Map<String, dynamic>;
    levelConfig['categoryMultipliers'] ??= <String, dynamic>{};
    final multipliers =
        levelConfig['categoryMultipliers'] as Map<String, dynamic>;
    multipliers[category.name] = value;

    await _persistConfig();
    _showSnackBar(
      '${category.displayName} multiplier saved: ${value.toStringAsFixed(2)}',
    );
  }

  Future<void> _saveLevelSettings() async {
    final coinReward = int.tryParse(_coinRewardController.text);
    final unlockCost = int.tryParse(_unlockCostController.text);
    final reqLevel = int.tryParse(_requiredLevelController.text);

    if (coinReward == null || coinReward < 0) {
      _showSnackBar('Invalid coin reward', isError: true);
      return;
    }
    if (unlockCost == null || unlockCost < 0) {
      _showSnackBar('Invalid unlock cost', isError: true);
      return;
    }
    if (reqLevel == null || reqLevel < 0) {
      _showSnackBar('Invalid required level', isError: true);
      return;
    }

    final levelId = _selectedLevel.id;
    _config[levelId] ??= <String, dynamic>{};
    final levelConfig = _config[levelId] as Map<String, dynamic>;
    levelConfig['coinReward'] = coinReward;
    levelConfig['unlockCostOverride'] = unlockCost;
    levelConfig['requiredLevelOverride'] = reqLevel;

    await _persistConfig();
    _showSnackBar('Level settings saved for ${_selectedLevel.name}');
  }

  Future<void> _persistConfig() async {
    try {
      await _client.from('remote_config').upsert({
        'key': 'flight_school_config',
        'value': _config,
      }, onConflict: 'key');
    } catch (e) {
      _showSnackBar('Save failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? FlitColors.error : FlitColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _iconForCategory(QuizCategory cat) {
    switch (cat) {
      case QuizCategory.stateName:
        return Icons.map;
      case QuizCategory.capital:
        return Icons.location_city;
      case QuizCategory.nickname:
        return Icons.label;
      case QuizCategory.sportsTeam:
        return Icons.sports_football;
      case QuizCategory.landmark:
        return Icons.landscape;
      case QuizCategory.flagDescription:
        return Icons.flag;
      case QuizCategory.stateBird:
        return Icons.flutter_dash;
      case QuizCategory.stateFlower:
        return Icons.local_florist;
      case QuizCategory.motto:
        return Icons.format_quote;
      case QuizCategory.celebrity:
        return Icons.star;
      case QuizCategory.filmSetting:
        return Icons.movie;
      case QuizCategory.mixed:
        return Icons.shuffle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Flight School Config'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: FlitColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadConfig,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Level selector dropdown
                _buildLevelSelector(),
                const SizedBox(height: 20),

                // Level settings card
                _buildLevelSettingsCard(),
                const SizedBox(height: 20),

                // Category multipliers header
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'CATEGORY DIFFICULTY MULTIPLIERS',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                // Category rows
                ...QuizCategory.values.map(_buildCategoryRow),
              ],
            ),
    );
  }

  Widget _buildLevelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedLevelIndex,
          isExpanded: true,
          dropdownColor: FlitColors.cardBackground,
          style: const TextStyle(color: FlitColors.textPrimary, fontSize: 15),
          items: List.generate(flightSchoolLevels.length, (i) {
            final level = flightSchoolLevels[i];
            return DropdownMenuItem(
              value: i,
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    color: FlitColors.oceanHighlight,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text('${level.name} - ${level.subtitle}'),
                ],
              ),
            );
          }),
          onChanged: (idx) {
            if (idx == null) return;
            setState(() {
              _selectedLevelIndex = idx;
            });
            _syncControllersForLevel();
          },
        ),
      ),
    );
  }

  Widget _buildLevelSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: FlitColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_selectedLevel.name} Settings',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            label: 'Coin Reward (base)',
            controller: _coinRewardController,
            hint: '50',
          ),
          const SizedBox(height: 10),
          _buildSettingRow(
            label: 'Unlock Cost Override',
            controller: _unlockCostController,
            hint: _selectedLevel.unlockCost.toString(),
          ),
          const SizedBox(height: 10),
          _buildSettingRow(
            label: 'Required Level Override',
            controller: _requiredLevelController,
            hint: _selectedLevel.requiredLevel.toString(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saveLevelSettings,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Level Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.success,
                foregroundColor: FlitColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 13,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              filled: true,
              fillColor: FlitColors.backgroundMid,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: FlitColors.oceanHighlight),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(QuizCategory category) {
    final controller = _multiplierControllers[category.name];
    final defaultMultiplier = clueDifficultyMultiplier(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Row(
        children: [
          // Category icon
          Icon(
            _iconForCategory(category),
            color: FlitColors.oceanHighlight,
            size: 20,
          ),
          const SizedBox(width: 10),

          // Category name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.displayName,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Default: ${defaultMultiplier.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Editable multiplier field
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                filled: true,
                fillColor: FlitColors.backgroundMid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: FlitColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: FlitColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: FlitColors.oceanHighlight,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Save button
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              onPressed: () => _saveCategoryMultiplier(category),
              icon: const Icon(Icons.save, size: 18),
              color: FlitColors.success,
              padding: EdgeInsets.zero,
              tooltip: 'Save ${category.displayName}',
              style: IconButton.styleFrom(
                backgroundColor: FlitColors.success.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
