import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/economy_config.dart';
import '../../data/services/economy_config_service.dart';
import '../../game/quiz/flight_school_level.dart';

/// Dedicated admin screen for gold and economy management.
///
/// Sections:
/// 1. Player Gold Operations - gift, remove, set gold by username
/// 2. Flight School Economy - coin rewards and unlock costs
/// 3. Economy Config - edit global economy settings
/// 4. Gold Audit Log - view recent gold transactions
class GoldManagementScreen extends StatefulWidget {
  const GoldManagementScreen({super.key});

  @override
  State<GoldManagementScreen> createState() => _GoldManagementScreenState();
}

class _GoldManagementScreenState extends State<GoldManagementScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  // ── Player Gold Operations ──
  final TextEditingController _playerUsernameController =
      TextEditingController();
  final TextEditingController _goldAmountController = TextEditingController();
  bool _playerOpLoading = false;
  String? _playerOpResult;
  bool _playerOpIsError = false;

  // ── Flight School Economy ──
  Map<String, dynamic> _flightSchoolConfig = {};
  bool _flightSchoolLoading = true;

  // ── Economy Config ──
  EconomyConfig? _economyConfig;
  bool _economyLoading = true;
  final TextEditingController _dailyScrambleController =
      TextEditingController();
  final TextEditingController _freeFlightPerClueController =
      TextEditingController();
  final TextEditingController _freeFlightCapController =
      TextEditingController();

  // ── Gold Audit Log ──
  List<Map<String, dynamic>> _auditLog = [];
  bool _auditLoading = false;
  bool _auditLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFlightSchoolConfig();
    _loadEconomyConfig();
  }

  @override
  void dispose() {
    _playerUsernameController.dispose();
    _goldAmountController.dispose();
    _dailyScrambleController.dispose();
    _freeFlightPerClueController.dispose();
    _freeFlightCapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadFlightSchoolConfig() async {
    try {
      final row = await _client
          .from('remote_config')
          .select('value')
          .eq('key', 'flight_school_config')
          .maybeSingle();

      if (row != null && row['value'] != null) {
        final raw = row['value'];
        if (raw is Map<String, dynamic>) {
          _flightSchoolConfig = Map<String, dynamic>.from(raw);
        } else if (raw is String) {
          _flightSchoolConfig = jsonDecode(raw) as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // Non-fatal: we just show defaults
    }
    if (!mounted) return;
    setState(() => _flightSchoolLoading = false);
  }

  Future<void> _loadEconomyConfig() async {
    try {
      final config = await EconomyConfigService.instance.getConfig();
      if (!mounted) return;
      _economyConfig = config;
      _dailyScrambleController.text =
          config.earnings.dailyScrambleBaseReward.toString();
      _freeFlightPerClueController.text =
          config.earnings.freeFlightPerClueReward.toString();
      _freeFlightCapController.text =
          config.earnings.freeFlightDailyCap.toString();
    } catch (_) {
      if (!mounted) return;
      _economyConfig = EconomyConfig.defaults();
      _dailyScrambleController.text = '150';
      _freeFlightPerClueController.text = '15';
      _freeFlightCapController.text = '150';
    }
    setState(() => _economyLoading = false);
  }

  Future<void> _loadAuditLog() async {
    setState(() {
      _auditLoading = true;
    });
    try {
      final rows = await _client
          .from('coin_ledger')
          .select(
            'id, user_id, amount, source, created_at, profiles!inner(username)',
          )
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _auditLog = List<Map<String, dynamic>>.from(rows as List);
        _auditLoading = false;
        _auditLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auditLoading = false;
        _auditLoaded = true;
      });
      _showSnackBar('Failed to load audit log: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Player Gold Operations
  // ---------------------------------------------------------------------------

  Future<void> _giftGold() async {
    await _executePlayerGoldOp('gift');
  }

  Future<void> _removeGold() async {
    await _executePlayerGoldOp('remove');
  }

  Future<void> _setGold() async {
    await _executePlayerGoldOp('set');
  }

  Future<void> _executePlayerGoldOp(String operation) async {
    final username = _playerUsernameController.text.trim();
    final amount = int.tryParse(_goldAmountController.text.trim());

    if (username.isEmpty) {
      _setOpResult('Please enter a username', isError: true);
      return;
    }
    if (amount == null || amount < 0) {
      _setOpResult('Please enter a valid amount', isError: true);
      return;
    }

    setState(() {
      _playerOpLoading = true;
      _playerOpResult = null;
    });

    try {
      // Look up user by username
      final userRow = await _client
          .from('profiles')
          .select('id, coins')
          .eq('username', username)
          .maybeSingle();

      if (userRow == null) {
        _setOpResult('User "$username" not found', isError: true);
        return;
      }

      final userId = userRow['id'] as String;
      final currentCoins = userRow['coins'] as int? ?? 0;

      int newCoins;
      int ledgerAmount;
      String source;

      switch (operation) {
        case 'gift':
          newCoins = currentCoins + amount;
          ledgerAmount = amount;
          source = 'admin_gift';
          break;
        case 'remove':
          newCoins = (currentCoins - amount).clamp(0, currentCoins);
          ledgerAmount = -(currentCoins - newCoins);
          source = 'admin_remove';
          break;
        case 'set':
          newCoins = amount;
          ledgerAmount = amount - currentCoins;
          source = 'admin_set';
          break;
        default:
          return;
      }

      // Update coins
      await _client
          .from('profiles')
          .update({'coins': newCoins}).eq('id', userId);

      // Record in coin ledger
      await _client.from('coin_ledger').insert({
        'user_id': userId,
        'amount': ledgerAmount,
        'source': source,
      });

      final opLabel = operation == 'gift'
          ? 'Gifted'
          : operation == 'remove'
              ? 'Removed'
              : 'Set to';
      _setOpResult(
        '$opLabel ${operation == "set" ? newCoins : amount} coins '
        'for @$username (was $currentCoins, now $newCoins)',
      );
    } catch (e) {
      _setOpResult('Operation failed: $e', isError: true);
    }
  }

  void _setOpResult(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _playerOpLoading = false;
      _playerOpResult = message;
      _playerOpIsError = isError;
    });
  }

  // ---------------------------------------------------------------------------
  // Flight School Economy
  // ---------------------------------------------------------------------------

  Future<void> _saveFlightSchoolReward(String levelId, int reward) async {
    _flightSchoolConfig[levelId] ??= <String, dynamic>{};
    (_flightSchoolConfig[levelId] as Map<String, dynamic>)['coinReward'] =
        reward;

    try {
      await _client.from('remote_config').upsert({
        'key': 'flight_school_config',
        'value': _flightSchoolConfig,
      }, onConflict: 'key');
      _showSnackBar('Saved reward for $levelId');
    } catch (e) {
      _showSnackBar('Save failed: $e', isError: true);
    }
  }

  Future<void> _saveFlightSchoolUnlockCost(String levelId, int cost) async {
    _flightSchoolConfig[levelId] ??= <String, dynamic>{};
    (_flightSchoolConfig[levelId]
        as Map<String, dynamic>)['unlockCostOverride'] = cost;

    try {
      await _client.from('remote_config').upsert({
        'key': 'flight_school_config',
        'value': _flightSchoolConfig,
      }, onConflict: 'key');
      _showSnackBar('Saved unlock cost for $levelId');
    } catch (e) {
      _showSnackBar('Save failed: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Economy Config
  // ---------------------------------------------------------------------------

  Future<void> _saveEconomyConfig() async {
    final daily = int.tryParse(_dailyScrambleController.text);
    final perClue = int.tryParse(_freeFlightPerClueController.text);
    final cap = int.tryParse(_freeFlightCapController.text);

    if (daily == null || perClue == null || cap == null) {
      _showSnackBar('Invalid values', isError: true);
      return;
    }

    if (_economyConfig == null) return;

    final updated = EconomyConfig(
      earnings: EarningsConfig(
        dailyScrambleBaseReward: daily,
        freeFlightPerClueReward: perClue,
        freeFlightDailyCap: cap,
      ),
      shopPriceOverrides: _economyConfig!.shopPriceOverrides,
      promotions: _economyConfig!.promotions,
      goldPackages: _economyConfig!.goldPackages,
    );

    try {
      await _client.from('economy_config').upsert({
        'id': 1,
        'config': updated.toJson(),
      });
      EconomyConfigService.instance.invalidateCache();
      _economyConfig = updated;
      _showSnackBar('Economy config saved');
    } catch (e) {
      _showSnackBar('Save failed: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Gold Management'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlayerGoldSection(),
          const SizedBox(height: 16),
          _buildFlightSchoolEconomySection(),
          const SizedBox(height: 16),
          _buildEconomyConfigSection(),
          const SizedBox(height: 16),
          _buildAuditLogSection(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Player Gold Operations
  // ---------------------------------------------------------------------------

  Widget _buildPlayerGoldSection() {
    return _CollapsibleSection(
      title: 'Player Gold Operations',
      icon: Icons.monetization_on,
      iconColor: FlitColors.gold,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username field
          TextField(
            controller: _playerUsernameController,
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration('Username (without @)'),
          ),
          const SizedBox(height: 10),

          // Amount field
          TextField(
            controller: _goldAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: FlitColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration('Gold Amount'),
          ),
          const SizedBox(height: 14),

          // Action buttons
          if (_playerOpLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton(
                  label: 'Gift Gold',
                  icon: Icons.card_giftcard,
                  color: FlitColors.success,
                  onTap: _giftGold,
                ),
                _actionButton(
                  label: 'Remove Gold',
                  icon: Icons.remove_circle_outline,
                  color: FlitColors.error,
                  onTap: _removeGold,
                ),
                _actionButton(
                  label: 'Set Exact',
                  icon: Icons.edit,
                  color: FlitColors.oceanHighlight,
                  onTap: _setGold,
                ),
              ],
            ),

          // Result message
          if (_playerOpResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    (_playerOpIsError ? FlitColors.error : FlitColors.success)
                        .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _playerOpIsError ? FlitColors.error : FlitColors.success,
                  width: 0.5,
                ),
              ),
              child: Text(
                _playerOpResult!,
                style: TextStyle(
                  color:
                      _playerOpIsError ? FlitColors.error : FlitColors.success,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Flight School Economy
  // ---------------------------------------------------------------------------

  Widget _buildFlightSchoolEconomySection() {
    return _CollapsibleSection(
      title: 'Flight School Economy',
      icon: Icons.school,
      iconColor: FlitColors.oceanHighlight,
      child: _flightSchoolLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              children: flightSchoolLevels.map((level) {
                final levelConfig =
                    (_flightSchoolConfig[level.id] as Map<String, dynamic>?) ??
                        <String, dynamic>{};
                final coinReward = levelConfig['coinReward'] as int? ?? 50;
                final unlockCost = levelConfig['unlockCostOverride'] as int? ??
                    level.unlockCost;

                return _FlightSchoolLevelRow(
                  level: level,
                  coinReward: coinReward,
                  unlockCost: unlockCost,
                  onSaveReward: (reward) =>
                      _saveFlightSchoolReward(level.id, reward),
                  onSaveUnlockCost: (cost) =>
                      _saveFlightSchoolUnlockCost(level.id, cost),
                );
              }).toList(),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Economy Config
  // ---------------------------------------------------------------------------

  Widget _buildEconomyConfigSection() {
    return _CollapsibleSection(
      title: 'Economy Config',
      icon: Icons.tune,
      iconColor: FlitColors.accent,
      child: _economyLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              children: [
                _configRow(
                  label: 'Daily Scramble Base Reward',
                  controller: _dailyScrambleController,
                ),
                const SizedBox(height: 10),
                _configRow(
                  label: 'Free Flight Per-Clue Reward',
                  controller: _freeFlightPerClueController,
                ),
                const SizedBox(height: 10),
                _configRow(
                  label: 'Free Flight Daily Cap',
                  controller: _freeFlightCapController,
                ),
                const SizedBox(height: 14),
                if (_economyConfig != null) ...[
                  // Promotions summary
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlitColors.backgroundMid,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer,
                          color: FlitColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_economyConfig!.promotions.length} promotions '
                          '(${_economyConfig!.activePromotions.length} active)',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_economyConfig!.goldPackages.length} gold packages',
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saveEconomyConfig,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save Economy Config'),
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

  // ---------------------------------------------------------------------------
  // Section 4: Gold Audit Log
  // ---------------------------------------------------------------------------

  Widget _buildAuditLogSection() {
    return _CollapsibleSection(
      title: 'Gold Audit Log',
      icon: Icons.receipt_long,
      iconColor: FlitColors.gold,
      onExpansionChanged: (expanded) {
        if (expanded && !_auditLoaded) {
          _loadAuditLog();
        }
      },
      child: _auditLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          : !_auditLoaded
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Expand to load audit log',
                    style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
                  ),
                )
              : _auditLog.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No audit log entries found',
                        style: TextStyle(
                            color: FlitColors.textMuted, fontSize: 13),
                      ),
                    )
                  : Column(
                      children: [
                        // Refresh button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _loadAuditLog,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                            style: TextButton.styleFrom(
                              foregroundColor: FlitColors.textSecondary,
                            ),
                          ),
                        ),
                        ...List.generate(
                          _auditLog.length,
                          (i) => _buildAuditRow(_auditLog[i]),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildAuditRow(Map<String, dynamic> entry) {
    final amount = entry['amount'] as int? ?? 0;
    final source = entry['source'] as String? ?? 'unknown';
    final createdAt = entry['created_at'] as String? ?? '';
    final profiles = entry['profiles'] as Map<String, dynamic>?;
    final username = profiles?['username'] as String? ?? '???';

    final isPositive = amount >= 0;
    final color = isPositive ? FlitColors.success : FlitColors.error;
    final sign = isPositive ? '+' : '';

    // Parse date for display
    String dateStr = '';
    final dt = DateTime.tryParse(createdAt);
    if (dt != null) {
      final local = dt.toLocal();
      dateStr =
          '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Amount
          SizedBox(
            width: 70,
            child: Text(
              '$sign$amount',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Username
          Expanded(
            child: Text(
              '@$username',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Source
          SizedBox(
            width: 80,
            child: Text(
              source,
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Date
          SizedBox(
            width: 70,
            child: Text(
              dateStr,
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: FlitColors.textMuted, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: FlitColors.backgroundMid,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FlitColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FlitColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: FlitColors.oceanHighlight),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _configRow({
    required String label,
    required TextEditingController controller,
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
}

// =============================================================================
// Collapsible Section
// =============================================================================

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, color: iconColor, size: 22),
          title: Text(
            title,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: FlitColors.textMuted,
          collapsedIconColor: FlitColors.textMuted,
          children: [child],
        ),
      ),
    );
  }
}

// =============================================================================
// Flight School Level Row
// =============================================================================

class _FlightSchoolLevelRow extends StatefulWidget {
  const _FlightSchoolLevelRow({
    required this.level,
    required this.coinReward,
    required this.unlockCost,
    required this.onSaveReward,
    required this.onSaveUnlockCost,
  });

  final FlightSchoolLevel level;
  final int coinReward;
  final int unlockCost;
  final ValueChanged<int> onSaveReward;
  final ValueChanged<int> onSaveUnlockCost;

  @override
  State<_FlightSchoolLevelRow> createState() => _FlightSchoolLevelRowState();
}

class _FlightSchoolLevelRowState extends State<_FlightSchoolLevelRow> {
  late TextEditingController _rewardController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _rewardController = TextEditingController(
      text: widget.coinReward.toString(),
    );
    _costController = TextEditingController(text: widget.unlockCost.toString());
  }

  @override
  void didUpdateWidget(_FlightSchoolLevelRow old) {
    super.didUpdateWidget(old);
    if (old.coinReward != widget.coinReward) {
      _rewardController.text = widget.coinReward.toString();
    }
    if (old.unlockCost != widget.unlockCost) {
      _costController.text = widget.unlockCost.toString();
    }
  }

  @override
  void dispose() {
    _rewardController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level name
          Row(
            children: [
              Icon(Icons.school, color: FlitColors.oceanHighlight, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.level.name} (Lv.${widget.level.requiredLevel})',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reward and cost row
          Row(
            children: [
              // Coin reward
              const Text(
                'Reward:',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 55,
                child: TextField(
                  controller: _rewardController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    filled: true,
                    fillColor: FlitColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: FlitColors.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: FlitColors.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () {
                    final val = int.tryParse(_rewardController.text);
                    if (val != null && val >= 0) {
                      widget.onSaveReward(val);
                    }
                  },
                  icon: const Icon(Icons.save, size: 14),
                  color: FlitColors.success,
                  padding: EdgeInsets.zero,
                ),
              ),
              const Spacer(),

              // Unlock cost
              const Text(
                'Unlock:',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    filled: true,
                    fillColor: FlitColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: FlitColors.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: FlitColors.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () {
                    final val = int.tryParse(_costController.text);
                    if (val != null && val >= 0) {
                      widget.onSaveUnlockCost(val);
                    }
                  },
                  icon: const Icon(Icons.save, size: 14),
                  color: FlitColors.success,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
